import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wake_up_new/features/model/alarm_model.dart';
import 'package:wake_up_new/features/provider/alarm_provider.dart';
import 'package:wake_up_new/features/widgets/alarm_card.dart';

class AlarmHome extends StatelessWidget {
  const AlarmHome({super.key});

  static const Color kGold = Color(0xFFF5CE7F);
  static const Color kDarkBg = Color(0xFF0F0F0F);
  static const Color kCardBg = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkBg,

      appBar: AppBar(
        backgroundColor: kDarkBg,
        elevation: 0,
        title: const Text(
          'Alarms',
          style: TextStyle(
            color: kGold,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.1,
          ),
        ),
        centerTitle: true,
      ),

      body: Consumer<AlarmProvider>(
        builder: (context, alarmProvider, _) {
          final alarms = alarmProvider.alarm;

          if (alarms.isEmpty) {
            return _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: alarms.length,
            itemBuilder: (context, index) {
              final alarm = alarms[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Container(
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: kGold.withOpacity(0.15),
                    ),
                  ),
                  child: AlarmCard(
                    key: ValueKey(alarm.id),
                    alarm: alarm,
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGold,
        elevation: 8,
        onPressed: () => _showAddAlarmDialog(context),
        icon: const Icon(Icons.add_alarm, color: Colors.black),
        label: const Text(
          'Add Alarm',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  void _showAddAlarmDialog(BuildContext context) async {
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kGold,
              onPrimary: Colors.black,
              surface: kCardBg,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
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

/// ---------------- EMPTY STATE ----------------
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AlarmHome.kGold.withOpacity(0.4),
              ),
            ),
            child: const Icon(
              Icons.alarm_off,
              size: 48,
              color: AlarmHome.kGold,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'No Alarms Set',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap the gold button to add one',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}
