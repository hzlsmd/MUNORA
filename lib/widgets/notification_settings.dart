import 'package:material_ui/material_ui.dart';

import '../services/notification_service.dart';
import '../services/notification_preferences.dart';
import '../services/push_notifications.dart';

class NotificationSettings extends StatefulWidget {
  const NotificationSettings({super.key});
  @override
  State<NotificationSettings> createState() => _NotificationSettingsState();
}

class _NotificationSettingsState extends State<NotificationSettings> {
  final service = NotificationService();
  bool enabled = false;
  bool busy = true;
  NotificationPreferences preferences = const NotificationPreferences();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await service.enabled();
      preferences = await NotificationPreferences.load();
      if (mounted) setState(() => enabled = value);
    } catch (_) {
      // Keep the control available for retry if preference storage fails.
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _change(bool value) async {
    setState(() => busy = true);
    try {
      final result = await service.setEnabled(value);
      if (!mounted) return;
      setState(() => enabled = result);
      if (value && !result) {
        _message(
          'Allow notifications in Android settings to enable weather tips.',
        );
      }
    } catch (_) {
      if (mounted) {
        await _load();
        _message('Unable to update notifications. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _savePreferences(NotificationPreferences value) async {
    setState(() => busy = true);
    try {
      await value.save();
      if (mounted) setState(() => preferences = value);
    } catch (_) {
      _message('Unable to save notification preferences. Please retry.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!NotificationService.supported) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Weather notifications'),
            value: enabled,
            onChanged: busy ? null : _change,
          ),
          ValueListenableBuilder<String?>(
            valueListenable: PushNotifications.instance.status,
            builder: (context, value, _) =>
                value == null && !PushNotifications.configured
                ? const SizedBox.shrink()
                : Column(
                    children: [
                      Text(
                        value ?? 'Push setup is pending.',
                        style: const TextStyle(fontSize: 12),
                      ),
                      TextButton(
                        onPressed: busy ? null : () => service.initialize(),
                        child: Text(
                          PushNotifications.configured
                              ? 'Retry push connection'
                              : 'Retry notification setup',
                        ),
                      ),
                    ],
                  ),
          ),
          if (enabled) ...[
            Text(
              PushNotifications.configured
                  ? 'Push delivery requires the updated backend. Android may delay delivery. Quiet hours use Philippine time.'
                  : 'Approximate hourly checks. Android may delay delivery. Quiet hours use Philippine time.',
              style: const TextStyle(fontSize: 12),
            ),
            for (final category in notificationCategories)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(switch (category) {
                  'storm' => 'Thunderstorms',
                  'rain' => 'Rain',
                  'heat' => 'Heat',
                  'wind' => 'Strong wind',
                  'uv' => 'High UV',
                  _ => 'Clear-weather suggestions',
                }),
                value: preferences.categories.contains(category),
                onChanged: busy
                    ? null
                    : (value) {
                        final categories = {...preferences.categories};
                        if (value == true) {
                          categories.add(category);
                        } else {
                          categories.remove(category);
                        }
                        _savePreferences(
                          NotificationPreferences(
                            categories: categories,
                            quietStart: preferences.quietStart,
                            quietEnd: preferences.quietEnd,
                          ),
                        );
                      },
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Quiet hours (including weather alerts)'),
              value: preferences.quietStart != null,
              onChanged: busy
                  ? null
                  : (value) => _savePreferences(
                      NotificationPreferences(
                        categories: preferences.categories,
                        quietStart: value ? 22 : null,
                        quietEnd: value ? 7 : null,
                      ),
                    ),
            ),
            if (preferences.quietStart != null)
              const Text(
                'Equal start and end hours means no quiet period.',
                style: TextStyle(fontSize: 11),
              ),
            if (preferences.quietStart != null)
              Row(
                children: [
                  for (final start in [true, false])
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        initialValue: start
                            ? preferences.quietStart
                            : preferences.quietEnd,
                        decoration: InputDecoration(
                          labelText: start ? 'From (PHT)' : 'Until (PHT)',
                        ),
                        items: List.generate(
                          24,
                          (hour) => DropdownMenuItem(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                        ),
                        onChanged: busy
                            ? null
                            : (hour) => _savePreferences(
                                NotificationPreferences(
                                  categories: preferences.categories,
                                  quietStart: start
                                      ? hour
                                      : preferences.quietStart,
                                  quietEnd: start ? preferences.quietEnd : hour,
                                ),
                              ),
                      ),
                    ),
                ],
              ),
          ],
          if (enabled)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: const Icon(Icons.notifications_active_outlined),
                label: const Text('Send test notification'),
                onPressed: busy
                    ? null
                    : () async {
                        try {
                          await service.sendTest();
                        } catch (_) {
                          _message(
                            'Unable to send notification. Check Android notification settings.',
                          );
                        }
                      },
              ),
            ),
        ],
      ),
    );
  }
}

/// Notification management remains reachable even when weather cannot load.
class NotificationSettingsButton extends StatelessWidget {
  const NotificationSettingsButton({super.key});
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Notification settings',
    icon: const Icon(Icons.notifications_none_rounded),
    onPressed: () => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notification settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (NotificationService.supported)
                const NotificationSettings()
              else
                const Text(
                  'Weather notifications are available in the Android app. You can still read Alerts and Tips here.',
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
