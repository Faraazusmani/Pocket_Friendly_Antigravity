import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_10y.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../errors/failures.dart';
import '../result/result.dart';

abstract class NotificationService {
  /// Initializes the notification service.
  Future<Result<void, PlatformFailure>> initialize();

  /// Displays an immediate notification.
  Future<Result<void, PlatformFailure>> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Schedules a notification for a future time.
  Future<Result<void, PlatformFailure>> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  });

  /// Cancels a scheduled notification.
  Future<Result<void, PlatformFailure>> cancelNotification(int id);

  /// Cancels all active and scheduled notifications.
  Future<Result<void, PlatformFailure>> cancelAllNotifications();
}

class NotificationServiceImpl implements NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;

  NotificationServiceImpl({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
  }) : _notificationsPlugin =
           notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  @override
  Future<Result<void, PlatformFailure>> initialize() async {
    try {
      tz.initializeTimeZones();

      const initializationSettingsAndroid = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initializationSettingsDarwin = DarwinInitializationSettings();

      const initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      final success = await _notificationsPlugin.initialize(
        initializationSettings,
      );

      if (success == true) {
        return const Success(null);
      } else {
        return const FailureResult(
          PlatformFailure('Failed to initialize local notifications plugin'),
        );
      }
    } catch (e) {
      return FailureResult(
        PlatformFailure('Error initializing local notifications', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'pocket_friendly_main_channel',
        'Pocket Friendly Notifications',
        channelDescription:
            'Main notification channel for Pocket Friendly finance alerts',
        importance: Importance.max,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(PlatformFailure('Failed to show notification', e));
    }
  }

  @override
  Future<Result<void, PlatformFailure>> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'pocket_friendly_main_channel',
        'Pocket Friendly Notifications',
        channelDescription:
            'Main notification channel for Pocket Friendly finance alerts',
        importance: Importance.max,
        priority: Priority.high,
      );
      const iosDetails = DarwinNotificationDetails();
      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tzLocation = tz.local;
      final scheduledTzDateTime = tz.TZDateTime.from(scheduledDate, tzLocation);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTzDateTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to schedule notification', e),
      );
    }
  }

  @override
  Future<Result<void, PlatformFailure>> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      return const Success(null);
    } catch (e) {
      return FailureResult(PlatformFailure('Failed to cancel notification', e));
    }
  }

  @override
  Future<Result<void, PlatformFailure>> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      return const Success(null);
    } catch (e) {
      return FailureResult(
        PlatformFailure('Failed to cancel all notifications', e),
      );
    }
  }
}
