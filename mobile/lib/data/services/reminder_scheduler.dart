import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

/// Puts a "check this plant again" notification on the phone's own calendar
/// of notifications. Nothing is sent anywhere.
abstract interface class ReminderScheduler {
  /// Schedule one reminder. Returns `false` when the user has not allowed
  /// the app to show notifications.
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  });

  Future<void> cancel(int id);
}

class LocalNotificationScheduler implements ReminderScheduler {
  LocalNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'periksa_ulang';
  static const _channelName = 'Pengingat periksa ulang';
  static const _channelDescription =
      'Mengingatkan Anda untuk memeriksa lagi daun yang pernah difoto.';

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _ready;

  Future<void> _initialise() => _ready ??= _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      // Ask only when the user sets a first reminder, not at launch.
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );

  Future<bool> _askPermission() async {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final android = _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        return await android?.requestNotificationsPermission() ?? false;
      case TargetPlatform.iOS:
        final ios = _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        return await ios?.requestPermissions(alert: true, sound: true) ?? false;
      default:
        return false;
    }
  }

  @override
  Future<bool> schedule({
    required int id,
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await _initialise();
    if (!await _askPermission()) return false;

    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      // An absolute instant: correct whatever the phone's time zone is, and
      // it spares the app a time-zone database.
      scheduledDate: tz.TZDateTime.from(at, tz.UTC),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // A morning reminder does not need to-the-second delivery, and the
      // inexact mode needs no extra permission.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    await _initialise();
    await _plugin.cancel(id: id);
  }
}
