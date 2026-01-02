import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wake_up_new/features/provider/alarm_provider.dart';
import 'package:wake_up_new/features/screens/alarm_home.dart';
import 'package:wake_up_new/features/screens/alarm_ring_screen.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:wake_up_new/core/services/alarm_service.dart';
import 'package:wake_up_new/core/services/alarm_trigger_service.dart';
import 'package:wake_up_new/core/services/alarm_ring_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Top-level callback for alarms - MUST be top level
@pragma('vm:entry-point')
void alarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  await AlarmService.triggerAlarm(id);
}

// Top-level callback for auto-snooze
@pragma('vm:entry-point')
void autoSnoozeCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('😴 Auto-snooze triggered for alarm: $id');
  await AlarmService.triggerAutoSnooze(id);
}

// Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global notification plugin instance
final FlutterLocalNotificationsPlugin notificationsPlugin =
FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 ========== APP STARTING ==========');

  // Initialize alarm manager
  await AndroidAlarmManager.initialize();
  debugPrint('✅ AndroidAlarmManager initialized');

  // Request Android permissions
  await _requestAndroidPermissions();

  // Initialize notifications
  await _initializeNotifications();

  // Setup isolate communication
  AlarmTriggerService.setupIsolatePort(_onAlarmReceived);

  // Create and initialize AlarmProvider
  final alarmProvider = AlarmProvider();
  await alarmProvider.initialize(); // ✅ Load alarms from storage
  debugPrint('✅ AlarmProvider initialized with ${alarmProvider.alarm.length} alarms');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: alarmProvider), // ✅ Use .value
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
  final currentContext = navigatorKey.currentContext;
  if (currentContext != null) {
    final currentRoute = ModalRoute.of(currentContext);
    if (currentRoute?.settings.name != '/alarm-ring') {
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
  debugPrint('🔔 Notification tapped: ${response.payload}');

  // Parse alarm ID from payload
  int? alarmId;
  if (response.payload != null && response.payload!.startsWith('alarm:')) {
    alarmId = int.tryParse(response.payload!.split(':')[1]);
  }

  if (alarmId == null) {
    debugPrint('❌ Could not parse alarm ID');
    return;
  }

  // Handle dismiss action
  if (response.actionId == 'dismiss') {
    debugPrint('🔕 Dismiss requested via notification');

    AlarmRingService.stopRinging();
    notificationsPlugin.cancel(alarmId);

    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
    }

    return;
  }

  // Handle snooze action
  if (response.actionId == 'snooze') {
    debugPrint('😴 Snooze requested via notification');

    AlarmRingService.stopRinging();
    notificationsPlugin.cancel(alarmId);

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

  // Default: Navigate to alarm ring screen
  debugPrint('📱 Navigating to alarm screen for ID: $alarmId');

  // Start ringing if not already
  if (!AlarmRingService.isRinging) {
    AlarmRingService.startRinging();
  }

  // Navigate to the alarm screen
  navigatorKey.currentState?.pushNamed(
    '/alarm-ring',
    arguments: alarmId,
  );
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
        '/alarm-ring': (context) {
          final alarmId = ModalRoute.of(context)!.settings.arguments as int;

          // Get the alarm from provider
          final alarmProvider = Provider.of<AlarmProvider>(context, listen: false);
          final alarm = alarmProvider.getAlarmById(alarmId);

          if (alarm == null) {
            debugPrint('⚠️ Alarm $alarmId not found in provider!');
            // Return a fallback screen or pop back
            return Scaffold(
              appBar: AppBar(title: const Text('Alarm Not Found')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text('This alarm no longer exists'),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        AlarmRingService.stopRinging();
                        notificationsPlugin.cancel(alarmId);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Go Back'),
                    ),
                  ],
                ),
              ),
            );
          }

          return AlarmRingScreen(alarmId: alarmId);
        },
      },
    );
  }
}