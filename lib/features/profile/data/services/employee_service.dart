import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/employee_details_model.dart';

class EmployeeService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  Future<EmployeeDetailsModel?> fetchEmployeeDashboard({String? date}) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) return null;
      final user = await LocalStorageService.getUser();
      final employeeId = user?.employeeId ?? 1;

      final url = AppUrls.getEmployeeDashboardUrl(
        accessPoint: accessPoint,
        employeeId: employeeId,
        param: 'S',
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
          final table1List = data['value']['Table1'] as List? ?? [];
          if (tableList.isNotEmpty) {
            return EmployeeDetailsModel.fromJson(
              tableList.first as Map<String, dynamic>,
              table1: table1List,
            );
          }
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
