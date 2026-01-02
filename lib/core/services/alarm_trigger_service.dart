
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlarmTriggerService {
  static const String _isolatePortName = 'alarm_isolate_port';

  @pragma('vm:entry-point')
  static Future<void> fireAlarm(int alarmId) async {
    debugPrint('🔥 ========== ALARM FIRING ==========');
    debugPrint('🔥 Alarm ID: $alarmId');

    WidgetsFlutterBinding.ensureInitialized();

    // Try to notify main isolate (works only if app is running)
    final sendPort = IsolateNameServer.lookupPortByName(_isolatePortName);
    if (sendPort != null) {
      sendPort.send(alarmId);
      debugPrint('✅ Notified main isolate');
    } else {
      debugPrint('⚠️ Main isolate not available (app killed)');
      debugPrint('⚠️ Relying on notification to wake user');
    }

    // Show notification (this ALWAYS works)
    await _showAlarmNotification(alarmId);
  }

  static Future<void> _showAlarmNotification(int id) async {
    final notifications = FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(const InitializationSettings(android: androidInit));

    final androidChannel = AndroidNotificationChannel(
      'alarm_channel_max',
      'Alarm Notifications',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    await notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel_max',
      'Alarm Notifications',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ongoing: true, // Can't be dismissed by swiping
      autoCancel: false,
      styleInformation: const BigTextStyleInformation(
        'Open the app to verify you are awake. Auto-snooze in 90 seconds.',
        contentTitle: 'WAKE UP! ⏰',
      ),
    );

    await notifications.show(
      id,
      'WAKE UP! ⏰',
      'Tap to verify you are awake',
      NotificationDetails(android: androidDetails),
      payload: 'alarm:$id',
    );

    debugPrint('✅ Notification shown');
  }

  /// Show notification when auto-snooze activates
  static Future<void> showAutoSnoozeNotification(int alarmId) async {
    final notifications = FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(const InitializationSettings(android: androidInit));

    final androidDetails = AndroidNotificationDetails(
      'auto_snooze_channel',
      'Auto-Snooze Notifications',
      importance: Importance.high,
      priority: Priority.high,
      playSound: false,
      enableVibration: true,
      styleInformation: const BigTextStyleInformation(
        'You didn\'t verify. Alarm rescheduled for 1 minute.',
        contentTitle: '😴 Alarm Auto-Snoozed',
      ),
    );

    await notifications.show(
      alarmId + 999999, // Different ID to not conflict
      '😴 Alarm Auto-Snoozed',
      'Will ring again in 1 minute',
      NotificationDetails(android: androidDetails),
    );
  }

  static void setupIsolatePort(Function(int) onAlarmReceived) {
    final receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(_isolatePortName);
    IsolateNameServer.registerPortWithName(receivePort.sendPort, _isolatePortName);

    receivePort.listen((data) {
      if (data is int) {
        debugPrint('📨 Main isolate received: $data');
        onAlarmReceived(data);
      }
    });

    debugPrint('✅ Isolate port setup complete');
  }
}