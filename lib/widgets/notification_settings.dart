import 'package:material_ui/material_ui.dart';

import '../services/notification_service.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await service.enabled();
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
