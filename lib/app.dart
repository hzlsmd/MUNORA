import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/ai_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/forecast_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/bottom_nav.dart';

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
          onCityChange: (c) => setState(() => selectedCity = c),
        );
        break;
      case AppScreen.forecast:
        body = ForecastScreen(navigate: navigate, city: selectedCity);
        break;
      case AppScreen.alerts:
        body = AlertsScreen(navigate: navigate, city: selectedCity);
        break;
      case AppScreen.ai:
        body = AIScreen(navigate: navigate);
        break;
    }

    return Scaffold(body: ClipRRect(child: body));
  }
}
