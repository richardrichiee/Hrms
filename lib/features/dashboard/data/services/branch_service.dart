import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/branch_model.dart';

class BranchService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  Future<List<BranchModel>> fetchBranches() async {
    try {
      final accessPoint =
          await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      final url = AppUrls.getBranchListUrl(
        accessPoint: accessPoint,
        userId: userId,
      );

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          final serverBranches = list
              .map((item) => BranchModel.fromJson(item as Map<String, dynamic>))
              .toList();
          if (serverBranches.isNotEmpty) {
            await LocalStorageService.saveBranches(serverBranches);
            return serverBranches;
          }
        }
      }
    } catch (_) {}

    // Fallback to locally cached branches first before default
    try {
      final cached = await LocalStorageService.getBranches();
      if (cached.isNotEmpty) {
        return cached;
      }
    } catch (_) {}

    return [BranchModel(value: 1, name: 'Head Office')];
  }

  Future<bool> saveBranchLocation({
    required int branchId,
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    try {
      final accessPoint =
          await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      final url = AppUrls.getSaveBranchLocationUrl(
        accessPoint: accessPoint,
        userId: userId,
        branchId: branchId,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );

      final response = await _dio.post(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      final success = response.statusCode == 200;
      if (success) {
        // Update local cached branches immediately
        try {
          final cached = await LocalStorageService.getBranches();
          final updatedList = cached.map((b) {
            if (b.value == branchId) {
              return BranchModel(
                value: b.value,
                name: b.name,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
              );
            }
            return b;
          }).toList();
          await LocalStorageService.saveBranches(updatedList);
        } catch (_) {}
      }
      return success;
    } catch (e) {
      return false;
    }
  }
}
