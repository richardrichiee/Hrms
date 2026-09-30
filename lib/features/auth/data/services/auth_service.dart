import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/user_model.dart';

class LoginResult {
  final bool isSuccess;
  final UserModel? user;
  final String? errorMessage;

  LoginResult({
    required this.isSuccess,
    this.user,
    this.errorMessage,
  });
}

class AuthService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  Future<LoginResult> login({
    required String loginId,
    required String password,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) {
        return LoginResult(
          isSuccess: false,
          errorMessage: 'Access Point missing. Please reconnect to your company.',
        );
      }

      final url = AppUrls.getLoginUrl(
        accessPoint: accessPoint,
        loginId: loginId,
        password: password,
      );

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
          final firstItem = (data['value'] as List).first as Map<String, dynamic>;
          
          final errorMessage = firstItem['ErrorMessage'] as String?;
          if (errorMessage != null && errorMessage.isNotEmpty) {
            return LoginResult(
              isSuccess: false,
              errorMessage: errorMessage,
            );
          }

          final user = UserModel.fromJson(firstItem);

          // Save user session in local storage
          await LocalStorageService.saveUser(user);

          return LoginResult(
            isSuccess: true,
            user: user,
          );
        }

        if (data['error'] != null && data['error']['message'] != null) {
          return LoginResult(
            isSuccess: false,
            errorMessage: data['error']['message'].toString(),
          );
        }
      }

      return LoginResult(
        isSuccess: false,
        errorMessage: 'Invalid username or password.',
      );
    } catch (e) {
      return LoginResult(
        isSuccess: false,
        errorMessage: 'Unable to connect to server. Please check your network and try again.',
      );
    }
  }
}
