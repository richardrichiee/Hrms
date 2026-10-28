import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';

class InboxService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  /// POST /api/HRM/General/v1/Inbox/{accessPoint}/{timeStamp}
  Future<List<Map<String, dynamic>>> fetchInboxSummary() async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) return [];
      final user = await LocalStorageService.getUser();
      final userId = user?.userId.toString() ?? '2';

      final url = AppUrls.getInboxUrl(accessPoint: accessPoint);

      final payload = {
        "Head": {
          "UserID": userId,
        }
      };

      final response = await _dio.post(
        url,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          return list.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// POST /api/HRM/General/v1/InboxDetails/{accessPoint}/{timeStamp}
  Future<List<Map<String, dynamic>>> fetchInboxDetails({
    required String menuCode,
    required String menuLinkCode,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) return [];
      final user = await LocalStorageService.getUser();
      final userId = user?.userId.toString() ?? '2';

      final url = AppUrls.getInboxDetailsUrl(accessPoint: accessPoint);

      final payload = {
        "Head": {
          "UserID": userId,
          "MenuLinkCode": menuLinkCode,
          "MenuCode": menuCode,
        }
      };

      final response = await _dio.post(
        url,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          return list.map((item) => item as Map<String, dynamic>).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
