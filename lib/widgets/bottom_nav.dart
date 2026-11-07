import 'package:flutter/material.dart';
import '../theme.dart';

enum AppScreen { splash, home, forecast, alerts, ai }

class _NavItem {
  final AppScreen screen;
  final String label;
  final IconData icon;
  const _NavItem(this.screen, this.label, this.icon);
}

const List<_NavItem> _items = [
  _NavItem(AppScreen.home, 'Home', Icons.home_rounded),
  _NavItem(AppScreen.forecast, 'Forecast', Icons.calendar_month_rounded),
  _NavItem(AppScreen.alerts, 'Alerts', Icons.warning_amber_rounded),
  _NavItem(AppScreen.ai, 'AI', Icons.auto_awesome_rounded),
];

class BottomNav extends StatelessWidget {
  final AppScreen active;
  final ValueChanged<AppScreen> onNavigate;

  const BottomNav({super.key, required this.active, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: _items.map((item) {
          final isActive = item.screen == active;
          return Expanded(
            child: InkWell(
              onTap: () => onNavigate(item.screen),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: isActive
                          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 6)
                          : const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isActive ? AppColors.skyBlueTop : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item.icon,
                        size: 22,
                        color: isActive ? Colors.white : AppColors.textGray,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive ? AppColors.skyBlueTop : AppColors.textGray,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
