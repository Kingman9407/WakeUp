import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:wake_up_new/features/model/alarm_model.dart';
import 'package:wake_up_new/core/services/alarm_trigger_service.dart';
import 'package:wake_up_new/main.dart';

class AlarmService {
  // ID offsets to avoid conflicts
  static const int _autoSnoozeIdOffset = 1000000;

  /// Schedule an alarm WITH auto-snooze fallback
  static Future<void> scheduleAlarm(AlarmModel alarm) async {
    final now = DateTime.now();
    DateTime alarmTime = alarm.time;

    debugPrint('⏰ ========== SCHEDULING ALARM ==========');
    debugPrint('⏰ Current time: $now');
    debugPrint('⏰ Initial alarm time: $alarmTime');

    // If time already passed, schedule for next day
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
      debugPrint('⏰ Time passed, rescheduling for: $alarmTime');
    }

    final difference = alarmTime.difference(now);
    debugPrint('⏰ Alarm will ring in: ${difference.inMinutes} minutes');

    try {
      // STEP 1: Schedule the main alarm
      final success1 = await AndroidAlarmManager.oneShotAt(
        alarmTime,
        alarm.id,
        alarmCallback, // Your top-level callback from main.dart
        wakeup: true,
        exact: true,
        rescheduleOnReboot: true,
      );

      debugPrint('✅ Main alarm scheduled: $success1 (ID: ${alarm.id})');

      // STEP 2: Schedule auto-snooze fallback (90 seconds after alarm)
      final autoSnoozeTime = alarmTime.add(const Duration(seconds: 90));
      final autoSnoozeId = alarm.id + _autoSnoozeIdOffset;

      final success2 = await AndroidAlarmManager.oneShotAt(
        autoSnoozeTime,
        autoSnoozeId,
        autoSnoozeCallback, // Your top-level callback from main.dart
        wakeup: true,
        exact: true,
        rescheduleOnReboot: true,
      );

      debugPrint('✅ Auto-snooze fallback scheduled: $success2 (ID: $autoSnoozeId)');
      debugPrint('✅ Will trigger at: $autoSnoozeTime (if alarm not dismissed)');

    } catch (e) {
      debugPrint('❌ Error scheduling alarm: $e');
    }
  }

  /// Cancel an alarm AND its auto-snooze fallback
  static Future<void> cancelAlarm(int alarmId) async {
    try {
      // Cancel main alarm
      await AndroidAlarmManager.cancel(alarmId);
      debugPrint('❌ Main alarm cancelled: $alarmId');

      // Cancel auto-snooze fallback
      final autoSnoozeId = alarmId + _autoSnoozeIdOffset;
      await AndroidAlarmManager.cancel(autoSnoozeId);
      debugPrint('❌ Auto-snooze cancelled: $autoSnoozeId');

    } catch (e) {
      debugPrint('❌ Error cancelling alarm: $e');
    }
  }

  /// Runs in background isolate when alarm triggers
  @pragma('vm:entry-point')
  static Future<void> triggerAlarm(int id) async {
    debugPrint('🔔 ========== ALARM TRIGGERED ==========');
    debugPrint('🔔 Alarm ID: $id');

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AlarmTriggerService.fireAlarm(id);
    } catch (e, stackTrace) {
      debugPrint('❌ Error in triggerAlarm: $e');
      debugPrint('❌ StackTrace: $stackTrace');
    }
  }

  /// Runs when auto-snooze fallback triggers (user didn't dismiss)
  @pragma('vm:entry-point')
  static Future<void> triggerAutoSnooze(int originalAlarmId) async {
    debugPrint('😴 ========== AUTO-SNOOZE TRIGGERED ==========');
    debugPrint('😴 Original Alarm ID: $originalAlarmId');
    debugPrint('😴 User did not dismiss alarm within 90 seconds');

    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Calculate the actual alarm ID (remove offset)
      final cleanAlarmId = originalAlarmId - _autoSnoozeIdOffset;

      // Schedule new alarm for 1 minute later
      final snoozeTime = DateTime.now().add(const Duration(minutes: 1));

      debugPrint('😴 Scheduling new alarm for: $snoozeTime');

      await AndroidAlarmManager.oneShotAt(
        snoozeTime,
        cleanAlarmId, // Reuse same ID
        alarmCallback,
        wakeup: true,
        exact: true,
      );

      // Show notification about auto-snooze
      await AlarmTriggerService.showAutoSnoozeNotification(cleanAlarmId);

      debugPrint('✅ Auto-snooze alarm scheduled');

    } catch (e, stackTrace) {
      debugPrint('❌ Error in triggerAutoSnooze: $e');
      debugPrint('❌ StackTrace: $stackTrace');
    }
  }
}
