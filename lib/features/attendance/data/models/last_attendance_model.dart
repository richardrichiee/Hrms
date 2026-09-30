class LastAttendanceModel {
  final String inOutTime;
  final int timeFlag; // 1 = Check In, 0 = Check Out
  final String? reason;

  LastAttendanceModel({
    required this.inOutTime,
    required this.timeFlag,
    this.reason,
  });

  bool get isCheckedIn => timeFlag == 1;
  bool get isCheckedOut => timeFlag == 0;

  /// Helper to get a cleanly formatted time (e.g., '10:26 AM')
  String get formattedTime {
    if (inOutTime.isEmpty || inOutTime == '--:--') return inOutTime;
    try {
      final parts = inOutTime.split(':');
      if (parts.length >= 2) {
        int hour = int.parse(parts[0]);
        final minute = parts[1].padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        if (hour == 0) {
          hour = 12;
        } else if (hour > 12) {
          hour -= 12;
        }
        return '$hour:$minute $period';
      }
    } catch (_) {}
    return inOutTime;
  }

  factory LastAttendanceModel.fromJson(Map<String, dynamic> json) {
    return LastAttendanceModel(
      inOutTime: json['InOutTime']?.toString().trim() ?? '',
      timeFlag: int.tryParse(json['TimeFlag']?.toString() ?? '0') ?? 0,
      reason: json['Reason']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'InOutTime': inOutTime,
      'TimeFlag': timeFlag,
      'Reason': reason,
    };
  }
}
