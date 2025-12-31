class AlarmModel {
  final DateTime time;
  bool isAlarmEnable;
  final int repetion;
  final bool isFaceEnable;
  final int id;

  AlarmModel ({
    required this.time,
    required this.isAlarmEnable,
    required this.repetion,
    required this.isFaceEnable,
    required this.id,
});
}