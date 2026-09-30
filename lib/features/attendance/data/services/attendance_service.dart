import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/attendance_log_model.dart';
import '../models/last_attendance_model.dart';

class AttendanceService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  Future<List<AttendanceLogModel>> fetchMonthlyAttendanceLogs({String? date}) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final employeeId = user?.employeeId ?? 1;

      final url = AppUrls.getEmployeeDashboardUrl(
        accessPoint: accessPoint,
        employeeId: employeeId,
        param: 'D',
        date: date,
      );

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value']['Table'] != null) {
          final tableList = data['value']['Table'] as List;
          return tableList
              .map((item) => AttendanceLogModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// GET /api/HRM/Mobile/v1/GetLastAttendance/{accessPoint}/{timeStamp}/{BranchID}/{EmployeeID}
  Future<LastAttendanceModel?> fetchLastAttendance({
    required int branchId,
    int? employeeId,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final empId = employeeId ?? user?.employeeId ?? 1;

      final url = AppUrls.getLastAttendanceUrl(
        accessPoint: accessPoint,
        branchId: branchId,
        employeeId: empId,
      );

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          if (list.isNotEmpty) {
            return LastAttendanceModel.fromJson(
              Map<String, dynamic>.from(list[0] as Map),
            );
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/HRM/Mobile/v1/GetHistoryAttendance/{accessPoint}/{timeStamp}/{BranchID}/{EmployeeID}
  Future<List<LastAttendanceModel>> fetchHistoryAttendance({
    required int branchId,
    int? employeeId,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final empId = employeeId ?? user?.employeeId ?? 1;

      final url = AppUrls.getHistoryAttendanceUrl(
        accessPoint: accessPoint,
        branchId: branchId,
        employeeId: empId,
      );

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          return list
              .map((item) => LastAttendanceModel.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
