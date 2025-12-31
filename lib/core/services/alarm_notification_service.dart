import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class AlarmNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static BuildContext? _appContext;

  static void setContext(BuildContext context) {
    _appContext = context;
  }

  static Future<void> initialize() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    debugPrint('✅ Notification service initialized');
  }

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');

    if (response.payload != null && _appContext != null) {
      final alarmId = int.tryParse(response.payload!);
      if (alarmId != null) {
        Navigator.of(_appContext!).pushNamed(
          '/alarm-ring',
          arguments: alarmId,
        );
      }
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }
}