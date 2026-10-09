import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';

class AccessPointResult {
  final bool isSuccess;
  final String? accessPoint;
  final String? companyImageUrl;
  final String? errorMessage;

  AccessPointResult({
    required this.isSuccess,
    this.accessPoint,
    this.companyImageUrl,
    this.errorMessage,
  });
}

class AccessPointService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<String?> ensureCompanyImageUrl() async {
    try {
      final cachedUrl = await LocalStorageService.getCompanyImageUrl();
      if (cachedUrl != null && cachedUrl.isNotEmpty) {
        return cachedUrl;
      }
      final accessId = await LocalStorageService.getAccessId() ?? 'abcd';
      final res = await fetchAccessPoint(accessId);
      return res.companyImageUrl;
    } catch (_) {
      return null;
    }
  }

  Future<AccessPointResult> fetchAccessPoint(String accessId) async {
    try {
      final url = AppUrls.getAccessPointUrl(accessId);
      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null &&
            data['value'] is List &&
            (data['value'] as List).isNotEmpty) {
          final firstItem = (data['value'] as List).first;
          final accessPoint = firstItem['AccessPoint'] as String?;
          final companyImageUrl = firstItem['CompanyImageUrl'] as String?;

          if (accessPoint != null && accessPoint.isNotEmpty) {
            // Save to secure local storage
            await LocalStorageService.saveAccessPoint(accessPoint);
            await LocalStorageService.saveAccessId(accessId);
            if (companyImageUrl != null && companyImageUrl.isNotEmpty) {
              await LocalStorageService.saveCompanyImageUrl(companyImageUrl);
            }

            return AccessPointResult(
              isSuccess: true,
              accessPoint: accessPoint,
              companyImageUrl: companyImageUrl,
            );
          }
        }

        if (data['error'] != null && data['error']['message'] != null) {
          if (accessId.toLowerCase() == 'hrmdemo' || accessId == '123456789') {
            await LocalStorageService.saveAccessPoint('HRMDemo');
            await LocalStorageService.saveAccessId(accessId);
            return AccessPointResult(isSuccess: true, accessPoint: 'HRMDemo');
          }
          return AccessPointResult(
            isSuccess: false,
            errorMessage: data['error']['message'].toString(),
          );
        }
      }

      if (accessId.toLowerCase() == 'hrmdemo' || accessId == '123456789') {
        await LocalStorageService.saveAccessPoint('HRMDemo');
        await LocalStorageService.saveAccessId(accessId);
        return AccessPointResult(isSuccess: true, accessPoint: 'HRMDemo');
      }

      return AccessPointResult(
        isSuccess: false,
        errorMessage: 'Invalid Access ID or company not found.',
      );
    } catch (e) {
      if (accessId.toLowerCase() == 'hrmdemo' || accessId == '123456789') {
        await LocalStorageService.saveAccessPoint('HRMDemo');
        await LocalStorageService.saveAccessId(accessId);
        return AccessPointResult(isSuccess: true, accessPoint: 'HRMDemo');
      }
      return AccessPointResult(
        isSuccess: false,
        errorMessage: 'Unable to connect to server. Please check your internet connection.',
      );
    }
  }
}
