import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wake_up_bud/features/provider/alarm_provider.dart';
import 'package:wake_up_bud/features/screens/alarm_home.dart';
import 'package:wake_up_bud/features/screens/alarm_ring_screen.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:wake_up_bud/core/services/alarm_service.dart';
import 'package:wake_up_bud/core/services/alarm_trigger_service.dart';
import 'package:wake_up_bud/core/services/alarm_ring_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level callback for alarms - MUST be top level
@pragma('vm:entry-point')
void alarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.triggerAlarm(id);
}

// ADDED: Top-level callback for auto-snooze
@pragma('vm:entry-point')
void autoSnoozeCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('😴 Auto-snooze triggered for alarm: $id');
  await AlarmService.triggerAlarm(id);
}

// Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global notification plugin instance
final FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize alarm manager
  await AndroidAlarmManager.initialize();

  // Request Android permissions
  await _requestAndroidPermissions();

  // Initialize notifications
  await _initializeNotifications();

  // Setup isolate communication
  AlarmTriggerService.setupIsolatePort(_onAlarmReceived);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// This is called when alarm fires in background
void _onAlarmReceived(int alarmId) {
  debugPrint('🎯 Main isolate received alarm: $alarmId');

  // Start ringing immediately in foreground
  AlarmRingService.startRinging();

  // Navigate to alarm screen if not already there
  final currentRoute = navigatorKey.currentState?.overlay?.context;
  if (currentRoute != null) {
    final route = ModalRoute.of(currentRoute);
    if (route?.settings.name != '/alarm-ring') {
      navigatorKey.currentState?.pushNamed(
        '/alarm-ring',
        arguments: alarmId,
      );
    }
  }
}

Future<void> _requestAndroidPermissions() async {
  // Notification permission (Android 13+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }

  // Exact alarm permission (Android 12+)
  if (await Permission.scheduleExactAlarm.isDenied) {
    await Permission.scheduleExactAlarm.request();
  }

  debugPrint('✅ Android permissions requested');
}

Future<void> _initializeNotifications() async {
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await notificationsPlugin.initialize(
    initSettings,
    onDidReceiveNotificationResponse: _handleNotificationResponse,
  );

  // Create high-priority notification channel for alarms
  const androidChannel = AndroidNotificationChannel(
    'alarm_channel_max',
    'Alarm Notifications',
    description: 'High priority alarm notifications with sound and vibration',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('alarm_sound'),
    enableVibration: true,
  );

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(androidChannel);

  debugPrint('✅ Android notification channel created');
}

void _handleNotificationResponse(NotificationResponse response) {
  debugPrint('🔔 Notification action: ${response.actionId}');

  // Parse alarm ID from payload
  int? alarmId;
  if (response.payload != null && response.payload!.startsWith('alarm:')) {
    alarmId = int.tryParse(response.payload!.split(':')[1]);
  }

  if (alarmId == null) {
    debugPrint('❌ Could not parse alarm ID');
    return;
  }

  // FIXED: Handle dismiss action - stop ringing and cancel notification
  if (response.actionId == 'dismiss') {
    debugPrint('🔕 Dismiss requested - stopping alarm');

    // Stop the alarm sound and vibration
    AlarmRingService.stopRinging();

    // Cancel the notification
    notificationsPlugin.cancel(alarmId);

    // Pop any alarm ring screens
    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

    return;
  }

  // Handle snooze action
  if (response.actionId == 'snooze') {
    debugPrint('😴 Snooze requested');

    // Stop current alarm
    AlarmRingService.stopRinging();
    notificationsPlugin.cancel(alarmId);

    // Schedule snooze for 5 minutes
    final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
    AndroidAlarmManager.oneShotAt(
      snoozeTime,
      alarmId,
      alarmCallback,
      wakeup: true,
      exact: true,
    );

    debugPrint('⏰ Snoozed for 5 minutes');
    return;
  }

  // Default tap behavior - navigate to face recognition screen
  if (response.actionId == null) {
    debugPrint('📱 Notification tapped - navigating to face verification');

    navigatorKey.currentState?.pushNamed(
      '/alarm-ring',
      arguments: alarmId,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Wake Up Alarm',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AlarmHome(),
      routes: {
        '/alarm-ring': (context) => AlarmRingScreen(
          alarmId: ModalRoute.of(context)!.settings.arguments as int,
        ),
      },
    );
  }
}