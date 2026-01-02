import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wake_up_new/features/model/alarm_model.dart';
import 'package:wake_up_new/features/provider/alarm_provider.dart';

class AlarmCard extends StatelessWidget {
  final AlarmModel alarm;

  const AlarmCard({
    super.key,
    required this.alarm,
  });

  static const Color kGold = Color(0xFFF5CE7F);
  static const Color kCardBg = Color(0xFF1A1A1A);
  static const Color kBorder = Color(0xFF2A2A2A);

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(alarm.time).format(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: alarm.isAlarmEnable
              ? kGold.withOpacity(0.35)
              : kBorder,
        ),
      ),
      child: Row(
        children: [
          /// 🗑 DELETE
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Colors.redAccent.withOpacity(0.8),
            onPressed: () {
              context.read<AlarmProvider>().removeAlarm(alarm);
            },
          ),

          const SizedBox(width: 6),

          /// ⏰ TIME
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: kGold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Alarm ID: ${alarm.id}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),

          /// 🔘 SWITCH
          Consumer<AlarmProvider>(
            builder: (_, provider, __) {
              final updatedAlarm =
              provider.alarm.firstWhere((a) => a.id == alarm.id);

              return Switch(
                value: updatedAlarm.isAlarmEnable,
                onChanged: (value) {
                  provider.toggleAlarm(alarm.id, value);
                },
                activeColor: kGold,
                inactiveThumbColor: Colors.grey.shade700,
                inactiveTrackColor: Colors.grey.shade900,
              );
            },
          ),
        ],
      ),
    );
  }
}
