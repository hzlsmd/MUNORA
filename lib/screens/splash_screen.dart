import 'package:material_ui/material_ui.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onDone;
  const SplashScreen({super.key, required this.onDone});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFA9CBE4),
          Color(0xFFB9B4D5),
          Color(0xFFE5C7D1),
          Color(0xFFF6D8CA),
        ],
        stops: [0, .38, .72, 1],
      ),
    ),
    child: const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'MUNORA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              shadows: [
                Shadow(
                  color: Color(0x597161E8),
                  blurRadius: 18,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
