import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';

class AlarmTriggerService {
  static const String _isolatePortName = 'alarm_isolate_port';
  static const String _channelId = 'alarm_channel_critical';
  static const String _channelName = 'Critical Alarm Notifications';

  /// This will be called from the background isolate
  @pragma('vm:entry-point')
  static Future<void> fireAlarm(int alarmId) async {
    debugPrint('🔥 Firing alarm in background: $alarmId');

    // Initialize Flutter binding for background isolate
    WidgetsFlutterBinding.ensureInitialized();

    // Send message to main isolate to start ringing
    final sendPort = IsolateNameServer.lookupPortByName(_isolatePortName);
    if (sendPort != null) {
      sendPort.send(alarmId);
      debugPrint('✅ Sent alarm ID to main isolate');
    } else {
      debugPrint('❌ Could not find main isolate port');
    }

    // Show notification with sound and action buttons
    await _showAlarmNotification(alarmId);
  }

  static Future<void> _showAlarmNotification(int id) async {
    final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await notifications.initialize(initSettings);

    // Create the notification channel with maximum priority
    final androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Critical alarm notifications with sound and vibration',
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList(const [0, 1000, 500, 1000, 500, 1000]),
    );

    // Register the channel
    await notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    // Create notification with custom sound and action buttons
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Critical alarm notifications with sound and vibration',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('alarm_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
      fullScreenIntent: false, // Set to false to prevent opening app
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      autoCancel: false,
      ticker: 'Alarm',
      styleInformation: const BigTextStyleInformation(
        'Your alarm is ringing! Use the buttons below to dismiss or snooze.',
        contentTitle: 'WAKE UP! ⏰',
      ),
      // Add action buttons that DON'T open the app
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'dismiss',
          'DISMISS',
          cancelNotification: true,
          showsUserInterface: false, // Changed to false to prevent opening app
        ),
        const AndroidNotificationAction(
          'snooze',
          'SNOOZE (5 min)',
          cancelNotification: false,
          showsUserInterface: false, // Changed to false to prevent opening app
        ),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await notifications.show(
      id,
      'WAKE UP! ⏰',
      'Your alarm is ringing! Use buttons to dismiss or snooze.',
      details,
      payload: 'alarm:$id',
    );

    debugPrint('✅ Notification shown with sound and vibration');
  }

  /// Setup the receive port in main isolate
  static void setupIsolatePort(Function(int) onAlarmReceived) {
    final receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(_isolatePortName);
    IsolateNameServer.registerPortWithName(
        receivePort.sendPort, _isolatePortName);

    receivePort.listen((dynamic data) {
      if (data is int) {
        debugPrint('📨 Received alarm ID in main isolate: $data');
        onAlarmReceived(data);
      }
    });

    debugPrint('✅ Isolate port setup complete');
  }
}