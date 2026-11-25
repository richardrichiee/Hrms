class UserModel {
  final String company;
  final int userId;
  final String userName;
  final int employeeId;
  final String empCode;
  final String serverDate;
  final int roleId;
  final int onlinePunchAnywhere;
  final int punchNeeded;
  final String? errorMessage;
  final String branchStartTime;
  final String branchEndTime;
  final int branchId;
  final String branchName;

  bool get canPunchAnywhere => onlinePunchAnywhere == 1;
  bool get isPunchNeeded => punchNeeded == 1;

  static int _parseFlag(dynamic value) {
    if (value == null) return 0;
    if (value is bool) return value ? 1 : 0;
    if (value is num) return value.toInt() == 1 ? 1 : 0;
    final str = value.toString().trim().toLowerCase();
    if (str == '1' || str == '1.0' || str == 'true' || str == 'y' || str == 'yes') {
      return 1;
    }
    return 0;
  }

  UserModel({
    required this.company,
    required this.userId,
    required this.userName,
    required this.employeeId,
    this.empCode = '',
    required this.serverDate,
    required this.roleId,
    this.onlinePunchAnywhere = 0,
    this.punchNeeded = 0,
    this.errorMessage,
    this.branchStartTime = '08:00:00',
    this.branchEndTime = '18:00:00',
    this.branchId = 0,
    this.branchName = '',
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      company: json['Company']?.toString() ?? '',
      userId: int.tryParse(json['UserID']?.toString() ??
              json['UserId']?.toString() ??
              json['ID']?.toString() ??
              '0') ??
          0,
      userName: json['UserName']?.toString() ??
          json['Username']?.toString() ??
          json['EmployeeName']?.toString() ??
          '',
      employeeId: int.tryParse(json['EmployeeID']?.toString() ??
              json['EmpID']?.toString() ??
              json['EmployeeId']?.toString() ??
              json['EmpId']?.toString() ??
              '0') ??
          0,
      empCode: json['EmpCode']?.toString() ??
          json['EmployeeCode']?.toString() ??
          json['Empcode']?.toString() ??
          json['EmpNo']?.toString() ??
          json['EmployeeNo']?.toString() ??
          json['empCode']?.toString() ??
          json['emp_code']?.toString() ??
          '',
      serverDate: json['ServerDate']?.toString() ?? '',
      roleId: int.tryParse(json['RoleID']?.toString() ??
              json['RoleId']?.toString() ??
              '0') ??
          0,
      onlinePunchAnywhere: _parseFlag(
        json['OnlinePunchAnywhere'] ??
            json['onlinePunchAnywhere'] ??
            json['PunchAnywhere'],
      ),
      punchNeeded: _parseFlag(
        json['PunchNeeded'] ?? json['punchNeeded'] ?? json['Punch_Needed'],
      ),
      errorMessage: json['ErrorMessage'] as String?,
      branchStartTime: json['BranchStartTime']?.toString() ??
          json['branchStartTime']?.toString() ??
          json['StartTime']?.toString() ??
          '08:00:00',
      branchEndTime: json['BranchEndTime']?.toString() ??
          json['branchEndTime']?.toString() ??
          json['EndTime']?.toString() ??
          '18:00:00',
      branchId: int.tryParse(
            json['BranchID']?.toString() ??
                json['BranchId']?.toString() ??
                json['branchId']?.toString() ??
                json['branchID']?.toString() ??
                json['DefaultBranchID']?.toString() ??
                json['DefaultBranchId']?.toString() ??
                json['UserBranchID']?.toString() ??
                json['UserBranchId']?.toString() ??
                json['ID_Branch']?.toString() ??
                json['Branch_ID']?.toString() ??
                '0',
          ) ??
          0,
      branchName: json['BranchName']?.toString() ??
          json['Branch_Name']?.toString() ??
          json['branchName']?.toString() ??
          json['branch_name']?.toString() ??
          json['DefaultBranchName']?.toString() ??
          json['DefaultBranch']?.toString() ??
          json['Branch']?.toString() ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Company': company,
      'UserID': userId,
      'UserName': userName,
      'EmployeeID': employeeId,
      'EmpCode': empCode,
      'ServerDate': serverDate,
      'RoleID': roleId,
      'OnlinePunchAnywhere': onlinePunchAnywhere,
      'PunchNeeded': punchNeeded,
      'ErrorMessage': errorMessage,
      'BranchStartTime': branchStartTime,
      'BranchEndTime': branchEndTime,
      'BranchID': branchId,
      'BranchName': branchName,
    };
  }
}
