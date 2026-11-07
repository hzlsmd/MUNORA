import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';
import '../models/weather_snapshot.dart';
import '../services/weather_service.dart';

class WeatherView extends StatefulWidget {
  final String city;
  final WeatherService service;
  final Widget Function(WeatherSnapshot snapshot) builder;
  const WeatherView(
      {super.key,
      required this.city,
      required this.service,
      required this.builder});

  @override
  State<WeatherView> createState() => _WeatherViewState();
}

class _WeatherViewState extends State<WeatherView> with WidgetsBindingObserver {
  WeatherSnapshot? data;
  String? error;
  bool loading = true;
  int request = 0;
  bool saved = false;
  Timer? expiry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    expiry = Timer.periodic(const Duration(minutes: 1), (_) {
      if (data != null && !data!.isUsable(DateTime.now(), offline: true)) {
        setState(() {
          data = null;
          error = 'Saved weather has expired. Please refresh.';
        });
      } else if (data != null && !data!.isUsable(DateTime.now()) && !saved) {
        setState(() => saved = true);
      }
    });
    load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading) load();
  }

  @override
  void dispose() {
    expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WeatherView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city || oldWidget.service != widget.service) {
      data = null;
      load();
    }
  }

  Future<void> load({bool force = false}) async {
    final id = ++request;
    final city = widget.city;
    setState(() {
      loading = true;
      error = null;
      if (data != null && !data!.isUsable(DateTime.now(), offline: true)) {
        data = null;
      }
    });
    WeatherSnapshot? cached;
    try {
      cached = await widget.service.cached(city);
    } catch (_) {/* Continue to the network if local storage fails. */}
    if (!mounted || id != request) return;
    if (cached != null && cached.isUsable(DateTime.now(), offline: true)) {
      setState(() {
        data = cached;
        saved = true;
      });
    }
    try {
      final result = await widget.service.fetch(city, force: force);
      if (mounted && id == request) {
        setState(() {
          data = result;
          saved = false;
        });
      }
    } catch (e) {
      if (mounted && id == request) {
        setState(() => error = e is WeatherException
            ? e.message
            : 'Weather is temporarily unavailable.');
      }
    } finally {
      if (mounted && id == request) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.city,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 16),
                  if (loading)
                    const CircularProgressIndicator()
                  else ...[
                    Text(error ?? 'No weather is available.',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                        onPressed: () => load(force: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry')),
                  ],
                ],
              )));
    }
    return Column(children: [
      Material(
        color:
            error == null ? const Color(0xFFF1F5F9) : const Color(0xFFFFF3CD),
        child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
              child: Row(children: [
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (saved || error != null)
                      Text('Saved weather. ${error ?? ''}',
                          style: const TextStyle(fontSize: 11)),
                    if (data!.source == 'Open-Meteo')
                      Wrap(spacing: 8, children: [
                        Link(
                            uri: Uri.parse('https://open-meteo.com/'),
                            target: LinkTarget.blank,
                            builder: (context, follow) => InkWell(
                                onTap: follow,
                                child: const Text('Weather data by Open-Meteo',
                                    style: TextStyle(
                                        fontSize: 11,
                                        decoration:
                                            TextDecoration.underline)))),
                        Link(
                            uri: Uri.parse(
                                'https://creativecommons.org/licenses/by/4.0/'),
                            target: LinkTarget.blank,
                            builder: (context, follow) => InkWell(
                                onTap: follow,
                                child: const Text('CC BY 4.0',
                                    style: TextStyle(
                                        fontSize: 11,
                                        decoration:
                                            TextDecoration.underline)))),
                      ])
                    else
                      const Text('OpenWeatherMap',
                          style: TextStyle(fontSize: 11)),
                    Text(
                        '${data!.source == 'Open-Meteo' ? 'Model estimate' : 'Observed'} ${weatherTime(data!.observedAt)}',
                        style: const TextStyle(fontSize: 11)),
                    Text('Updated ${weatherTime(data!.updatedAt)}',
                        style: const TextStyle(fontSize: 11)),
                  ],
                )),
                if (loading)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                else
                  IconButton(
                      onPressed: () => load(force: true),
                      tooltip: 'Refresh weather',
                      icon: const Icon(Icons.refresh)),
              ]),
            )),
      ),
      Expanded(child: widget.builder(data!)),
    ]);
  }
}
