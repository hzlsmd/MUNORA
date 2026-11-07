import 'package:flutter/material.dart';
import '../models/city_weather.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_icon.dart';
import '../widgets/weather_view.dart';

class ForecastScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  final WeatherService service;
  const ForecastScreen(
      {super.key,
      required this.navigate,
      required this.city,
      required this.service});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  bool dailyTab = true;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(children: [
              IconButton(
                  onPressed: () => widget.navigate(AppScreen.home),
                  tooltip: 'Back to weather',
                  icon: const Icon(Icons.arrow_back)),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    const Text('5-Day Forecast',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    Text(widget.city),
                  ])),
            ]),
          )),
      Expanded(
          child: WeatherView(
              city: widget.city,
              service: widget.service,
              builder: (snapshot) => SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                  value: false,
                                  icon: Icon(Icons.schedule),
                                  label: Text('3-Hour')),
                              ButtonSegment(
                                  value: true,
                                  icon: Icon(Icons.calendar_today),
                                  label: Text('Daily')),
                            ],
                            selected: {dailyTab},
                            onSelectionChanged: (value) =>
                                setState(() => dailyTab = value.single),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                              'Philippine time (PHT). Daily ranges cover available 3-hour forecasts; the first day may be partial.',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.textGray)),
                          const SizedBox(height: 12),
                          if (dailyTab)
                            ...snapshot.daily.map((d) => _WeeklyTile(d: d))
                          else
                            ...snapshot.hourly.map((h) => _HourlyTile(h: h)),
                        ]),
                  ))),
      BottomNav(active: AppScreen.forecast, onNavigate: widget.navigate),
    ]);
  }
}

class _WeeklyTile extends StatelessWidget {
  final DailyPoint d;
  const _WeeklyTile({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: cardDecoration(
        border: d.today
            ? Border.all(color: AppColors.skyBlueTop, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          WeatherIcon(condition: d.cond, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.day,
                    style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 14,
                        fontWeight:
                            d.today ? FontWeight.w700 : FontWeight.w500)),
                Text(d.cond,
                    style: const TextStyle(
                        color: AppColors.textGray, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(d.hi,
                  style: const TextStyle(
                      color: AppColors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              Text(d.lo,
                  style: const TextStyle(
                      color: AppColors.blue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourlyTile extends StatelessWidget {
  final HourlyPoint h;
  const _HourlyTile({required this.h});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 71,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: cardDecoration(),
      child: Row(
        children: [
          WeatherIcon(condition: h.condition, size: 32),
          const SizedBox(width: 12),
          Expanded(
              child: Text(h.time,
                  style: const TextStyle(
                      color: AppColors.textBody, fontSize: 14))),
          Text(h.temp,
              style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
