import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wake_up_bud/features/model/alarm_model.dart';
import 'package:wake_up_bud/features/provider/alarm_provider.dart';

class AlarmCard extends StatelessWidget {
  final AlarmModel alarm;

  const AlarmCard({
    super.key,
    required this.alarm,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        leading: IconButton(
          icon: const Icon(Icons.delete, color: Colors.red),
          onPressed: () {
            context.read<AlarmProvider>().removeAlarm(alarm);
          },
        ),
        title: Text(
          TimeOfDay.fromDateTime(alarm.time).format(context),
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          'ID: ${alarm.id}',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: Consumer<AlarmProvider>(
          builder: (_, provider, __) {
            final updatedAlarm =
            provider.alarm.firstWhere((a) => a.id == alarm.id);

            return Switch(
              value: updatedAlarm.isAlarmEnable,
              onChanged: (value) {
                provider.toggleAlarm(alarm.id, value);
              },
            );
          },
        ),
      ),
    );
  }
}