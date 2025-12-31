import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:wake_up_bud/features/model/alarm_model.dart';
import 'package:wake_up_bud/core/services/alarm_trigger_service.dart';
import 'package:wake_up_bud/main.dart';

class AlarmService {
  /// Schedule an alarm
  static Future<void> scheduleAlarm(AlarmModel alarm) async {
    final now = DateTime.now();
    DateTime alarmTime = alarm.time;

    debugPrint('⏰ Current time: $now');
    debugPrint('⏰ Initial alarm time: $alarmTime');

    // If time already passed, schedule for next day
    if (alarmTime.isBefore(now)) {
      alarmTime = alarmTime.add(const Duration(days: 1));
      debugPrint('⏰ Time passed, rescheduling for: $alarmTime');
    }

    final difference = alarmTime.difference(now);
    debugPrint('⏰ Alarm will ring in: ${difference.inMinutes} minutes (${difference.inSeconds} seconds)');

    try {
      final success = await AndroidAlarmManager.oneShotAt(
        alarmTime,
        alarm.id,
        alarmCallback,
        wakeup: true,
        exact: true,
        rescheduleOnReboot: true,
      );

      debugPrint('✅ Alarm scheduling result: $success');
      debugPrint('✅ Alarm ID: ${alarm.id}');
      debugPrint('✅ Alarm time: $alarmTime');
    } catch (e) {
      debugPrint('❌ Error scheduling alarm: $e');
    }
  }

  /// Cancel an alarm
  static Future<void> cancelAlarm(int alarmId) async {
    try {
      await AndroidAlarmManager.cancel(alarmId);
      debugPrint('❌ Alarm cancelled with ID: $alarmId');
    } catch (e) {
      debugPrint('❌ Error cancelling alarm: $e');
    }
  }

  /// Runs in background isolate when alarm triggers
  @pragma('vm:entry-point')
  static Future<void> triggerAlarm(int id) async {
    debugPrint('🔔🔔🔔 ALARM CALLBACK TRIGGERED! ID: $id 🔔🔔🔔');

    try {
      WidgetsFlutterBinding.ensureInitialized();
      await AlarmTriggerService.fireAlarm(id);
    } catch (e, stackTrace) {
      debugPrint('❌ Error in triggerAlarm: $e');
      debugPrint('❌ StackTrace: $stackTrace');
    }
  }
}