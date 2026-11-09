import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_snapshot.dart';
import '../services/weather_insights.dart';
import '../theme.dart';
import 'atmosphere.dart';

class InsightView extends StatefulWidget {
  final String city;
  final WeatherInsightsService? service;
  final Widget Function(WeatherInsights? data) builder;
  const InsightView({
    super.key,
    required this.city,
    required this.service,
    required this.builder,
  });
  @override
  State<InsightView> createState() => _InsightViewState();
}

class _InsightViewState extends State<InsightView> {
  late Future<WeatherInsights?> future;
  Timer? refresh;
  @override
  void initState() {
    super.initState();
    future = widget.service?.fetch(widget.city) ?? Future.value(null);
    if (widget.service != null) {
      refresh = Timer.periodic(const Duration(minutes: 1), (_) {
        setState(() {
          future = widget.service!.fetch(widget.city);
        });
      });
    }
  }

  @override
  void dispose() {
    refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<WeatherInsights?>(
    future: future,
    builder: (context, snapshot) => widget.builder(snapshot.data),
  );
}

String metric(double? value, String suffix) =>
    value == null ? 'Unavailable' : '${value.round()}$suffix';
String uvCategory(double? uv) => uv == null
    ? 'No UV reading'
    : uv < 3
    ? 'Low'
    : uv < 6
    ? 'Moderate'
    : uv < 8
    ? 'High'
    : uv < 11
    ? 'Very high'
    : 'Extreme';

class CalmMetrics extends StatelessWidget {
  final String wind;
  final WeatherInsights? insights;
  const CalmMetrics({super.key, required this.wind, this.insights});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = MediaQuery.textScalerOf(context).scale(12) > 16
          ? 104.0
          : (constraints.maxWidth - 24) / 3;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: [
          _metric('Wind', wind, 'Current estimate', width),
          _metric(
            'Precip Prob',
            metric(insights?.rainProbability, '%'),
            'Current hour',
            width,
          ),
          _metric(
            'UV Index',
            metric(insights?.uvIndex, ''),
            uvCategory(insights?.uvIndex),
            width,
          ),
        ],
      );
    },
  );
  Widget _metric(String label, String value, String detail, double width) =>
      Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xB3FFFFFF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textBody),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: AppColors.indigo),
            ),
          ],
        ),
      );
}

class ModelAgreementPanel extends StatelessWidget {
  final WeatherInsights? insights;
  const ModelAgreementPanel({super.key, this.insights});
  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: const Text(
        'Model agreement',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        insights?.agreementPercent == null
            ? 'Unavailable — no complete comparison'
            : '${insights!.agreementPercent}% agreement · 3 models',
        style: const TextStyle(fontSize: 12, color: AppColors.indigo),
      ),
      children: const [
        Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            'ECMWF, GFS and ICON are compared over the next six forecast hours. A wet hour means at least 0.1 mm of rain. The percentage is the average share agreeing on wet/dry conditions. It is not a probability of accuracy or an AI confidence score.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
        ),
      ],
    ),
  );
}

class OutdoorPanel extends StatelessWidget {
  final WeatherInsights? insights;
  const OutdoorPanel({super.key, this.insights});
  @override
  Widget build(BuildContext context) => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEBD6FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(child: DesignIcon('a7a0c')),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Outdoor activity window',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (insights?.outdoorStart != null) ...[
          Text(
            '${weatherTime(insights!.outdoorStart!)} – ${weatherTime(insights!.outdoorEnd!)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.indigo,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A lower-rain, lower-UV option in the available forecast. Recheck conditions before heading out.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text(metric(insights!.outdoorTemperature, '°C'))),
              Chip(label: Text('UV ${metric(insights!.outdoorUv, '')}')),
              Chip(
                label: Text(
                  'Humidity ${metric(insights!.outdoorHumidity, '%')}',
                ),
              ),
            ],
          ),
        ] else
          const Text(
            'No suitable window is available in the current data. Check the forecast before planning outdoor activities.',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: AppColors.textBody,
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Three consecutive daytime hours: rain chance ≤30%, temperature ≤31°C and UV ≤5. This is planning guidance, not a safety guarantee.',
          style: TextStyle(
            fontSize: 11,
            height: 1.5,
            color: AppColors.textBody,
          ),
        ),
      ],
    ),
  );
}

class GuidanceFeedback extends StatefulWidget {
  final String city;
  const GuidanceFeedback({super.key, required this.city});
  @override
  State<GuidanceFeedback> createState() => _GuidanceFeedbackState();
}

class _GuidanceFeedbackState extends State<GuidanceFeedback> {
  int? value;
  bool touched = false;
  Future<void> writes = Future.value();
  String get keyName => 'tips.feedback.${widget.city}';
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted && !touched) setState(() => value = prefs.getInt(keyName));
    } catch (_) {}
  }

  void choose(int choice) {
    touched = true;
    setState(() => value = value == choice ? null : choice);
    final selected = value;
    final key = keyName;
    writes = writes.then((_) async {
      try {
        final p = await SharedPreferences.getInstance();
        if (selected == null) {
          await p.remove(key);
        } else {
          await p.setInt(key, selected);
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Feedback could not be saved.')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => GlassCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Was this guidance helpful?',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        const Text(
          'Feedback stays on this device.',
          style: TextStyle(fontSize: 12, color: AppColors.textBody),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              tooltip: 'Helpful',
              isSelected: value == 1,
              onPressed: () => choose(1),
              icon: const DesignIcon('c7413'),
              selectedIcon: const Icon(Icons.thumb_up, color: AppColors.indigo),
            ),
            IconButton(
              tooltip: 'Not helpful',
              isSelected: value == -1,
              onPressed: () => choose(-1),
              icon: const DesignIcon('63099'),
              selectedIcon: const Icon(
                Icons.thumb_down,
                color: AppColors.indigo,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
