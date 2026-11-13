"""Reproducible NCR ERA5 rain research; no forecast API or paid service."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import time
from datetime import datetime, timezone
from urllib.request import urlopen
from urllib.error import HTTPError
from urllib.parse import urlencode
import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.preprocessing import StandardScaler
from sklearn.metrics import brier_score_loss, log_loss, roc_auc_score, average_precision_score, precision_score, recall_score

ROOT = Path(__file__).resolve().parents[1]
CITIES = re.findall(r'slug: "([^"]+)"', (ROOT/'backend/src/cities.mjs').read_text())
COORDS = [(float(a),float(b)) for a,b in re.findall(r'latitude: ([\d.]+),\s+longitude: ([\d.]+)', (ROOT/'backend/src/cities.mjs').read_text())]
WET = {51,53,55,56,57,61,63,65,66,67,71,73,75,77,80,81,82,85,86,95,96,99}
CODES = WET | {0,1,2,3,45,48}
FEATURES = ['temperatureC','humidityPercent','pressureHpa','windSpeedMs','wetFlag','hourSin','hourCos','seasonSin','seasonCos'] + ['city_'+c for c in CITIES]
VARIABLES = ['temperature_2m','relative_humidity_2m','pressure_msl','wind_speed_10m','weather_code','rain']
UNITS = {'temperatureC':'°C','humidityPercent':'%','pressureHpa':'hPa','windSpeedMs':'m/s'}

def feature_vector(temp, humidity, pressure, wind, code, city, timestamp):
    if city not in CITIES or code not in CODES or not all(math.isfinite(v) for v in [temp,humidity,pressure,wind]):
        raise ValueError('invalid inputs')
    if not (-90 <= temp <= 60 and 0 <= humidity <= 100 and 800 <= pressure <= 1100 and 0 <= wind <= 100):
        raise ValueError('invalid meteorological domain')
    t = pd.Timestamp(timestamp)
    if t.tzinfo is None: raise ValueError('timestamp must have timezone')
    t = t.tz_convert('Asia/Manila')
    hour = t.hour + t.minute/60 + t.second/3600
    season = (t.dayofyear-1 + hour/24)/365.2425
    return [temp,humidity,pressure,wind,int(code in WET),math.sin(2*math.pi*hour/24),math.cos(2*math.pi*hour/24),math.sin(2*math.pi*season),math.cos(2*math.pi*season)] + [int(c==city) for c in CITIES]

def label_rows(frame):
    frame = frame.sort_values(['city','time']).copy()
    if frame.duplicated(['city','time']).any(): raise ValueError('duplicate city/hour')
    grouped = frame.groupby('city',sort=False)
    valid = frame.rain.notna()
    total = 0
    for offset in (1,2,3):
        future_time = grouped.time.shift(-offset)
        rain = grouped.rain.shift(-offset)
        valid &= ((future_time-frame.time) == pd.Timedelta(hours=offset)) & rain.notna()
        total = total+rain
    frame['target'] = (total >= .1).astype(int)
    frame['targetEnd'] = grouped.time.shift(-3)
    return frame.loc[valid].copy()

def split_rows(frame):
    result = {}
    for name,lo,hi in [('train',2021,2024),('validation',2024,2025),('test',2025,2026)]:
        result[name] = frame.loc[(frame.time.dt.year>=lo)&(frame.time.dt.year<hi)&(frame.targetEnd.dt.year<hi)].copy()
    return result

def internal_training_mask(frame):
    return (frame.time.dt.year < 2023) & (frame.targetEnd.dt.year < 2023)

def export_artifact(artifact, output):
    artifact['target']['futureOffsets'] = [1,2,3]
    artifact['featureTransform'] = {'timezone':'Asia/Manila','hour':'hour+minute/60+second/3600','season':'(dayOfYear-1+hour/24)/365.2425'}
    report = ROOT/'ml/reports/evaluation.json'
    report.parent.mkdir(parents=True,exist_ok=True)
    report.write_text(json.dumps(artifact,indent=2,allow_nan=False)+'\n')
    compact = dict(artifact)
    compact['metrics'] = {split:{k:v for k,v in m.items() if k not in ['byCity','bySeason','reliability']} for split,m in artifact['metrics'].items()}
    compact['provenance'] = {k:v for k,v in artifact['provenance'].items() if k != 'requests'}
    compact['provenance']['reportPath'] = 'ml/reports/evaluation.json'
    compact['provenance']['reportSha256'] = hashlib.sha256(report.read_bytes()).hexdigest()
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(compact,indent=2,allow_nan=False)+'\n')

def duplicate_weights(frame):
    return 1/frame.groupby(['grid','time'])['grid'].transform('size').to_numpy()

def fit_baselines(train):
    mean = lambda f: float(np.average(f.target,weights=f.weight))
    return {'climatology':mean(train),'dry':mean(train[train.wetFlag==0]),'wet':mean(train[train.wetFlag==1])}

def sigmoid(x):
    return 1/(1+math.exp(-x)) if x>=0 else math.exp(x)/(1+math.exp(x))

def fetch(cache, name, params):
    path = cache/(name+'.json')
    meta = cache/(name+'.meta.json')
    if path.exists() and meta.exists():
        raw = path.read_bytes()
        if hashlib.sha256(raw).hexdigest() != json.loads(meta.read_text())['sha256']: raise ValueError('cache checksum mismatch')
        return json.loads(raw),json.loads(meta.read_text())
    url = 'https://archive-api.open-meteo.com/v1/archive?'+urlencode(params)
    for attempt in range(6):
        time.sleep(1.2)
        try:
            with urlopen(url,timeout=120) as response: raw = response.read()
            body = json.loads(raw)
            if body.get('error'): raise ValueError(body)
            info = {'url':url,'params':params,'downloadedAt':datetime.now(timezone.utc).isoformat(),'sha256':hashlib.sha256(raw).hexdigest(),'bytes':len(raw),'units':body['hourly_units'],'grid':{k:body.get(k) for k in ['latitude','longitude','elevation','timezone','utc_offset_seconds']}}
            path.write_bytes(raw); meta.write_text(json.dumps(info,indent=2))
            print('downloaded',name,len(raw),flush=True)
            return body,info
        except HTTPError as error:
            if error.code not in (429,500,502,503,504): raise
            delay = max(float(error.headers.get('Retry-After','0')), min(60,5*2**attempt))
            print('retry',name,error.code,delay,flush=True); time.sleep(delay)
    raise RuntimeError('provider retries exhausted')

def download(cache):
    cache.mkdir(parents=True,exist_ok=True)
    base = {'hourly':','.join(VARIABLES),'models':'era5','temperature_unit':'celsius','wind_speed_unit':'ms','precipitation_unit':'mm','timezone':'Asia/Manila','timeformat':'unixtime','elevation':'nan'}
    mappings, provenance, grids = {},[],{}
    for city,(lat,lon) in zip(CITIES,COORDS):
        params = dict(base,latitude=lat,longitude=lon,start_date='2021-01-01',end_date='2021-01-01')
        body,info = fetch(cache,'grid-'+city,params)
        key = str(body['latitude'])+','+str(body['longitude'])
        mappings[city]=key; grids.setdefault(key,(lat,lon)); provenance.append(info)
    frames=[]
    for index,(grid,(lat,lon)) in enumerate(grids.items()):
        parts=[]
        for year in range(2021,2026):
            body,info = fetch(cache,f'era5-grid{index}-{year}',dict(base,latitude=lat,longitude=lon,start_date=f'{year}-01-01',end_date=f'{year}-12-31'))
            expected = {'time':'unixtime','temperature_2m':'°C','relative_humidity_2m':'%','pressure_msl':'hPa','wind_speed_10m':'m/s','weather_code':'wmo code','rain':'mm'}
            if body['hourly_units'] != expected: raise ValueError('unexpected units')
            if (str(body['latitude'])+','+str(body['longitude'])) != grid: raise ValueError('grid changed')
            f = pd.DataFrame(body['hourly']); f['time']=pd.to_datetime(f.time,unit='s',utc=True).dt.tz_convert('Asia/Manila'); parts.append(f); provenance.append(info)
        f=pd.concat(parts,ignore_index=True); f['grid']=grid
        for city in [c for c,g in mappings.items() if g==grid]:
            c=f.copy(); c['city']=city; frames.append(c)
    return pd.concat(frames,ignore_index=True),provenance,mappings

def metrics(frame,p):
    y=frame.target; w=frame.weight
    result={'brier':float(brier_score_loss(y,p,sample_weight=w)),'logLoss':float(log_loss(y,p,sample_weight=w,labels=[0,1])),'rocAuc':float(roc_auc_score(y,p,sample_weight=w)) if y.nunique()>1 else None,'prAuc':float(average_precision_score(y,p,sample_weight=w)) if y.nunique()>1 else None,'precisionAt60':float(precision_score(y,p>=.6,sample_weight=w,zero_division=0)),'recallAt60':float(recall_score(y,p>=.6,sample_weight=w,zero_division=0)),'prevalence':float(np.average(y,weights=w)),'cityRows':len(frame),'uniqueGridHours':int(frame[['grid','time']].drop_duplicates().shape[0])}
    bins=[]
    for lo in np.arange(0,1,.1):
        mask=(p>=lo)&(p<lo+.1 if lo<.9 else p<=1)
        if mask.any(): bins.append({'lower':float(lo),'count':int(mask.sum()),'meanProbability':float(np.average(p[mask],weights=w[mask])),'observedFrequency':float(np.average(y[mask],weights=w[mask]))})
    result['reliability']=bins
    return result

def train(cache,output):
    data,provenance,mappings=download(cache)
    data=data.dropna(subset=VARIABLES)
    frame=label_rows(data); frame['weight']=duplicate_weights(frame)
    frame['wetFlag']=frame.weather_code.isin(WET).astype(int)
    X=np.asarray([feature_vector(r.temperature_2m,r.relative_humidity_2m,r.pressure_msl,r.wind_speed_10m,r.weather_code,r.city,r.time) for r in frame.itertuples()])
    frame['rowIndex']=np.arange(len(frame)); splits=split_rows(frame)
    tr=splits['train']; va=splits['validation']; te=splits['test']
    xtr=X[tr.rowIndex]; scaler=StandardScaler().fit(xtr,sample_weight=tr.weight)
    # Candidate C values fixed before inspecting 2025; earliest block validates settings.
    early=internal_training_mask(tr); holdout=tr.time.dt.year==2023; internal=[]
    inner_scaler=StandardScaler().fit(xtr[early],sample_weight=tr.weight[early])
    for c in [.01,.1,1.]:
        model=LogisticRegression(C=c,max_iter=1000,random_state=2026,solver='lbfgs').fit(inner_scaler.transform(xtr[early]),tr.target[early],sample_weight=tr.weight[early])
        p=model.predict_proba(inner_scaler.transform(xtr[holdout]))[:,1]
        internal.append((float(brier_score_loss(tr.target[holdout],p,sample_weight=tr.weight[holdout])),c))
    c=min(internal)[1]
    model=LogisticRegression(C=c,max_iter=1000,random_state=2026,solver='lbfgs').fit(scaler.transform(xtr),tr.target,sample_weight=tr.weight)
    baseline=fit_baselines(tr); results={}; passed=True
    for name,f in splits.items():
        p=model.predict_proba(scaler.transform(X[f.rowIndex]))[:,1]
        m=metrics(f,p)
        climate=np.full(len(f),baseline['climatology']); persistence=np.where(f.wetFlag,baseline['wet'],baseline['dry'])
        m['climatologyBrier']=float(brier_score_loss(f.target,climate,sample_weight=f.weight));m['persistenceBrier']=float(brier_score_loss(f.target,persistence,sample_weight=f.weight))
        m['byCity']={city:metrics(f.loc[f.city==city],p[f.city.to_numpy()==city]) for city in CITIES}
        month=f.time.dt.month
        m['bySeason']={season:metrics(f.loc[mask],p[mask.to_numpy()]) for season,mask in [('wetMayOct',month.between(5,10)),('dryNovApr',~month.between(5,10))]}
        results[name]=m
        if name!='train': passed &= m['brier']<min(m['climatologyBrier'],m['persistenceBrier'])
        print(name,{k:v for k,v in m.items() if k not in ['byCity','bySeason','reliability']},flush=True)
    bounds={key:{'min':float(tr[col].min()),'max':float(tr[col].max())} for key,col in zip(list(UNITS),VARIABLES[:4])}
    vectors=[]
    for i in [0,len(va)//2,len(va)-1]:
        r=va.iloc[i]; v=X[int(r.rowIndex)].tolist();prob=sigmoid(float(np.dot((np.asarray(v)-scaler.mean_)/scaler.scale_,model.coef_[0])+model.intercept_[0]))
        vectors.append({'input':{'temperatureC':float(r.temperature_2m),'humidityPercent':float(r.relative_humidity_2m),'pressureHpa':float(r.pressure_msl),'windSpeedMs':float(r.wind_speed_10m),'weatherCode':int(r.weather_code),'city':r.city,'observedAt':r.time.tz_convert('UTC').isoformat()},'features':v,'probability':prob})
    artifact={'schemaVersion':1,'modelVersion':'ncr-era5-logistic-v1','validationPassed':bool(passed),'featureNames':FEATURES,'means':scaler.mean_.tolist(),'scales':scaler.scale_.tolist(),'coefficients':model.coef_[0].tolist(),'intercept':float(model.intercept_[0]),'units':UNITS,'bounds':bounds,'cities':CITIES,'wetWeatherCodes':sorted(WET),'acceptedWeatherCodes':sorted(CODES),'trainingDates':{'train':'2021–2023','validation':'2024','test':'2025'},'target':{'hours':3,'rainThresholdMm':.1,'definition':'sum rainfall t+1,t+2,t+3 >= 0.1 mm'},'regularizationC':c,'internalValidation':internal,'baselines':baseline,'metrics':results,'goldenVectors':vectors,'provenance':{'source':'Open-Meteo Historical Weather API, ERA5','attribution':'Weather data by Open-Meteo.com; ERA5 by Copernicus Climate Change Service (C3S), ECMWF. Contains modified Copernicus Climate Change Service information.','cityGrids':mappings,'requests':provenance,'pipelineSha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'trainingDataSha256':hashlib.sha256(''.join(p['sha256'] for p in provenance).encode()).hexdigest()}}
    export_artifact(artifact,output)
    print('artifact',output,'active',passed,flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--cache',type=Path,default=Path('/workspace/work/ai-weather-data'));parser.add_argument('--output',type=Path,default=ROOT/'assets/models/rain_model.json');args=parser.parse_args();train(args.cache,args.output)
