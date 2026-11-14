import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  runApp(const MunoraApp());
  unawaited(NotificationService().initialize());
}
