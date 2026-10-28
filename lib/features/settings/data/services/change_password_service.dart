import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';

class ChangePasswordResult {
  final bool isSuccess;
  final String message;

  const ChangePasswordResult({
    required this.isSuccess,
    required this.message,
  });
}

class ChangePasswordService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  /// Cryptone HRM stores passwords using SHA-1 over UTF-16LE (Unicode),
  /// formatted as uppercase hexadecimal bytes separated by hyphens (e.g. BitConverter.ToString)
  static String hashPassword(String password) {
    final bytes = <int>[];
    for (final codeUnit in password.codeUnits) {
      bytes.add(codeUnit & 0xFF);
      bytes.add((codeUnit >> 8) & 0xFF);
    }
    final digest = sha1.convert(bytes);
    return digest.bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join('-');
  }

  /// POST /api/HRM/Mobile/v1/UpdatePassword/{UserID}/{timeStamp}/{accessPoint}
  Future<ChangePasswordResult> changePassword({
    required String newPassword,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) {
        return const ChangePasswordResult(
          isSuccess: false,
          message: 'Company access point not configured.',
        );
      }
      final user = await LocalStorageService.getUser();
      final targetId = (user != null && user.userId > 0)
          ? user.userId
          : ((user != null && user.employeeId > 0) ? user.employeeId : 0);

      if (targetId == 0) {
        return const ChangePasswordResult(
          isSuccess: false,
          message: 'User session not found. Please log in again.',
        );
      }

      final newUrl = AppUrls.getUpdatePasswordUrl(
        userId: targetId,
        accessPoint: accessPoint,
      );

      final hashedPassword = hashPassword(newPassword);

      final payload = {
        "Head": {
          "NewPasswd": hashedPassword,
        }
      };

      Response? response;
      try {
        response = await _dio.post(
          newUrl,
          data: payload,
          options: Options(
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        );
      } on DioException catch (dioErr) {
        // If the newly added mobile endpoint throws an internal server error (e.g. backend index bug),
        // fallback seamlessly to the stable ChangePassWord/v1/Save endpoint
        final statusCode = dioErr.response?.statusCode;
        if (statusCode == 500 || statusCode == 404 || statusCode == 400) {
          final fallbackUrl = AppUrls.getChangePasswordSaveUrl(
            id: targetId,
            userId: targetId,
            accessPoint: accessPoint,
          );
          response = await _dio.post(
            fallbackUrl,
            data: payload,
            options: Options(
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ),
          );
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          // Check for error in value list
          if (data['value'] is List && (data['value'] as List).isNotEmpty) {
            final first = (data['value'] as List).first;
            if (first is Map) {
              final errMsg = first['ERRORMESSAGE']?.toString() ??
                  first['ErrorMessage']?.toString();
              if (errMsg != null && errMsg.trim().isNotEmpty) {
                return ChangePasswordResult(
                  isSuccess: false,
                  message: errMsg.trim(),
                );
              }
            }
          }
          // Check for general error
          if (data['error'] is Map && data['error']['message'] != null) {
            final msg = data['error']['message'].toString().trim();
            if (msg.isNotEmpty) {
              return ChangePasswordResult(
                isSuccess: false,
                message: msg,
              );
            }
          }
        }
        return const ChangePasswordResult(
          isSuccess: true,
          message: 'Password changed successfully!',
        );
      }

      return const ChangePasswordResult(
        isSuccess: false,
        message: 'Server returned an invalid response. Please try again.',
      );
    } on DioException catch (e) {
      final serverMsg = (e.response?.data is Map && e.response?.data['error'] is Map)
          ? e.response?.data['error']['message']?.toString() ??
              e.response?.data['error']['Message']?.toString()
          : null;
      return ChangePasswordResult(
        isSuccess: false,
        message: serverMsg ??
            'Unable to connect to server. Please check your connection and try again.',
      );
    } catch (e) {
      return const ChangePasswordResult(
        isSuccess: false,
        message: 'Network error occurred. Please check your connection and try again.',
      );
    }
  }
}
