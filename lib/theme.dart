import 'package:flutter/material.dart';

/// Color + gradient constants ported 1:1 from the original design's hex values.
class AppColors {
  AppColors._();

  static const Color skyBlueTop = Color(0xFF1A8FE3);
  static const Color skyBlueMid = Color(0xFF3AABF0);
  static const Color skyBlueBottom = Color(0xFF6EC6F5);

  static const Color indigoTop = Color(0xFF6366F1);
  static const Color indigoMid = Color(0xFF818CF8);
  static const Color indigoBottom = Color(0xFFA5B4FC);

  static const Color bg = Color(0xFFEEF4FB);
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textGray = Color(0xFF9CA3AF);
  static const Color textBody = Color(0xFF4B5563);
  static const Color divider = Color(0xFFF0F4F8);

  static const Color red = Color(0xFFEF4444);
  static const Color blue = Color(0xFF3B82F6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color indigo = Color(0xFF6366F1);

  static const LinearGradient skyGradient = LinearGradient(
    begin: Alignment(0, -1),
    end: Alignment(0.17, 1), // approximates the 175deg CSS gradient
    colors: [skyBlueTop, skyBlueMid, skyBlueBottom],
  );

  static const LinearGradient indigoGradient = LinearGradient(
    begin: Alignment(0, -1),
    end: Alignment(0.17, 1),
    colors: [indigoTop, indigoMid, indigoBottom],
  );
}

/// Shared card decoration matching `.card` in the original CSS.
BoxDecoration cardDecoration({Color color = Colors.white, Border? border}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(20),
    border: border,
    boxShadow: const [
      BoxShadow(color: Color(0x140050B4), blurRadius: 16, offset: Offset(0, 2)),
    ],
  );
}
