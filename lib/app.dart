import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/supported_cities.dart';
import 'services/weather_service.dart';

import 'screens/ai_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/forecast_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/bottom_nav.dart';
import 'widgets/demo_notice.dart';

class MunoraApp extends StatelessWidget {
  const MunoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MUNORA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFEEF4FB),
      ),
      home: const _RootScreen(),
    );
  }
}

class _RootScreen extends StatefulWidget {
  const _RootScreen();

  @override
  State<_RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<_RootScreen> {
  AppScreen screen = AppScreen.splash;
  String selectedCity = 'Muntinlupa';
  final weatherService = WeatherService();

  @override
  void initState() {
    super.initState();
    restoreCity();
  }

  Future<void> restoreCity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('selectedCity');
      if (mounted && saved != null && supportedCities.contains(saved)) {
        setState(() => selectedCity = saved);
      }
    } catch (_) {
      /* Keep the default when storage is unavailable. */
    }
  }

  Future<void> selectCity(String city) async {
    setState(() => selectedCity = city);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selectedCity', city);
    } catch (_) {
      /* Selection still works without persistent storage. */
    }
  }

  @override
  void dispose() {
    weatherService.dispose();
    super.dispose();
  }

  void navigate(AppScreen s) => setState(() => screen = s);

  @override
  Widget build(BuildContext context) {
    Widget body;
    switch (screen) {
      case AppScreen.splash:
        body = SplashScreen(onDone: () => navigate(AppScreen.home));
        break;
      case AppScreen.home:
        body = HomeScreen(
          navigate: navigate,
          city: selectedCity,
          service: weatherService,
          onCityChange: selectCity,
        );
        break;
      case AppScreen.forecast:
        body = ForecastScreen(
          navigate: navigate,
          city: selectedCity,
          service: weatherService,
        );
        break;
      case AppScreen.alerts:
        body = DemoNotice(
          message: 'Demo alerts only. These are sample warnings, not current official advisories.',
          child: AlertsScreen(navigate: navigate, city: selectedCity),
        );
        break;
      case AppScreen.ai:
        body = AIScreen(
          navigate: navigate,
          city: selectedCity,
          service: weatherService,
        );
        break;
    }

    return Scaffold(body: ClipRRect(child: body));
  }
}
