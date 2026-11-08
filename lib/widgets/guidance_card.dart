import 'package:material_ui/material_ui.dart';

import '../services/weather_recommendations.dart';
import '../theme.dart';
import 'atmosphere.dart';

class GuidanceCard extends StatelessWidget {
  final WeatherTip tip;
  final bool featured;
  const GuidanceCard({super.key, required this.tip, this.featured = false});
  @override
  Widget build(BuildContext context) {
    final asset = switch (tip.id) {
      'rain' => 'f27ef',
      'storm' => '02d7f',
      'heat' => '2df58',
      'wind' => '53672',
      _ => 'a7a0c',
    };
    return Material(
      color: Colors.transparent,
      child: GlassCard(
        color: featured ? const Color(0xC4FFFFFF) : const Color(0xA6FFFFFF),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (featured) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.indigo,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Featured recommendation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tip.id == 'heat'
                        ? const Color(0xFFFFDDB7)
                        : const Color(0xFFE9DEFF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(child: DesignIcon(asset)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tip.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tip.advice,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.textBody,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: ValueKey('${tip.id}:${tip.reason}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: const Text(
                  'Why this suggestion?',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.indigo,
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      tip.reason,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: AppColors.textBody,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
