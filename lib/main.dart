import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MunoraApp());
  unawaited(NotificationService().initialize(handleLaunch: true));
}
