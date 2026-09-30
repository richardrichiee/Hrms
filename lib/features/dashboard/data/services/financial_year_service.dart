import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/financial_year_model.dart';

class FinancialYearService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  Future<List<FinancialYearModel>> fetchFinancialYears() async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      final url = AppUrls.getFinancialYearListUrl(
        accessPoint: accessPoint,
        userId: userId,
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
              .map((item) => FinancialYearModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [
        FinancialYearModel(value: 3, name: '2025-26'),
        FinancialYearModel(value: 1, name: '2024-25'),
        FinancialYearModel(value: 2, name: '2023-24'),
      ];
    } catch (e) {
      // Fallback list if network request fails
      return [
        FinancialYearModel(value: 3, name: '2025-26'),
        FinancialYearModel(value: 1, name: '2024-25'),
        FinancialYearModel(value: 2, name: '2023-24'),
      ];
    }
  }
}
