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

  /// POST /api/HRM/ChangePassWord/v1/Save/{id}/{UserID}/{timeStamp}/{accessPoint}
  Future<ChangePasswordResult> changePassword({
    required String newPassword,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final targetId = (user != null && user.userId > 0)
          ? user.userId
          : ((user != null && user.employeeId > 0) ? user.employeeId : 0);
      final actingUserId = (user != null && user.userId > 0)
          ? user.userId
          : targetId;

      if (targetId == 0) {
        return const ChangePasswordResult(
          isSuccess: false,
          message: 'User session not found. Please log in again.',
        );
      }

      final url = AppUrls.getChangePasswordSaveUrl(
        id: targetId,
        userId: actingUserId,
        accessPoint: accessPoint,
      );

      final hashedPassword = hashPassword(newPassword);

      final payload = {
        "Head": {
          "NewPasswd": hashedPassword,
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
    } catch (e) {
      return const ChangePasswordResult(
        isSuccess: false,
        message: 'Network error occurred. Please check your connection and try again.',
      );
    }
  }
}
