class LeaveBalanceItem {
  final int leaveId;
  final String leaveName;
  final double opening;
  final double taken;
  final double closing;

  LeaveBalanceItem({
    required this.leaveId,
    required this.leaveName,
    this.opening = 0.0,
    this.taken = 0.0,
    required this.closing,
  });

  factory LeaveBalanceItem.fromJson(Map<String, dynamic> json) {
    final closingVal = (json['Closing'] as num?)?.toDouble() ??
        (json['Balance'] as num?)?.toDouble() ??
        (json['BalanceLeaves'] as num?)?.toDouble() ??
        0.0;
    final takenVal = (json['Taken'] as num?)?.toDouble() ??
        (json['LeaveTaken'] as num?)?.toDouble() ??
        (json['Availed'] as num?)?.toDouble() ??
        0.0;
    final openingVal = (json['Opening'] as num?)?.toDouble() ??
        (json['Total'] as num?)?.toDouble() ??
        (json['TotalLeaves'] as num?)?.toDouble() ??
        (closingVal + takenVal);

    return LeaveBalanceItem(
      leaveId: json['LeaveID'] ?? json['LeaveId'] ?? 0,
      leaveName: json['LeaveName']?.toString() ?? 'Leave',
      opening: openingVal,
      taken: takenVal,
      closing: closingVal,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'LeaveID': leaveId,
      'LeaveName': leaveName,
      'Opening': opening,
      'Taken': taken,
      'Closing': closing,
    };
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
      final Map<String, LeaveBalanceItem> grouped = {};
      for (final item in table1) {
        final Map<String, dynamic> raw;
        if (item is Map<String, dynamic>) {
          raw = item;
        } else if (item is Map) {
          raw = Map<String, dynamic>.from(item);
        } else {
          continue;
        }
        final parsed = LeaveBalanceItem.fromJson(raw);
        final key = parsed.leaveId > 0
            ? parsed.leaveId.toString()
            : parsed.leaveName.trim().toUpperCase();

        if (grouped.containsKey(key)) {
          final existing = grouped[key]!;
          final preferredName = existing.leaveName.length >= parsed.leaveName.length
              ? existing.leaveName
              : parsed.leaveName;
          grouped[key] = LeaveBalanceItem(
            leaveId: parsed.leaveId > 0 ? parsed.leaveId : existing.leaveId,
            leaveName: preferredName,
            opening: existing.opening + parsed.opening,
            taken: existing.taken + parsed.taken,
            closing: existing.closing + parsed.closing,
          );
        } else {
          grouped[key] = parsed;
        }
      }
      balances.addAll(grouped.values);
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
