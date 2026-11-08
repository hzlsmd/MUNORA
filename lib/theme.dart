import 'package:material_ui/material_ui.dart';

/// Shared palette from the supplied MUNORA design.
class AppColors {
  AppColors._();
  static const skyBlueTop = Color(0xFF5B5FC7);
  static const skyBlueMid = Color(0xFF9A8EE8);
  static const skyBlueBottom = Color(0xFFE1E0FF);
  static const indigoTop = Color(0xFF4246AD);
  static const indigoMid = Color(0xFF6E68CE);
  static const indigoBottom = Color(0xFFB9B4D5);
  static const bg = Color(0xFFDFD7F9);
  static const textDark = Color(0xFF191C1E);
  static const textGray = Color(0xFF626171);
  static const textBody = Color(0xFF464652);
  static const divider = Color(0x33C7C5D4);
  static const red = Color(0xFFBA1A1A);
  static const blue = Color(0xFF5B5FC7);
  static const amber = Color(0xFF805622);
  static const indigo = Color(0xFF4246AD);
  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFBFE3FF), Color(0xFFDFD7F9), Color(0xFFFEDAC8)],
    stops: [0, .55, 1],
  );
  static const indigoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [indigoTop, indigoMid, skyBlueMid],
  );
}

BoxDecoration cardDecoration({
  Color color = const Color(0xA6FFFFFF),
  Border? border,
}) => BoxDecoration(
  color: color,
  borderRadius: BorderRadius.circular(24),
  border: border,
  boxShadow: const [
    BoxShadow(color: Color(0x126E64A0), blurRadius: 20, offset: Offset(0, 8)),
  ],
);
