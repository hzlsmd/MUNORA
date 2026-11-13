import importlib.util
import math
import pathlib
import unittest
import numpy as np
import pandas as pd

MODULE = pathlib.Path(__file__).parents[1] / 'rain_model.py'

class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(MODULE.exists(), 'training pipeline is implemented')
        spec = importlib.util.spec_from_file_location('rain_model', MODULE)
        self.m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.m)

    def frame(self, start='2023-12-31T20:00', count=10):
        return pd.DataFrame({'time':pd.date_range(start, periods=count, freq='h', tz='Asia/Manila'), 'rain':[0,.1,0,0,0,.1,0,0,0,0][:count], 'city':['manila']*count,'grid':['x']*count})

    def test_labels_are_future_only_and_split_boundary_is_purged(self):
        f = self.m.label_rows(self.frame())
        self.assertEqual(list(f.target[:4]), [1,0,1,1])
        self.assertEqual(len(f),7)
        train = self.m.split_rows(f)['train']
        self.assertEqual(len(train),1)

    def test_missing_unordered_duplicate_hours_are_not_valid_labels(self):
        f = self.frame().drop(index=2).iloc[::-1]
        labeled = self.m.label_rows(f)
        self.assertTrue((labeled.time >= self.frame().time[3]).all())
        with self.assertRaises(ValueError):
            self.m.label_rows(pd.concat([self.frame(),self.frame().iloc[:1]]))

    def test_feature_order_cycles_and_city_encoding(self):
        x = self.m.feature_vector(30,80,1000,2,61,'manila',pd.Timestamp('2024-01-01T00:00:00+08:00'))
        self.assertEqual(x[:5], [30,80,1000,2,1])
        self.assertAlmostEqual(x[5],0)
        self.assertAlmostEqual(x[6],1)
        self.assertAlmostEqual(x[7],0)
        self.assertEqual(x[10],1)
        self.assertEqual(sum(x[9:]),1)
        with self.assertRaises(ValueError):
            self.m.feature_vector(30,101,1000,2,61,'manila',pd.Timestamp('2024-01-01'))

    def test_baselines_are_fitted_only_from_training_and_weight_grid_duplicates(self):
        f = pd.DataFrame({'target':[0,1,1], 'wetFlag':[0,0,1], 'weight':[.5,.5,1.]})
        b = self.m.fit_baselines(f)
        self.assertEqual(b,{'climatology':.75,'dry':.5,'wet':1.})
        rows = pd.DataFrame({'grid':['a','a','b'],'time':[1,1,1]})
        np.testing.assert_allclose(self.m.duplicate_weights(rows),[.5,.5,1])

    def test_internal_tuning_split_purges_labels_crossing_2023(self):
        frame = self.m.label_rows(self.frame(start='2022-12-31T20:00'))
        early = self.m.internal_training_mask(frame)
        self.assertEqual(early.sum(),1)
        self.assertTrue((frame.loc[early].targetEnd.dt.year < 2023).all())

    def test_export_prediction_uses_stable_sigmoid(self):
        self.assertEqual(self.m.sigmoid(-1000),0)
        self.assertEqual(self.m.sigmoid(1000),1)

if __name__ == '__main__': unittest.main()

class ArtifactTests(unittest.TestCase):
    def test_actual_export_is_finite_and_golden_vectors_match(self):
        import json
        artifact = pathlib.Path(__file__).parents[2]/'assets/models/rain_model.json'
        self.assertTrue(artifact.exists(), 'actual trained numeric artifact exists')
        self.assertLess(artifact.stat().st_size, 30000)
        a=json.loads(artifact.read_text())
        self.assertEqual(a['schemaVersion'],1)
        self.assertEqual(a['target']['futureOffsets'],[1,2,3])
        self.assertEqual(a['featureTransform'],{'timezone':'Asia/Manila','hour':'hour+minute/60+second/3600','season':'(dayOfYear-1+hour/24)/365.2425'})
        self.assertEqual(len(a['featureNames']),26)
        for key in ['means','scales','coefficients']:
            self.assertEqual(len(a[key]),26)
            self.assertTrue(all(math.isfinite(v) for v in a[key]))
        self.assertTrue(all(v>0 for v in a['scales']))
        for vector in a['goldenVectors']:
            z = sum((x-m)/s*c for x,m,s,c in zip(vector['features'],a['means'],a['scales'],a['coefficients'])) + a['intercept']
            p = 1/(1+math.exp(-z)) if z>=0 else math.exp(z)/(1+math.exp(z))
            self.assertAlmostEqual(p, vector['probability'], places=13)
        expected = all(a['metrics'][split]['brier'] < min(a['metrics'][split]['climatologyBrier'],a['metrics'][split]['persistenceBrier']) for split in ['validation','test'])
        self.assertEqual(a['validationPassed'],expected)
