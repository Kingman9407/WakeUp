// ==================== PERSISTENT ALARM PROVIDER ====================

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'package:wake_up_new/features/model/alarm_model.dart';
import 'package:wake_up_new/core/logger/app_logger.dart';
import 'package:wake_up_new/core/services/alarm_service.dart';
import 'package:wake_up_new/core/services/alarm_ring_service.dart';
import 'package:wake_up_new/core/services/alarm_trigger_service.dart';
import 'package:wake_up_new/main.dart';

class AlarmProvider with ChangeNotifier {
  static const String _storageKey = 'alarms_data';

  final List<AlarmModel> _alarm = [];
  List<AlarmModel> get alarm => _alarm;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // ================= ID GENERATION =================

  /// Generate a safe alarm ID that won't exceed android_alarm_manager_plus limits
  /// Uses a 32-bit signed integer range (max value: 2147483647)
  int _generateSafeAlarmId() {
    final random = Random();
    int newId;

    // Keep generating until we find an unused ID
    do {
      // Generate a random positive integer within safe range (1 to 2147483647)
      newId = random.nextInt(2147483647) + 1;
    } while (_alarm.any((alarm) => alarm.id == newId));

    debugPrint('🆔 Generated safe alarm ID: $newId');
    return newId;
  }

  // ================= INITIALIZATION FROM STORAGE =================

  /// MUST be called before using the provider
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('📦 ========== LOADING ALARMS FROM STORAGE ==========');

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? alarmsJson = prefs.getString(_storageKey);

      if (alarmsJson != null) {
        final List<dynamic> alarmsList = json.decode(alarmsJson);

        _alarm.clear();
        for (var alarmData in alarmsList) {
          final alarm = AlarmModel.fromJson(alarmData);
          _alarm.add(alarm);
          debugPrint('✅ Loaded alarm: ID ${alarm.id}, Time: ${alarm.time}');
        }

        debugPrint('✅ Loaded ${_alarm.length} alarms from storage');
      } else {
        debugPrint('ℹ️ No alarms found in storage');
      }

      _isInitialized = true;
      notifyListeners();

    } catch (e) {
      debugPrint('❌ Error loading alarms: $e');
      _isInitialized = true;
    }
  }

  // ================= SAVE TO STORAGE =================

  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final List<Map<String, dynamic>> alarmsData =
      _alarm.map((alarm) => alarm.toJson()).toList();

      final String alarmsJson = json.encode(alarmsData);
      await prefs.setString(_storageKey, alarmsJson);

      debugPrint('💾 Saved ${_alarm.length} alarms to storage');
    } catch (e) {
      debugPrint('❌ Error saving alarms: $e');
      AppLoggerHelper.logError('Failed to save alarms: $e');
    }
  }

  // ================= ALARM OPERATIONS =================

  void addAlarm(AlarmModel alarm) {
    _alarm.add(alarm);

    // Schedule the alarm if it's enabled
    if (alarm.isAlarmEnable) {
      AlarmService.scheduleAlarm(alarm);
    }

    AppLoggerHelper.logInfo(
      'Alarm Added → id: ${alarm.id}, enabled: ${alarm.isAlarmEnable}',
    );

    _saveToStorage(); // Persist to disk
    notifyListeners();
  }

  void removeAlarm(AlarmModel alarm) {
    // Cancel the scheduled alarm
    AlarmService.cancelAlarm(alarm.id);

    _alarm.remove(alarm);

    AppLoggerHelper.logInfo(
      'Alarm Removed → id: ${alarm.id}',
    );

    _saveToStorage(); // Persist to disk
    notifyListeners();
  }

  void toggleAlarm(int id, bool value) {
    final index = _alarm.indexWhere((a) => a.id == id);

    if (index != -1) {
      _alarm[index].isAlarmEnable = value;

      // Schedule or cancel based on toggle
      if (value) {
        AlarmService.scheduleAlarm(_alarm[index]);
      } else {
        AlarmService.cancelAlarm(id);
      }

      AppLoggerHelper.logInfo(
        'Alarm Toggled → id: $id, enabled: $value',
      );

      _saveToStorage(); // Persist to disk
      notifyListeners();
    } else {
      AppLoggerHelper.logInfo(
        'Toggle Failed → Alarm id $id not found',
      );
    }
  }

  // ================= GET ALARM BY ID =================

  /// Get a specific alarm by ID - useful when app restarts
  AlarmModel? getAlarmById(int id) {
    try {
      return _alarm.firstWhere((a) => a.id == id);
    } catch (e) {
      debugPrint('⚠️ Alarm not found: $id');
      return null;
    }
  }

  // ================= AUTO-SNOOZE FUNCTIONALITY =================

  Future<int?> createAutoSnoozeAlarm({
    required int originalAlarmId,
    required Duration snoozeDelay,
  }) async {
    try {
      debugPrint('🔄 ========== AUTO-SNOOZE STARTED ==========');

      // STEP 1: Find and validate the original alarm
      final originalIndex = _alarm.indexWhere((a) => a.id == originalAlarmId);

      AlarmModel? originalAlarm;
      if (originalIndex != -1) {
        originalAlarm = _alarm[originalIndex];
        debugPrint('✅ Found original alarm at index $originalIndex');
      } else {
        debugPrint('⚠️ Original alarm not found in list, using defaults');
        originalAlarm = AlarmModel(
          id: originalAlarmId,
          time: DateTime.now(),
          isAlarmEnable: true,
          repetion: 0,
          isFaceEnable: true,
        );
      }

      // STEP 2: Cancel the system alarm
      debugPrint('❌ Cancelling original alarm: $originalAlarmId');
      await AlarmService.cancelAlarm(originalAlarmId);

      // STEP 3: Remove from list and IMMEDIATELY persist to storage
      debugPrint('🗑️ Removing original alarm from list');
      if (originalIndex != -1) {
        _alarm.removeAt(originalIndex);

        // 🔥 CRITICAL FIX: Save immediately after removal
        await _saveToStorage();
        debugPrint('✅ Original alarm removal persisted to storage');
      }

      // STEP 4: Cancel the notification
      debugPrint('🔕 Cancelling original notification');
      await notificationsPlugin.cancel(originalAlarmId);

      // Give the system a moment to clean up
      await Future.delayed(const Duration(milliseconds: 100));

      // STEP 5: Generate new SAFE ID and time
      final newAlarmId = _generateSafeAlarmId(); // 🔥 FIX: Use safe ID generator
      final snoozeTime = DateTime.now().add(snoozeDelay);

      debugPrint('📋 New alarm details:');
      debugPrint('   New ID: $newAlarmId (safe for android_alarm_manager)');
      debugPrint('   Snooze time: $snoozeTime');
      debugPrint('   Face detection: ${originalAlarm.isFaceEnable}');
      debugPrint('   Repetition: ${originalAlarm.repetion}');

      // STEP 6: Create new alarm with same settings
      final newAlarm = AlarmModel(
        id: newAlarmId,
        time: snoozeTime,
        isAlarmEnable: true,
        repetion: originalAlarm.repetion,
        isFaceEnable: originalAlarm.isFaceEnable,
      );

      // STEP 7: Add to provider (this will schedule it and save to storage)
      debugPrint('➕ Adding new auto-snooze alarm to provider');
      addAlarm(newAlarm);

      // STEP 8: Show immediate notification
      debugPrint('📱 Showing immediate auto-snooze notification');
      await _showAutoSnoozeNotification(newAlarmId, snoozeDelay);

      // STEP 9: Stop any currently playing alarm sound
      debugPrint('🔕 Stopping current alarm sounds');
      await AlarmRingService.stopRinging();

      debugPrint('✅ ========== AUTO-SNOOZE COMPLETE ==========');
      debugPrint('   Original alarm $originalAlarmId → Removed & Persisted');
      debugPrint('   New alarm $newAlarmId → Scheduled for $snoozeTime & Persisted');

      AppLoggerHelper.logInfo(
        'Auto-Snooze → Original: $originalAlarmId (removed), New: $newAlarmId (scheduled)',
      );

      notifyListeners();
      return newAlarmId;

    } catch (e, stackTrace) {
      debugPrint('❌ ========== AUTO-SNOOZE FAILED ==========');
      debugPrint('❌ Error: $e');
      debugPrint('❌ StackTrace: $stackTrace');
      AppLoggerHelper.logError('Auto-snooze failed: $e');
      return null;
    }
  }

  Future<void> _showAutoSnoozeNotification(int alarmId, Duration delay) async {
    try {
      final delayMinutes = delay.inMinutes;

      await notificationsPlugin.show(
        alarmId,
        '⏰ Alarm Auto-Snoozed',
        'You didn\'t verify. Alarm will ring again in $delayMinutes minute${delayMinutes != 1 ? 's' : ''}.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'auto_snooze_channel',
            'Auto-Snooze Notifications',
            channelDescription: 'Notifications for auto-snoozed alarms',
            importance: Importance.high,
            priority: Priority.high,
            playSound: false,
            enableVibration: false,
            styleInformation: BigTextStyleInformation(
              'Open the app when the alarm rings to verify you\'re awake.',
              contentTitle: '⏰ Alarm Auto-Snoozed',
            ),
          ),
        ),
      );

      debugPrint('✅ Auto-snooze notification shown');
    } catch (e) {
      debugPrint('❌ Error showing auto-snooze notification: $e');
    }
  }
}