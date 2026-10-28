import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/user_rights_model.dart';

class UserRightsService {
  final Dio _dio = Dio();

  Future<UserRightsModel> fetchUserRights({
    required int menuCode,
    int? branchId,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) {
        return UserRightsModel.noAccess();
      }
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;
      final activeBranchId = branchId ?? 1;

      final url = AppUrls.getUserRightsUrl(
        accessPoint: accessPoint,
        menuCode: menuCode,
        userId: userId,
        branchId: activeBranchId,
      );

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List && (data['value'] as List).isNotEmpty) {
          final firstItem = (data['value'] as List).first as Map<String, dynamic>;
          return UserRightsModel.fromJson(firstItem);
        }
      }

      return UserRightsModel.noAccess();
    } catch (e) {
      return UserRightsModel.noAccess();
    }
  }
}
