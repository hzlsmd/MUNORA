import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/city_weather.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_icon.dart';

class ForecastScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final String city;
  const ForecastScreen({super.key, required this.navigate, required this.city});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  bool weeklyTab = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    decoration: const BoxDecoration(gradient: AppColors.skyGradient),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => widget.navigate(AppScreen.home),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0x33FFFFFF),
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0x4DFFFFFF)),
                              ),
                              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('7-Day Forecast', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(widget.city, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                      const Text('NCR, Philippines', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: const Color(0xFFE2EBF5), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(child: _TabButton(label: 'Hourly', active: !weeklyTab, onTap: () => setState(() => weeklyTab = false))),
                          Expanded(child: _TabButton(label: 'Weekly', active: weeklyTab, onTap: () => setState(() => weeklyTab = true))),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: weeklyTab
                          ? weekly.map((d) => _WeeklyTile(d: d)).toList()
                          : forecastHourly.map((h) => _HourlyTile(h: h)).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          BottomNav(active: AppScreen.forecast, onNavigate: widget.navigate),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TabButton({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: active ? const [BoxShadow(color: Color(0x1A0050B4), blurRadius: 8, offset: Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: active ? AppColors.skyBlueTop : AppColors.textGray)),
      ),
    );
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
        border: d.today ? Border.all(color: AppColors.skyBlueTop, width: 2) : Border.all(color: Colors.transparent, width: 2),
      ),
      child: Row(
        children: [
          WeatherIcon(condition: d.cond, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(d.day, style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: d.today ? FontWeight.w700 : FontWeight.w500)),
                Text(d.cond, style: const TextStyle(color: AppColors.textGray, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(d.hi, style: const TextStyle(color: AppColors.red, fontSize: 15, fontWeight: FontWeight.w700)),
              Text(d.lo, style: const TextStyle(color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w500)),
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
          Expanded(child: Text(h.time, style: const TextStyle(color: AppColors.textBody, fontSize: 14))),
          Text(h.temp, style: const TextStyle(color: AppColors.textDark, fontSize: 16, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
