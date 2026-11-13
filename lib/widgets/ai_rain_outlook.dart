import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import '../services/rain_model.dart';
import '../theme.dart';
import 'atmosphere.dart';
import 'weather_view.dart';

class AIRainOutlook extends StatefulWidget {
  final WeatherSnapshot weather;
  final RainModelLoader? loader;
  const AIRainOutlook({super.key, required this.weather, this.loader});
  @override
  State<AIRainOutlook> createState() => _AIRainOutlookState();
}

class _AIRainOutlookState extends State<AIRainOutlook> {
  late Future<RainModel?> _model;
  Timer? _expiry;
  @override
  void initState() {
    super.initState();
    _model = (widget.loader ?? RainModelLoader.instance).load();
    _expiry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _expiry?.cancel();
    super.dispose();
  }

  RainPrediction? _predict(RainModel? model, bool live) {
    final w = widget.weather;
    final now = DateTime.now().toUtc();
    if (!live ||
        w.source != 'Open-Meteo' ||
        w.humidity == null ||
        w.pressure == null ||
        w.weatherCode == null ||
        !w.isUsable(now)) {
      return null;
    }
    return model?.predict(
      RainInput(
        temperatureC: w.temperature,
        humidityPercent: w.humidity!,
        pressureHpa: w.pressure!,
        windSpeedMs: w.windSpeed,
        weatherCode: w.weatherCode!,
        city: w.city,
        observedAt: w.observedAt,
      ),
      now: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    final live = WeatherLiveStatus.of(context);
    return FutureBuilder<RainModel?>(
      future: _model,
      builder: (context, snapshot) {
        final prediction = _predict(snapshot.data, live);
        return GlassCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'AI rain outlook',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              const Text(
                'Experimental estimate',
                style: TextStyle(fontSize: 12, color: AppColors.indigo),
              ),
              const SizedBox(height: 10),
              if (prediction == null)
                Text(
                  snapshot.connectionState == ConnectionState.waiting
                      ? 'Loading rain model…'
                      : 'Unavailable. A validated model and fresh supported live weather are required.',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                )
              else ...[
                Text(
                  '${formatRainProbability(prediction.probability)} probability of rain',
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'From ${weatherTime(prediction.estimatedAt)}\nThrough ${weatherTime(prediction.windowEnd)} (3 hours)',
                  style: const TextStyle(fontSize: 12, height: 1.5),
                ),
                if (prediction.probability >= .6) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Carry rain protection and consider a sheltered backup plan.',
                    style: TextStyle(fontSize: 12, height: 1.5),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Chance of at least 0.1 mm total rain. Probability is not accuracy. Keep checking current conditions and official advisories.',
                  style: TextStyle(fontSize: 11, height: 1.5),
                ),
              ],
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Model details',
                  style: TextStyle(fontSize: 12),
                ),
                children: [
                  Text(
                    'Model: ${snapshot.data?.version ?? 'unavailable'}. Trained on 2021–2023 Open-Meteo ERA5 gridded reanalysis; evaluated on 2024–2025. Nearby cities may share a grid. Live predictive performance still needs prospective validation. Data: Open-Meteo (CC BY 4.0), ERA5 / Copernicus Climate Change Service.',
                    style: const TextStyle(fontSize: 11, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
