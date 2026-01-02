// ==================== ALARM MODEL WITH JSON SUPPORT ====================

class AlarmModel {
  int id;
  DateTime time;
  bool isAlarmEnable;
  int repetion; // 0 = once, 1 = daily, 2 = weekdays, etc.
  bool isFaceEnable;

  AlarmModel({
    required this.id,
    required this.time,
    required this.isAlarmEnable,
    required this.repetion,
    required this.isFaceEnable,
  });

  // ================= JSON SERIALIZATION =================

  /// Convert AlarmModel to JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time.toIso8601String(), // Store as ISO string
      'isAlarmEnable': isAlarmEnable,
      'repetion': repetion,
      'isFaceEnable': isFaceEnable,
    };
  }

  /// Create AlarmModel from JSON Map
  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'] as int,
      time: DateTime.parse(json['time'] as String), // Parse ISO string
      isAlarmEnable: json['isAlarmEnable'] as bool,
      repetion: json['repetion'] as int,
      isFaceEnable: json['isFaceEnable'] as bool,
    );
  }

  // ================= COPY WITH =================

  /// Create a copy of this alarm with optional modifications
  AlarmModel copyWith({
    int? id,
    DateTime? time,
    bool? isAlarmEnable,
    int? repetion,
    bool? isFaceEnable,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      time: time ?? this.time,
      isAlarmEnable: isAlarmEnable ?? this.isAlarmEnable,
      repetion: repetion ?? this.repetion,
      isFaceEnable: isFaceEnable ?? this.isFaceEnable,
    );
  }

  @override
  String toString() {
    return 'AlarmModel(id: $id, time: $time, enabled: $isAlarmEnable, repetion: $repetion, face: $isFaceEnable)';
  }
}