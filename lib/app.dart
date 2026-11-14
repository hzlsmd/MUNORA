import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/supported_cities.dart';
import 'services/weather_service.dart';
import 'services/notification_service.dart';
import 'services/push_notifications.dart';
import 'services/push_state.dart';
import 'services/weather_insights.dart';

import 'screens/ai_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/forecast_screen.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';
import 'widgets/bottom_nav.dart';
import 'theme.dart';

class MunoraApp extends StatelessWidget {
  const MunoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MUNORA',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.indigo),
        scaffoldBackgroundColor: AppColors.bg,
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

class _RootScreenState extends State<_RootScreen> with WidgetsBindingObserver {
  PushAlert? pendingAlert;
  AppScreen screen = AppScreen.splash;
  String selectedCity = 'Muntinlupa';
  bool openPlannerOnLoad = false;
  final weatherService = WeatherService();
  final insightsService = WeatherInsightsService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotifications.instance.attach(openAlert);
    restoreCity();
  }

  void openAlert(PushAlert alert) {
    if (!mounted) return;
    if (screen == AppScreen.splash) {
      pendingAlert = alert;
      return;
    }
    selectCity(alert.city);
    setState(() => screen = AppScreen.alerts);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Startup/resume also restores local checks after leaving a push build.
      // initialize handles setup failures without blocking the weather UI.
      NotificationService().initialize();
    }
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
      PushNotifications.instance.retry();
    } catch (_) {
      /* Selection still works without persistent storage. */
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushNotifications.instance.onOpen = null;
    weatherService.dispose();
    insightsService.dispose();
    super.dispose();
  }

  void navigate(AppScreen s) {
    final alert = pendingAlert;
    if (screen == AppScreen.splash && alert != null) {
      pendingAlert = null;
      screen = s;
      if (PushAlert.parse({
            'city': alert.city,
            'eventId': alert.eventId,
            'issuedAt': alert.issuedAt.toIso8601String(),
            'route': 'alerts',
          }, DateTime.now()) !=
          null) {
        openAlert(alert);
        return;
      }
    }
    setState(() {
      screen = s;
      openPlannerOnLoad = false;
    });
  }

  void openActivityPlanner() => setState(() {
    screen = AppScreen.ai;
    openPlannerOnLoad = true;
  });

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
          onOpenPlanner: openActivityPlanner,
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
        body = AlertsScreen(
          navigate: navigate,
          city: selectedCity,
          service: weatherService,
          insightsService: insightsService,
        );
        break;
      case AppScreen.ai:
        body = AIScreen(
          navigate: navigate,
          city: selectedCity,
          service: weatherService,
          insightsService: insightsService,
          openPlannerOnLoad: openPlannerOnLoad,
        );
        break;
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.skyGradient),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: ClipRRect(child: body),
          ),
        ),
      ),
    );
  }
}
