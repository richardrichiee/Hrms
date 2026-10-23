class UserModel {
  final String company;
  final int userId;
  final String userName;
  final int employeeId;
  final String empCode;
  final String serverDate;
  final int roleId;
  final String? errorMessage;

  UserModel({
    required this.company,
    required this.userId,
    required this.userName,
    required this.employeeId,
    this.empCode = '',
    required this.serverDate,
    required this.roleId,
    this.errorMessage,
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
      errorMessage: json['ErrorMessage'] as String?,
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
      'ErrorMessage': errorMessage,
    };
  }
}
