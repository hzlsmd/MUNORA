import 'package:material_ui/material_ui.dart';

import '../theme.dart';
import 'atmosphere.dart';

enum AppScreen { splash, home, forecast, alerts, ai }

class BottomNav extends StatelessWidget {
  final AppScreen active;
  final ValueChanged<AppScreen> onNavigate;
  const BottomNav({super.key, required this.active, required this.onNavigate});
  @override
  Widget build(BuildContext context) {
    const items = [
      (AppScreen.home, 'Home', '86e9b'),
      (AppScreen.forecast, 'Forecast', '53672'),
      (AppScreen.alerts, 'Alerts', 'fb3b1'),
      (AppScreen.ai, 'Tips', 'ced2d'),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: FrostedSurface(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: items.map((item) {
              final selected = active == item.$1;
              return Expanded(
                child: Semantics(
                  selected: selected,
                  button: true,
                  child: Material(
                    color: selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(32),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(32),
                      onTap: () => onNavigate(item.$1),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              height: 22,
                              child: Center(child: DesignIcon(item.$3)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.$2,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppColors.indigo
                                    : AppColors.textBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
