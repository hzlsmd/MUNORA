import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

enum WeatherKind {
  sunny,
  partlyCloudy,
  cloudy,
  rain,
  drizzle,
  thunderstorm,
  snow,
  moon,
  haze,
  wind,
  nightRain,
}

WeatherKind weatherKindFor(String condition) {
  final c = condition.toLowerCase();
  if (c.contains('thunder') || c.contains('storm')) {
    return WeatherKind.thunderstorm;
  }
  if (c.contains('snow')) return WeatherKind.snow;
  if (c.contains('haze') || c.contains('fog') || c.contains('mist')) {
    return WeatherKind.haze;
  }
  if (c.contains('wind') || c.contains('breezy')) return WeatherKind.wind;
  if (c.contains('night') && c.contains('rain')) return WeatherKind.nightRain;
  if (c.contains('moon') || c.contains('night') || c.contains('clear night')) {
    return WeatherKind.moon;
  }
  if (c.contains('drizzle') ||
      c.contains('light rain') ||
      c.contains('scattered rain')) {
    return WeatherKind.drizzle;
  }
  if (c.contains('rain') || c.contains('shower')) return WeatherKind.rain;
  if (c.contains('partly') ||
      c.contains('partial') ||
      c.contains('mostly sunny') ||
      c.contains('partly sunny')) {
    return WeatherKind.partlyCloudy;
  }
  if (c.contains('cloud') ||
      c.contains('overcast') ||
      c.contains('scattered cloud') ||
      c.contains('humid')) {
    return WeatherKind.cloudy;
  }
  return WeatherKind.sunny; // sun / clear / hot / warm, and the default
}

class WeatherIcon extends StatefulWidget {
  final String condition;
  final double size;

  const WeatherIcon({super.key, required this.condition, this.size = 32});

  @override
  State<WeatherIcon> createState() => _WeatherIconState();
}

class _WeatherIconState extends State<WeatherIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  void _start() {
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      motion.stop();
      motion.value = 1;
    } else {
      motion.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _start();
  }

  @override
  void didUpdateWidget(covariant WeatherIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.condition != widget.condition) _start();
  }

  @override
  void dispose() {
    motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.condition,
    image: true,
    child: SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _WeatherPainter(weatherKindFor(widget.condition), motion),
        ),
      ),
    ),
  );
}

class _WeatherPainter extends CustomPainter {
  final WeatherKind kind;
  final Animation<double> motion;
  _WeatherPainter(this.kind, this.motion) : super(repaint: motion);

  Paint _surface(Rect bounds, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ).createShader(bounds);

  void _sun(Canvas canvas, Offset center, double radius, double wave) {
    final rays = Paint()
      ..color = const Color(0xFFFFC83D)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + wave * .16;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * (radius + 6),
        center + direction * (radius + 11),
        rays,
      );
    }
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawShadow(
      Path()..addOval(bounds),
      const Color(0xFFAB6500),
      3,
      false,
    );
    canvas.drawCircle(
      center,
      radius,
      _surface(bounds, const [
        Color(0xFFFFF8AF),
        Color(0xFFFFCC36),
        Color(0xFFF29921),
      ]),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(-radius * .25, -radius * .36),
        width: radius,
        height: radius * .45,
      ),
      Paint()..color = Colors.white.withValues(alpha: .48),
    );
  }

  void _cloud(Canvas canvas, double wave, {bool dark = false}) {
    canvas.save();
    canvas.translate(wave * 2, -wave * 1.5);
    final cloud = Path()
      ..moveTo(24, 66)
      ..cubicTo(6, 66, 7, 43, 24, 42)
      ..cubicTo(26, 19, 58, 17, 65, 39)
      ..cubicTo(89, 30, 99, 65, 77, 66)
      ..close();
    canvas.drawShadow(cloud, const Color(0xFF466C8C), 4, false);
    canvas.drawPath(
      cloud,
      _surface(
        const Rect.fromLTWH(18, 27, 65, 40),
        dark
            ? const [Color(0xFFD4DFEC), Color(0xFF829BB6), Color(0xFF4F6C88)]
            : const [Color(0xFFFFFFFF), Color(0xFFE9F4FC), Color(0xFF9DBFD8)],
      ),
    );
    canvas.drawPath(
      Path()
        ..moveTo(29, 39)
        ..quadraticBezierTo(40, 27, 51, 35),
      Paint()
        ..color = Colors.white.withValues(alpha: .55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);
    final wave = math.sin(motion.value * math.pi * 2);
    final precipitation = {
      WeatherKind.rain,
      WeatherKind.drizzle,
      WeatherKind.nightRain,
      WeatherKind.thunderstorm,
      WeatherKind.snow,
    }.contains(kind);
    if (kind == WeatherKind.sunny || kind == WeatherKind.partlyCloudy) {
      _sun(
        canvas,
        kind == WeatherKind.sunny ? const Offset(50, 47) : const Offset(65, 32),
        kind == WeatherKind.sunny ? 22 : 16,
        wave,
      );
    }
    if (kind == WeatherKind.moon || kind == WeatherKind.nightRain) {
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(const Rect.fromLTWH(29, 17, 45, 47)),
        Path()..addOval(const Rect.fromLTWH(44, 9, 42, 43)),
      );
      canvas.drawShadow(moon, const Color(0xFF315987), 3, false);
      canvas.drawPath(
        moon,
        _surface(const Rect.fromLTWH(29, 17, 45, 47), const [
          Color(0xFFFFF4C6),
          Color(0xFFBDDFF9),
          Color(0xFF6087B3),
        ]),
      );
    }
    if (kind == WeatherKind.cloudy ||
        kind == WeatherKind.partlyCloudy ||
        precipitation ||
        kind == WeatherKind.haze) {
      _cloud(
        canvas,
        wave,
        dark: kind == WeatherKind.thunderstorm || kind == WeatherKind.nightRain,
      );
    }
    if (precipitation && kind != WeatherKind.thunderstorm) {
      for (var i = 0; i < (kind == WeatherKind.drizzle ? 2 : 3); i++) {
        final x = 30.0 + i * 18;
        final y = 76 + math.sin(motion.value * math.pi * 4 + i) * 3;
        if (kind == WeatherKind.snow) {
          final pen = Paint()
            ..color = const Color(0xFF60B3DA)
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round;
          for (var arm = 0; arm < 3; arm++) {
            final vector =
                Offset(
                  math.cos(arm * math.pi / 3),
                  math.sin(arm * math.pi / 3),
                ) *
                5;
            canvas.drawLine(Offset(x, y) - vector, Offset(x, y) + vector, pen);
          }
        } else {
          final drop = Path()
            ..moveTo(x + 3, y - 6)
            ..cubicTo(x + 11, y + 5, x - 6, y + 9, x, y)
            ..close();
          canvas.drawPath(
            drop,
            _surface(Rect.fromLTWH(x - 3, y - 6, 11, 15), const [
              Color(0xFF83E3FF),
              Color(0xFF238CD8),
              Color(0xFF1265AA),
            ]),
          );
        }
      }
    }
    if (kind == WeatherKind.thunderstorm) {
      canvas.save();
      canvas.translate(wave, 0);
      final bolt = Path()
        ..moveTo(49, 54)
        ..lineTo(38, 74)
        ..lineTo(49, 74)
        ..lineTo(44, 91)
        ..lineTo(64, 65)
        ..lineTo(53, 65)
        ..lineTo(60, 54)
        ..close();
      canvas.drawShadow(bolt, const Color(0xFFB47B22), 2, false);
      canvas.drawPath(
        bolt,
        _surface(const Rect.fromLTWH(38, 54, 26, 37), const [
          Color(0xFFFFF4A0),
          Color(0xFFFFCF3E),
          Color(0xFFEF9B28),
        ]),
      );
      canvas.restore();
    }
    if (kind == WeatherKind.wind || kind == WeatherKind.haze) {
      final pen = Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFBDEAF7), Color(0xFF5399B9), Color(0xFF34728F)],
        ).createShader(const Rect.fromLTWH(15, 30, 70, 50))
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final y = (kind == WeatherKind.haze ? 68.0 : 34.0) + i * 10;
        canvas.drawPath(
          Path()
            ..moveTo(19 + wave * 3, y)
            ..lineTo(64 + i * 4, y)
            ..quadraticBezierTo(83, y, 76, y - 7),
          pen,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WeatherPainter oldDelegate) =>
      oldDelegate.kind != kind || oldDelegate.motion != motion;
}
