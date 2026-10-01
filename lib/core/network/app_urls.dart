import 'package:intl/intl.dart';

class AppUrls {
  static const String baseUrl = 'http://122.165.40.92/CryptoneHRMAPI/';

  static String get timestamp {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Endpoint: /api/HRM/Mobile/v1/GetaccessPoint/{accessID}/{timeStamp}
  static String getAccessPointUrl(String accessID) {
    final time = timestamp;
    return '${baseUrl}api/HRM/Mobile/v1/GetaccessPoint/$accessID/$time';
  }

  /// Endpoint: /api/HRM/Mobile/v1/Login/{accessPoint}/{timeStamp}/{LoginID}/{password}
  static String getLoginUrl({
    required String accessPoint,
    required String loginId,
    required String password,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/Mobile/v1/Login/$accessPoint/$time/$loginId/$password';
  }

  /// Endpoint: /api/HRM/Mobile/v1/BranchList/{accessPoint}/{timeStamp}/{UserID}
  static String getBranchListUrl({
    required String accessPoint,
    required int userId,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/Mobile/v1/BranchList/$accessPoint/$time/$userId';
  }

  /// Endpoint: /api/HRM/Mobile/v1/FinancialYearList/{accessPoint}/{timeStamp}/{UserID}
  static String getFinancialYearListUrl({
    required String accessPoint,
    required int userId,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/Mobile/v1/FinancialYearList/$accessPoint/$time/$userId';
  }

  /// Endpoint: /api/HRM/General/v1/EmployeeDashBoard/{accessPoint}/{timeStamp}?iD={iD}&param={param}&Date={Date}
  /// Note: param='S' for Summary/Profile, param='D' for Daily Calendar Attendance logs
  static String getEmployeeDashboardUrl({
    required String accessPoint,
    required int employeeId,
    dynamic param = 'S',
    String? date,
  }) {
    final time = timestamp;
    final formattedDate =
        date ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${baseUrl}api/HRM/General/v1/EmployeeDashBoard/$accessPoint/$time?iD=$employeeId&param=$param&Date=$formattedDate';
  }

  /// Endpoint: /api/HRM/General/v1/DashBoard/{accessPoint}/{timeStamp}?MonthCode={MonthCode}&Type={Type}
  /// Note: Returns Table4 containing Leaves (For The Month)
  static String getGeneralDashboardUrl({
    required String accessPoint,
    String? monthCode,
    String type = 'A',
  }) {
    final time = timestamp;
    final formattedDate =
        monthCode ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
    return '${baseUrl}api/HRM/General/v1/DashBoard/$accessPoint/$time?MonthCode=$formattedDate&Type=$type';
  }

  /// Endpoint: /api/HRM/LeaveApplication/v1/List/{userId}/{timeStamp}/{accessPoint}
  static String getLeaveApplicationListUrl({
    required int userId,
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/LeaveApplication/v1/List/$userId/$time/$accessPoint';
  }

  /// Endpoint: /api/HRM/LeaveApplication/v1/Get/{id}/{timeStamp}/{accessPoint}
  static String getLeaveApplicationDetailsUrl({
    required int key,
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/LeaveApplication/v1/Get/$key/$time/$accessPoint';
  }

  /// Endpoint: POST /api/HRM/LeaveApplication/v1/Calculation/{timeStamp}/{accessPoint}
  static String getLeaveApplicationCalculationUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/LeaveApplication/v1/Calculation/$time/$accessPoint';
  }

  /// Endpoint: GET /api/HRM/General/v1/GetUserRights/{accessPoint}/{timeStamp}/{MenuCode}/{UserID}/{BranchID}
  static String getUserRightsUrl({
    required String accessPoint,
    required int menuCode,
    required int userId,
    required int branchId,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/General/v1/GetUserRights/$accessPoint/$time/$menuCode/$userId/$branchId';
  }

  /// Endpoint: POST /api/HRM/LeaveApplication/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  static String getSaveLeaveApplicationUrl({
    int id = 0,
    required int userId,
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/LeaveApplication/v1/Save/$id/$userId/$time/$accessPoint';
  }

  /// Endpoint: GET /api/HRM/General/v1/RetrieveDataTable_GeneralDetails/{accessPoint}/{timeStamp}?iD={iD}&param={param}
  static String getNotificationCountUrl({
    required String accessPoint,
    required int userId,
    dynamic param = 'Count',
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/General/v1/RetrieveDataTable_GeneralDetails/$accessPoint/$time?iD=$userId&param=$param';
  }

  /// Endpoint: POST /api/HRM/General/v1/Inbox/{accessPoint}/{timeStamp}
  static String getInboxUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/General/v1/Inbox/$accessPoint/$time';
  }

  /// Endpoint: POST /api/HRM/General/v1/InboxDetails/{accessPoint}/{timeStamp}
  static String getInboxDetailsUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/General/v1/InboxDetails/$accessPoint/$time';
  }

  /// Endpoint: POST /api/HRM/LeaveCancellation/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  static String getSaveLeaveCancellationUrl({
    int id = 0,
    required int userId,
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/LeaveCancellation/v1/Save/$id/$userId/$time/$accessPoint';
  }

  /// Endpoint: GET /api/HRM/ClaimForm/v1/List/{timeStamp}/{accessPoint}
  static String getClaimListUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/ClaimForm/v1/List/$time/$accessPoint';
  }

  /// Endpoint: GET /api/HRM/ClaimForm/v1/Get/{id}/{timeStamp}/{accessPoint}
  static String getClaimDetailsUrl({
    required int key,
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/ClaimForm/v1/Get/$key/$time/$accessPoint';
  }

  /// Endpoint: POST /api/HRM/ClaimForm/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  static String getSaveClaimUrl({
    int id = 0,
    required int userId,
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/ClaimForm/v1/Save/$id/$userId/$time/$accessPoint';
  }

  /// Endpoint: POST /api/HRM/ClaimForm/v1/GetRate/{timeStamp}/{accessPoint}
  static String getClaimRateUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/ClaimForm/v1/GetRate/$time/$accessPoint';
  }

  /// Endpoint: POST /api/HRM/ClaimForm/v1/Delete/{id}/{timeStamp}/{accessPoint}
  static String getDeleteClaimUrl({
    required int id,
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/ClaimForm/v1/Delete/$id/$time/$accessPoint';
  }

  /// Endpoint: GET /api/HRM/General/v1/RetrieveDataTable_GeneralDetails/{accessPoint}/{timeStamp}?iD=0&param=ClaimMaster
  static String getClaimMasterUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/General/v1/RetrieveDataTable_GeneralDetails/$accessPoint/$time?iD=0&param=ClaimMaster';
  }

  /// Endpoint: POST /api/HRM/LeaveApplication/v1/EmpSearch/{timeStamp}/{accessPoint}
  static String getLeaveEmpSearchUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/LeaveApplication/v1/EmpSearch/$time/$accessPoint';
  }

  /// Endpoint: POST /api/HRM/LeaveApplication/v1/Approve_Or_Forward/{timeStamp}/{accessPoint}
  static String getLeaveApproveOrForwardUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/LeaveApplication/v1/Approve_Or_Forward/$time/$accessPoint';
  }

  /// Endpoint: POST /api/HRM/ClaimForm/v1/EmpSearch/{timeStamp}/{accessPoint}
  static String getClaimEmpSearchUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/ClaimForm/v1/EmpSearch/$time/$accessPoint';
  }

  /// Endpoint: POST /api/HRM/ClaimForm/v1/Approve_Or_Forward/{timeStamp}/{accessPoint}
  static String getClaimApproveOrForwardUrl({
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/ClaimForm/v1/Approve_Or_Forward/$time/$accessPoint';
  }

  /// Endpoint: POST /api/HRM/Mobile/v1/SaveBranchLocation/{accessPoint}/{timeStamp}/{UserID}/{BranchID}/{Latitude}/{Longitude}/{Radius}
  static String getSaveBranchLocationUrl({
    required String accessPoint,
    required int userId,
    required int branchId,
    required double latitude,
    required double longitude,
    required double radius,
  }) {
    final time = timestamp;
    final radiusStr = radius.round().toString();
    return '${baseUrl}api/HRM/Mobile/v1/SaveBranchLocation/$accessPoint/$time/$userId/$branchId/$latitude/$longitude/$radiusStr';
  }

  /// Endpoint: GET /api/HRM/Mobile/v1/GetLastAttendance/{accessPoint}/{timeStamp}/{BranchID}/{EmployeeID}
  static String getLastAttendanceUrl({
    required String accessPoint,
    required int branchId,
    required int employeeId,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/Mobile/v1/GetLastAttendance/$accessPoint/$time/$branchId/$employeeId';
  }

  /// Endpoint: GET /api/HRM/Mobile/v1/GetHistoryAttendance/{accessPoint}/{timeStamp}/{BranchID}/{EmployeeID}
  static String getHistoryAttendanceUrl({
    required String accessPoint,
    required int branchId,
    required int employeeId,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/Mobile/v1/GetHistoryAttendance/$accessPoint/$time/$branchId/$employeeId';
  }

  /// Endpoint: POST /api/HRM/Attendance/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  static String getSaveAttendanceUrl({
    int id = 0,
    required int userId,
    required String accessPoint,
  }) {
    final time = timestamp;
    return '${baseUrl}api/HRM/Attendance/v1/Save/$id/$userId/$time/$accessPoint';
  }
}


