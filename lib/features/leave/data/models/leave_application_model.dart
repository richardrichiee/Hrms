class LeaveApplicationModel {
  final int key;
  final String employee;
  final String leaveName;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final double noOfLeaves;
  final String reason;
  final String status;

  LeaveApplicationModel({
    required this.key,
    required this.employee,
    required this.leaveName,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    this.noOfLeaves = 1.0,
    this.reason = '',
    this.status = '',
  });

  factory LeaveApplicationModel.fromJson(Map<String, dynamic> json) {
    return LeaveApplicationModel(
      key: json['Key'] ?? 0,
      employee: json['Employee'] ?? 'Employee',
      leaveName: json['LeaveName'] ?? json['LeaveName1'] ?? 'Leave',
      leaveType: json['LeaveType'] ?? 'Full Day',
      fromDate: json['FromDate'] ?? '',
      toDate: json['ToDate'] ?? '',
      noOfLeaves: (json['NoOfLeaves'] as num?)?.toDouble() ?? 1.0,
      reason: json['Reason'] ?? '',
      status: json['Status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Key': key,
      'Employee': employee,
      'LeaveName': leaveName,
      'LeaveType': leaveType,
      'FromDate': fromDate,
      'ToDate': toDate,
      'NoOfLeaves': noOfLeaves,
      'Reason': reason,
      'Status': status,
    };
  }
}
