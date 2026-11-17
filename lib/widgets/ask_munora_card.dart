import 'package:material_ui/material_ui.dart';

import '../models/weather_snapshot.dart';
import 'weather_view.dart';
import 'atmosphere.dart';
import '../theme.dart';

class AskMunoraCard extends StatelessWidget {
  final WeatherSnapshot weather;
  final VoidCallback onOpen;
  const AskMunoraCard({super.key, required this.weather, required this.onOpen});
  @override
  Widget build(BuildContext context) {
    final fresh =
        WeatherLiveStatus.of(context) && weather.isUsable(DateTime.now());
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ask MUNORA',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              fresh
                  ? 'Ask about rain, outdoor timing and heat in ${weather.city}. Answers use fresh weather checked by the service.'
                  : 'Saved or outdated weather is shown. Refresh weather before asking for current advice.',
              style: const TextStyle(fontSize: 13, color: AppColors.textBody),
            ),
            if (!fresh)
              TextButton(
                onPressed: WeatherLiveStatus.refreshOf(context),
                child: const Text('Refresh weather'),
              ),
            FilledButton(
              onPressed: fresh ? onOpen : null,
              child: const Text('Ask MUNORA'),
            ),
          ],
        ),
      ),
    );
  }
}
