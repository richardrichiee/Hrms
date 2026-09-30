class LeaveBalanceItem {
  final int leaveId;
  final String leaveName;
  final double closing;

  LeaveBalanceItem({
    required this.leaveId,
    required this.leaveName,
    required this.closing,
  });

  factory LeaveBalanceItem.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceItem(
      leaveId: json['LeaveID'] ?? 0,
      leaveName: json['LeaveName']?.toString() ?? 'Leave',
      closing: (json['Closing'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'LeaveID': leaveId, 'LeaveName': leaveName, 'Closing': closing};
  }
}

class EmployeeDetailsModel {
  final int empId;
  final String empCode;
  final String name;
  final String designation;
  final String contactAddress;
  final String phoneNumber;
  final String email;
  final String doj;
  final String employmentType;
  final double totalPendingClaimAmount;
  final double thisPendingMonthClaimAmount;
  final int attendanceForTheMonth;
  final num noOfLeavesForTheMonth;
  final List<LeaveBalanceItem> leaveBalances;

  EmployeeDetailsModel({
    required this.empId,
    required this.empCode,
    required this.name,
    required this.designation,
    required this.contactAddress,
    this.phoneNumber = '',
    this.email = '',
    this.doj = '',
    this.employmentType = '',
    this.totalPendingClaimAmount = 0.0,
    this.thisPendingMonthClaimAmount = 0.0,
    this.attendanceForTheMonth = 0,
    this.noOfLeavesForTheMonth = 0,
    this.leaveBalances = const [],
  });

  factory EmployeeDetailsModel.fromJson(
    Map<String, dynamic> json, {
    List<dynamic>? table1,
  }) {
    final balances = <LeaveBalanceItem>[];
    if (table1 != null) {
      for (final item in table1) {
        if (item is Map<String, dynamic>) {
          balances.add(LeaveBalanceItem.fromJson(item));
        } else if (item is Map) {
          balances.add(
            LeaveBalanceItem.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return EmployeeDetailsModel(
      empId: json['EmpID'] ?? 0,
      empCode: json['EmpCode']?.toString() ?? '',
      name: json['Name'] ?? 'Employee',
      designation: json['Designation'] ?? 'Staff',
      contactAddress: json['ContactAddress'] ?? '',
      phoneNumber: json['PhoneNumber']?.toString() ?? '',
      email: json['Email']?.toString() ?? '',
      doj: json['DOJ']?.toString() ?? '',
      employmentType: json['EmploymentType']?.toString() ?? '',
      totalPendingClaimAmount:
          (json['TotalPendingClaimAmount'] as num?)?.toDouble() ?? 0.0,
      thisPendingMonthClaimAmount:
          (json['ThisPendingMonthClaimAMount'] as num?)?.toDouble() ??
          (json['ThisPendingMonthClaimAmount'] as num?)?.toDouble() ??
          0.0,
      attendanceForTheMonth:
          int.tryParse(
            json['AttandanceForthemonth']?.toString() ??
                json['AttendanceForthemonth']?.toString() ??
                '0',
          ) ??
          0,
      noOfLeavesForTheMonth: (json['NoOfLeavesforTheMonth'] as num?) ?? 0,
      leaveBalances: balances,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'EmpID': empId,
      'EmpCode': empCode,
      'Name': name,
      'Designation': designation,
      'ContactAddress': contactAddress,
      'PhoneNumber': phoneNumber,
      'Email': email,
      'DOJ': doj,
      'EmploymentType': employmentType,
      'TotalPendingClaimAmount': totalPendingClaimAmount,
      'ThisPendingMonthClaimAMount': thisPendingMonthClaimAmount,
      'AttandanceForthemonth': attendanceForTheMonth,
      'NoOfLeavesforTheMonth': noOfLeavesForTheMonth,
      'LeaveBalances': leaveBalances.map((e) => e.toJson()).toList(),
    };
  }
}
