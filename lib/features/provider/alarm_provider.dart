import 'package:flutter/material.dart';
import 'package:wake_up_bud/features/model/alarm_model.dart';
import 'package:wake_up_bud/core/logger/app_logger.dart';
import 'package:wake_up_bud/core/services/alarm_service.dart';

class AlarmProvider with ChangeNotifier {
  final List<AlarmModel> _alarm = [];
  List<AlarmModel> get alarm => _alarm;

  void addAlarm(AlarmModel alarm) {
    _alarm.add(alarm);

    // Schedule the sounds if it's enabled
    if (alarm.isAlarmEnable) {
      AlarmService.scheduleAlarm(alarm);
    }

    AppLoggerHelper.logInfo(
      'Alarm Added → id: ${alarm.id}, enabled: ${alarm.isAlarmEnable}',
    );

    notifyListeners();
  }

  void removeAlarm(AlarmModel alarm) {
    // Cancel the scheduled sounds
    AlarmService.cancelAlarm(alarm.id);

    _alarm.remove(alarm);

    AppLoggerHelper.logInfo(
      'Alarm Removed → id: ${alarm.id}',
    );

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

      notifyListeners();
    } else {
      AppLoggerHelper.logInfo(
        'Toggle Failed → Alarm id $id not found',
      );
    }
  }
}