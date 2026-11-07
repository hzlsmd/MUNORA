import 'package:flutter/material.dart';
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

class _WeatherViewState extends State<WeatherView> {
  WeatherSnapshot? data;
  String? error;
  bool loading = true;
  int request = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant WeatherView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city != widget.city || oldWidget.service != widget.service) {
      data = null;
      load();
    }
  }

  Future<void> load() async {
    final id = ++request;
    final city = widget.city;
    setState(() {
      loading = true;
      error = null;
    });
    final cached = await widget.service.cached(city);
    if (!mounted || id != request) return;
    if (cached != null) setState(() => data = cached);
    try {
      final result = await widget.service.fetch(city);
      if (mounted && id == request) setState(() => data = result);
    } on WeatherException catch (e) {
      if (mounted && id == request) setState(() => error = e.message);
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
                        onPressed: load,
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
                    child: Text(
                  '${error == null ? '' : 'Saved weather. $error\n'}OpenWeatherMap\nObserved ${weatherTime(data!.observedAt)}',
                  style: const TextStyle(fontSize: 11),
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
                      onPressed: load,
                      tooltip: 'Refresh weather',
                      icon: const Icon(Icons.refresh)),
              ]),
            )),
      ),
      Expanded(child: widget.builder(data!)),
    ]);
  }
}
