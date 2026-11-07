import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/supported_cities.dart';
import '../models/city_weather.dart';
import '../services/weather_service.dart';
import '../theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/weather_icon.dart';
import '../widgets/weather_view.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<AppScreen> navigate;
  final ValueChanged<String> onCityChange;
  final String city;
  final WeatherService service;
  const HomeScreen(
      {super.key,
      required this.navigate,
      required this.onCityChange,
      required this.city,
      required this.service});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int activeHour = 0;
  bool showPicker = false;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Column(children: [
        SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Expanded(
                    child: TextButton.icon(
                  onPressed: () => setState(() => showPicker = true),
                  icon: const Icon(Icons.location_on_outlined),
                  label: Text(widget.city, overflow: TextOverflow.ellipsis),
                )),
                IconButton(
                    onPressed: () => widget.navigate(AppScreen.alerts),
                    tooltip: 'Weather alerts',
                    icon: const Icon(Icons.notifications_outlined)),
              ]),
            )),
        Expanded(
            child: WeatherView(
                city: widget.city,
                service: widget.service,
                builder: (snapshot) => SingleChildScrollView(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Hero(loc: snapshot.current),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: _StatsCard(loc: snapshot.current)),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            child: _HourlyCard(
                                points: snapshot.hourly.take(8).toList(),
                                activeHour: activeHour,
                                onSelect: (i) => setState(() => activeHour = i),
                                onViewMore: () =>
                                    widget.navigate(AppScreen.forecast))),
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: _CtaButton(
                                color: AppColors.skyBlueTop,
                                icon: Icons.calendar_month_rounded,
                                label: 'View 5-Day Forecast',
                                onTap: () =>
                                    widget.navigate(AppScreen.forecast))),
                      ],
                    )))),
        BottomNav(active: AppScreen.home, onNavigate: widget.navigate),
      ]),
      if (showPicker)
        Positioned.fill(
            child: _CityPickerModal(
          selectedIdx: supportedCities.indexOf(widget.city),
          onSelect: (i) {
            setState(() {
              showPicker = false;
              activeHour = 0;
            });
            widget.onCityChange(supportedCities[i]);
          },
          onClose: () => setState(() => showPicker = false),
        )),
    ]);
  }
}

class _Hero extends StatelessWidget {
  final CityWeather loc;
  const _Hero({required this.loc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(gradient: AppColors.skyGradient),
      child: Row(children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text('${loc.temp}\u00b0C',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 72,
                      fontWeight: FontWeight.w800))),
          Text(loc.condition,
              style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 4),
          Text('Feels like ${loc.feelsLike}',
              style: const TextStyle(color: Colors.white, fontSize: 14)),
        ])),
        const SizedBox(width: 12),
        WeatherIcon(condition: loc.condition, size: 80),
      ]),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final CityWeather loc;
  const _StatsCard({required this.loc});

  @override
  Widget build(BuildContext context) {
    final stats = [
      (Icons.water_drop_outlined, 'Humidity', loc.humidity),
      (Icons.speed, 'Pressure', loc.pressure),
      (Icons.air, 'Wind speed', loc.wind),
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
                  Icon(emoji, size: 22, color: AppColors.skyBlueTop),
                  const SizedBox(height: 6),
                  Text(val,
                      style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.textGray, fontSize: 10)),
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
  final List<HourlyPoint> points;
  final int activeHour;
  final ValueChanged<int> onSelect;
  final VoidCallback onViewMore;
  const _HourlyCard(
      {required this.points,
      required this.activeHour,
      required this.onSelect,
      required this.onViewMore});

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                  child: Text('3-Hour Forecast',
                      style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w700))),
              IconButton(
                onPressed: onViewMore,
                tooltip: 'View forecast',
                icon: const Icon(Icons.arrow_forward,
                    color: AppColors.skyBlueTop),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 166 * scale,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: points.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final h = points[i];
                final active = activeHour == i;
                return GestureDetector(
                  onTap: () => onSelect(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 90 * scale,
                    padding:
                        const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFFEEF6FF)
                          : const Color(0xFFFAFBFD),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color:
                              active ? AppColors.skyBlueTop : AppColors.divider,
                          width: 2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(h.time,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: active
                                    ? AppColors.skyBlueTop
                                    : AppColors.textGray,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        WeatherIcon(condition: h.condition, size: 32),
                        const SizedBox(height: 8),
                        Text(h.temp,
                            style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
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
  const _CtaButton(
      {required this.color,
      required this.icon,
      required this.label,
      required this.onTap});

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
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
  const _CityPickerModal(
      {required this.selectedIdx,
      required this.onSelect,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0x73142850),
        child: SafeArea(
            child: Center(
                child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440, maxHeight: 560),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                onTap: () {},
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(children: [
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Choose City',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('National Capital Region (NCR)',
                                style: TextStyle(fontSize: 11)),
                          ])),
                      IconButton(
                          onPressed: onClose,
                          tooltip: 'Close city picker',
                          icon: const Icon(Icons.close)),
                    ]),
                  ),
                  const Divider(height: 1),
                  Flexible(
                      child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: supportedCities.length,
                    itemBuilder: (context, i) => ListTile(
                      selected: i == selectedIdx,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(supportedCities[i]),
                      subtitle: const Text('NCR, Philippines'),
                      trailing: i == selectedIdx
                          ? const Icon(Icons.check_circle)
                          : null,
                      onTap: () => onSelect(i),
                    ),
                  )),
                ]),
              ),
            ),
          ),
        ))),
      ),
    );
  }
}
