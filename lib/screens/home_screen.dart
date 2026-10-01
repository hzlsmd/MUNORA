import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/mock_data.dart';
import '../models/city_weather.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_icon.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final ValueChanged<String> onCityChange;

  const HomeScreen({super.key, required this.navigate, required this.onCityChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedIdx = 0;
  int activeHour = 0;
  bool showPicker = false;

  CityWeather get loc => cities[selectedIdx];

  void selectCity(int i) {
    setState(() {
      selectedIdx = i;
      showPicker = false;
    });
    widget.onCityChange(cities[i].city);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          color: AppColors.bg,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(loc: loc, onPickCity: () => setState(() => showPicker = true), onBell: () => widget.navigate(AppScreen.alerts)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: _StatsCard(loc: loc),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: _HourlyCard(
                          activeHour: activeHour,
                          onSelect: (i) => setState(() => activeHour = i),
                          onViewMore: () => widget.navigate(AppScreen.forecast),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _CtaButton(
                                color: AppColors.skyBlueTop,
                                icon: Icons.calendar_month_rounded,
                                label: 'View 7-Day Forecast ›',
                                onTap: () => widget.navigate(AppScreen.forecast),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _CtaButton(
                                color: AppColors.indigo,
                                icon: Icons.add_box_outlined,
                                label: 'Ask AI ›',
                                onTap: () => widget.navigate(AppScreen.ai),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              BottomNav(active: AppScreen.home, onNavigate: widget.navigate),
            ],
          ),
        ),
        if (showPicker)
          _CityPickerModal(
            selectedIdx: selectedIdx,
            onSelect: selectCity,
            onClose: () => setState(() => showPicker = false),
          ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  final CityWeather loc;
  final VoidCallback onPickCity;
  final VoidCallback onBell;
  const _Hero({required this.loc, required this.onPickCity, required this.onBell});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 32),
      decoration: const BoxDecoration(gradient: AppColors.skyGradient),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: onPickCity,
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${loc.city} City',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                            const Text('NCR, Philippines', style: TextStyle(color: Color(0xBFFFFFFF), fontSize: 11)),
                          ],
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_drop_down, color: Color(0xCCFFFFFF), size: 18),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onBell,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.skyBlueTop,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0x4DFFFFFF), width: 2),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.notifications, color: Colors.white, size: 20),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3B30),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(loc.temp,
                              style: GoogleFonts.poppins(
                                  color: Colors.white, fontSize: 88, fontWeight: FontWeight.w800, height: 1, letterSpacing: -3)),
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Text('°C',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      Text(loc.condition,
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                      Text('Feels like ${loc.feelsLike}', style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 14)),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: WeatherIcon(condition: loc.condition, size: 110),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final CityWeather loc;
  const _StatsCard({required this.loc});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('💧', 'Humidity', loc.humidity),
      ('🌡️', 'Pressure', loc.pressure),
      ('☀️', 'UV Index', loc.uvNum),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: cardDecoration(),
      child: Row(
        children: List.generate(stats.length, (i) {
          final (emoji, label, val) = stats[i];
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                border: i < stats.length - 1
                    ? const Border(right: BorderSide(color: AppColors.divider))
                    : null,
              ),
              child: Column(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 22)),
                  const SizedBox(height: 6),
                  Text(val, style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(label, style: const TextStyle(color: AppColors.textGray, fontSize: 10)),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _HourlyCard extends StatelessWidget {
  final int activeHour;
  final ValueChanged<int> onSelect;
  final VoidCallback onViewMore;
  const _HourlyCard({required this.activeHour, required this.onSelect, required this.onViewMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hourly Forecast', style: TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: onViewMore,
                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                child: const Text('View more ›', style: TextStyle(color: AppColors.skyBlueTop, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: hourlyBase.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final h = hourlyBase[i];
                final active = activeHour == i;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 72,
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: active ? const Color(0xFFEEF6FF) : const Color(0xFFFAFBFD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? AppColors.skyBlueTop : AppColors.divider, width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(h.time, style: TextStyle(color: active ? AppColors.skyBlueTop : AppColors.textGray, fontSize: 11, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        WeatherIcon(condition: h.condition, size: 32),
                        const SizedBox(height: 8),
                        Text(h.temp, style: const TextStyle(color: AppColors.textDark, fontSize: 13, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _CtaButton({required this.color, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _CityPickerModal extends StatelessWidget {
  final int selectedIdx;
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;
  const _CityPickerModal({required this.selectedIdx, required this.onSelect, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: const Color(0x73142850),
        padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
        child: GestureDetector(
          onTap: () {}, // swallow taps inside the sheet
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 560),
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Choose City', style: TextStyle(color: AppColors.textDark, fontSize: 17, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('National Capital Region (NCR)', style: TextStyle(color: AppColors.textGray, fontSize: 11)),
                          ],
                        ),
                        InkWell(
                          onTap: onClose,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(color: AppColors.divider, shape: BoxShape.circle),
                            child: const Icon(Icons.close, size: 16, color: Color(0xFF555555)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: cities.length,
                      itemBuilder: (context, i) {
                        final c = cities[i];
                        final sel = i == selectedIdx;
                        return InkWell(
                          onTap: () => onSelect(i),
                          child: Container(
                            color: sel ? const Color(0xFFEEF6FF) : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                            decoration: const BoxDecoration(
                              border: Border(bottom: BorderSide(color: Color(0xFFF5F7FA))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: sel ? const Color(0xFFDBEEFF) : AppColors.divider,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: WeatherIcon(condition: c.condition, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.city,
                                            style: TextStyle(
                                                color: AppColors.textDark,
                                                fontSize: 14,
                                                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
                                        const Text('NCR, Philippines', style: TextStyle(color: AppColors.textGray, fontSize: 11)),
                                      ],
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('${c.temp}°C', style: const TextStyle(color: AppColors.skyBlueTop, fontSize: 16, fontWeight: FontWeight.w700)),
                                    if (sel) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 18,
                                        height: 18,
                                        decoration: const BoxDecoration(color: AppColors.skyBlueTop, shape: BoxShape.circle),
                                        child: const Icon(Icons.check, size: 12, color: Colors.white),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
