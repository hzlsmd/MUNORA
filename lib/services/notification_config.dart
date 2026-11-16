import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Stable native identifiers shared by local and push delivery modes.
const weatherNotificationJob = 'munora.weather.tips.v1';
const weatherNotificationsEnabledKey = 'notifications.weather.enabled';
const weatherNotificationId = 2401;
const weatherNotificationChannelId = 'weather_tips';
const weatherNotificationChannelName = 'Weather recommendations';
const weatherNotificationChannelDescription =
    'Forecast-based guidance for the selected NCR city';
const weatherNotificationIcon = 'ic_weather_notification';

const weatherNotificationInitialization = InitializationSettings(
  android: AndroidInitializationSettings(weatherNotificationIcon),
);
const weatherNotificationChannel = AndroidNotificationChannel(
  weatherNotificationChannelId,
  weatherNotificationChannelName,
  description: weatherNotificationChannelDescription,
  importance: Importance.defaultImportance,
);

NotificationDetails weatherNotificationDetails({
  bool onlyAlertOnce = false,
  String? body,
}) => NotificationDetails(
  android: AndroidNotificationDetails(
    weatherNotificationChannelId,
    weatherNotificationChannelName,
    channelDescription: weatherNotificationChannelDescription,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
    onlyAlertOnce: onlyAlertOnce,
    styleInformation: body == null ? null : BigTextStyleInformation(body),
  ),
);
