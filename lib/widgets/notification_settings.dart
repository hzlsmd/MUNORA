import 'package:material_ui/material_ui.dart';

import '../services/notification_service.dart';

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
