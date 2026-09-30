class AttendanceLogModel {
  final int slNo;
  final int epId;
  final String employee;
  final int branchId;
  final String branchName;
  final int day;
  final String attendanceDate;
  final String inTime;
  final String outTime;
  final String present;

  AttendanceLogModel({
    required this.slNo,
    required this.epId,
    required this.employee,
    required this.branchId,
    required this.branchName,
    required this.day,
    required this.attendanceDate,
    required this.inTime,
    required this.outTime,
    required this.present,
  });

  factory AttendanceLogModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['AttendanceDate']?.toString() ?? '';
    int dayVal = json['Day'] ?? 0;
    if (dayVal == 0 && rawDate.isNotEmpty) {
      final parsedDate = DateTime.tryParse(rawDate);
      if (parsedDate != null) {
        dayVal = parsedDate.day;
      }
    }

    return AttendanceLogModel(
      slNo: json['SlNo'] ?? 0,
      epId: json['EpID'] ?? 0,
      employee: json['Employee'] ?? '',
      branchId: json['BranchID'] ?? 0,
      branchName: json['BranchName'] ?? '',
      day: dayVal,
      attendanceDate: rawDate,
      inTime: json['InTime']?.toString() ?? 'Ab',
      outTime: json['OutTime']?.toString() ?? 'Ab',
      present: json['Present']?.toString() ?? 'Ab',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SlNo': slNo,
      'EpID': epId,
      'Employee': employee,
      'BranchID': branchId,
      'BranchName': branchName,
      'Day': day,
      'AttendanceDate': attendanceDate,
      'InTime': inTime,
      'OutTime': outTime,
      'Present': present,
    };
  }
}
