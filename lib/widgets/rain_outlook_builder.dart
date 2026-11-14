import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/weather_snapshot.dart';
import '../services/rain_model.dart';
import '../services/rain_outlook.dart';
import 'weather_view.dart';

/// Both cards share RainModelLoader's memoized asset; no weather requests here.
class RainOutlookBuilder extends StatefulWidget {
  final WeatherSnapshot weather;
  final RainModelLoader? loader;
  final Widget Function(RainOutlook outlook, bool loading, String? modelVersion)
  builder;
  const RainOutlookBuilder({
    super.key,
    required this.weather,
    this.loader,
    required this.builder,
  });

  @override
  State<RainOutlookBuilder> createState() => _RainOutlookBuilderState();
}

class _RainOutlookBuilderState extends State<RainOutlookBuilder> {
  late Future<RainModel?> model;
  Timer? expiry;
  @override
  void initState() {
    super.initState();
    model = (widget.loader ?? RainModelLoader.instance).load();
    expiry = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant RainOutlookBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loader != widget.loader) {
      model = (widget.loader ?? RainModelLoader.instance).load();
    }
  }

  @override
  void dispose() {
    expiry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final live = WeatherLiveStatus.of(context);
    return FutureBuilder<RainModel?>(
      future: model,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final loaded = loading ? null : snapshot.data;
        final outlook = evaluateRainOutlook(
          widget.weather,
          model: loaded,
          live: live,
          now: DateTime.now().toUtc(),
        );
        return widget.builder(outlook, loading, loaded?.version);
      },
    );
  }
}
