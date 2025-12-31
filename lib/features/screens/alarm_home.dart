import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wake_up_bud/features/model/alarm_model.dart';
import 'package:wake_up_bud/features/provider/alarm_provider.dart';
import 'package:wake_up_bud/features/widgets/alarm_card.dart';

class AlarmHome extends StatelessWidget {
  const AlarmHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alarm'),
      ),
      body: Consumer<AlarmProvider>(
        builder: (context, alarmProvider, _) {
          final alarms = alarmProvider.alarm;

          if (alarms.isEmpty) {
            return const Center(
              child: Text('No alarms added'),
            );
          }

          return ListView.builder(
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];

              return AlarmCard(
                key: ValueKey(alarm.id),
                alarm: alarm,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddAlarmDialog(context);
        },
        child: const Icon(Icons.add_alarm),
      ),
    );
  }

  void _showAddAlarmDialog(BuildContext context) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (selectedTime == null) return;

    final now = DateTime.now();
    final alarmTime = DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime.hour,
      selectedTime.minute,
    );

    // Generate a valid 32-bit integer ID
    // Use the last 31 bits of milliseconds (avoid overflow)
    final id = DateTime.now().millisecondsSinceEpoch % 2147483647;

    final alarm = AlarmModel(
      id: id,
      time: alarmTime,
      isAlarmEnable: true,
      repetion: 0,
      isFaceEnable: false,
    );

    if (!context.mounted) return;
    context.read<AlarmProvider>().addAlarm(alarm);
  }
}