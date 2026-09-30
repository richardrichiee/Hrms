class ClaimMasterItem {
  final int value;
  final String name;

  ClaimMasterItem({
    required this.value,
    required this.name,
  });

  factory ClaimMasterItem.fromJson(Map<String, dynamic> json) {
    return ClaimMasterItem(
      value: int.tryParse(json['Value']?.toString() ?? '0') ?? 0,
      name: json['Name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Value': value,
      'Name': name,
    };
  }
}

class ClaimRateResult {
  final double rate;
  final int rateFlag;

  ClaimRateResult({
    required this.rate,
    required this.rateFlag,
  });

  factory ClaimRateResult.fromJson(Map<String, dynamic> json) {
    return ClaimRateResult(
      rate: double.tryParse(json['Rate']?.toString() ?? '0.0') ?? 0.0,
      rateFlag: int.tryParse(json['RateFlag']?.toString() ?? '0') ?? 0,
    );
  }
}

class ClaimTailItem {
  final String claimId;
  final String claimName;
  final double amount;
  final double rate;
  final String rateFlag;
  final String qty;
  final String reason;
  final String date;
  final String status;
  final String statusText;

  ClaimTailItem({
    required this.claimId,
    required this.claimName,
    required this.amount,
    required this.rate,
    this.rateFlag = '0',
    required this.qty,
    required this.reason,
    required this.date,
    this.status = '0',
    this.statusText = 'Not Processed',
  });

  factory ClaimTailItem.fromJson(Map<String, dynamic> json) {
    return ClaimTailItem(
      claimId: json['ClaimID']?.toString() ?? '0',
      claimName: json['ClaimName']?.toString() ?? '',
      amount: double.tryParse(json['Amount']?.toString() ?? '0.0') ?? 0.0,
      rate: double.tryParse(json['Rate']?.toString() ?? '0.0') ?? 0.0,
      rateFlag: json['RateFlag']?.toString() ?? '0',
      qty: json['Qty']?.toString() ?? '1',
      reason: json['Reason']?.toString() ?? '',
      date: json['Date']?.toString() ?? '',
      status: json['Status']?.toString() ?? '0',
      statusText: json['StatusText']?.toString() ?? 'Not Processed',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ClaimID': claimId,
      'ClaimName': claimName,
      'Amount': amount,
      'Rate': rate,
      'RateFlag': rateFlag,
      'Qty': qty,
      'Reason': reason,
      'Date': date,
      'Status': status,
      'StatusText': statusText,
    };
  }
}

class ClaimModel {
  final int id;
  final String branchId;
  final String finYearId;
  final String claimDate;
  final String claimNumber;
  final String empId;
  final String employeeName;
  final double amount;
  final String approvalStatus; // "N", "A", "R"
  final String remarks;
  final List<ClaimTailItem> tailItems;

  ClaimModel({
    required this.id,
    required this.branchId,
    required this.finYearId,
    required this.claimDate,
    required this.claimNumber,
    required this.empId,
    this.employeeName = '',
    required this.amount,
    required this.approvalStatus,
    required this.remarks,
    this.tailItems = const [],
  });

  String get approvalStatusText {
    final s = approvalStatus.trim();
    if (s.toLowerCase() == 'approved' || s.toUpperCase() == 'A') {
      return 'Approved';
    }
    if (s.toLowerCase() == 'rejected' || s.toUpperCase() == 'R') {
      return 'Rejected';
    }
    if (s.toLowerCase() == 'forward' || s.toUpperCase() == 'F') {
      return 'Forward';
    }
    return 'Pending';
  }

  factory ClaimModel.fromJson(Map<String, dynamic> json) {
    final head = json['Head'] != null && json['Head'] is Map<String, dynamic>
        ? json['Head'] as Map<String, dynamic>
        : json;

    final rawTail = json['Tail'];
    List<ClaimTailItem> tailList = [];
    if (rawTail != null && rawTail is List) {
      tailList = rawTail
          .map((item) => ClaimTailItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    return ClaimModel(
      id: int.tryParse(head['ID']?.toString() ??
              head['Key']?.toString() ??
              head['ClaimNumber']?.toString() ??
              '0') ??
          0,
      branchId: head['BranchID']?.toString() ?? '1',
      finYearId: head['FinYearID']?.toString() ?? '3',
      claimDate: head['ClaimDate']?.toString() ?? head['Date']?.toString() ?? head['FromDate']?.toString() ?? '',
      claimNumber: head['ClaimNumber']?.toString() ?? head['Key']?.toString() ?? '0',
      empId: head['EmpID']?.toString() ??
          head['EmployeeID']?.toString() ??
          head['EmpId']?.toString() ??
          head['addBy']?.toString() ??
          head['AddBy']?.toString() ??
          '0',
      employeeName: head['Employee']?.toString() ??
          head['EmployeeName']?.toString() ??
          head['UserName']?.toString() ??
          '',
      amount: double.tryParse(head['Amount']?.toString() ?? head['TotalAmount']?.toString() ?? '0.0') ?? 0.0,
      approvalStatus: head['ApprovalStatus']?.toString() ?? head['Status']?.toString() ?? 'N',
      remarks: head['Remarks']?.toString() ?? head['Reason']?.toString() ?? '',
      tailItems: tailList,
    );
  }
}
