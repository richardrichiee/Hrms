class LeaveDetailsModel {
  final int lvApplicationId;
  final int branchId;
  final int leaveId;
  final int empId;
  final dynamic leaveType;
  final String fromDate;
  final String toDate;
  final double noOfLeaves;
  final String approvalStatus;
  final String reason;

  LeaveDetailsModel({
    required this.lvApplicationId,
    required this.branchId,
    required this.leaveId,
    required this.empId,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.noOfLeaves,
    required this.approvalStatus,
    required this.reason,
  });

  factory LeaveDetailsModel.fromJson(Map<String, dynamic> json) {
    return LeaveDetailsModel(
      lvApplicationId: json['LvApplicationID'] ?? 0,
      branchId: json['BranchID'] ?? 1,
      leaveId: json['LeaveID'] ?? 1,
      empId: json['EmpID'] ?? 0,
      leaveType: json['LeaveType'] ?? 1,
      fromDate: json['FromDate'] ?? '',
      toDate: json['ToDate'] ?? '',
      noOfLeaves: (json['NoOfLeaves'] is num)
          ? (json['NoOfLeaves'] as num).toDouble()
          : 1.0,
      approvalStatus: json['ApprovalStatus'] ?? 'A',
      reason: json['Reason'] ?? '',
    );
  }

  String get approvalStatusText {
    switch (approvalStatus.toUpperCase()) {
      case 'A':
      case 'APPROVED':
      case 'APPROVE':
        return 'Approved';
      case 'P':
      case 'PENDING':
      case 'N':
        return 'Pending';
      case 'R':
      case 'REJECTED':
      case 'REJECT':
        return 'Rejected';
      case 'F':
      case 'FORWARD':
      case 'FORWARDED':
        return 'Forwarded';
      default:
        return 'Pending';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'LvApplicationID': lvApplicationId,
      'BranchID': branchId,
      'LeaveID': leaveId,
      'EmpID': empId,
      'LeaveType': leaveType,
      'FromDate': fromDate,
      'ToDate': toDate,
      'NoOfLeaves': noOfLeaves,
      'ApprovalStatus': approvalStatus,
      'Reason': reason,
    };
  }
}
