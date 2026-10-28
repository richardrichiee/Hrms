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
      key: int.tryParse(json['Key']?.toString() ??
              json['ID']?.toString() ??
              json['LvApplicationID']?.toString() ??
              '') ??
          0,
      employee: json['Employee']?.toString() ??
          json['EmployeeName']?.toString() ??
          json['EmpName']?.toString() ??
          json['Name']?.toString() ??
          json['UserName']?.toString() ??
          'Employee',
      leaveName: json['LeaveName']?.toString() ??
          json['LeaveName1']?.toString() ??
          json['LeaveTypeName']?.toString() ??
          json['Category']?.toString() ??
          'Leave',
      leaveType: json['LeaveType']?.toString() ??
          json['DurationType']?.toString() ??
          'Full Day',
      fromDate: json['FromDate']?.toString() ?? '',
      toDate: json['ToDate']?.toString() ?? '',
      noOfLeaves: (json['NoOfLeaves'] is num)
          ? (json['NoOfLeaves'] as num).toDouble()
          : (double.tryParse(json['NoOfLeaves']?.toString() ?? '') ??
              double.tryParse(json['Days']?.toString() ?? '') ??
              1.0),
      reason: json['Reason']?.toString() ?? json['Remarks']?.toString() ?? '',
      status: json['Status']?.toString() ??
          json['ApprovalStatus']?.toString() ??
          'Pending',
    );
  }

  String get formattedStatus {
    switch (status.trim().toUpperCase()) {
      case 'A':
      case 'APPROVED':
      case 'APPROVE':
        return 'Approved';
      case 'R':
      case 'REJECTED':
      case 'REJECT':
        return 'Rejected';
      case 'F':
      case 'FORWARD':
      case 'FORWARDED':
        return 'Forwarded';
      case 'N':
      case 'P':
      case 'PENDING':
        return 'Pending';
      default:
        return status.isNotEmpty ? status : 'Pending';
    }
  }

  bool get isApproved {
    final s = status.trim().toUpperCase();
    return s == 'A' || s == 'APPROVED' || s == 'APPROVE';
  }

  bool get isPending {
    final s = status.trim().toUpperCase();
    return s == 'N' ||
        s == 'P' ||
        s == 'PENDING' ||
        s == 'FORWARD' ||
        s == 'FORWARDED' ||
        s == 'F' ||
        s.isEmpty;
  }

  bool get isRejected {
    final s = status.trim().toUpperCase();
    return s == 'R' || s == 'REJECTED' || s == 'REJECT';
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
