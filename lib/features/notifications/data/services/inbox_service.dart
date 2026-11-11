import 'dart:convert';
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

  /// POST /api/HRM/General/v1/Approve/{accessPoint}/{timeStamp} ('A')
  /// POST /api/HRM/General/v1/Recommendation/{accessPoint}/{timeStamp} ('F')
  /// POST /api/HRM/General/v1/Reject/{accessPoint}/{timeStamp} ('R')
  /// MenuLinkCode: Leave Application = "10", Claim = "3", Leave Cancellation = "12"
  Future<InboxApprovalResult> submitApprovalAction({
    required int recordId,
    required String action, // 'A' = Approve, 'F' = Recommendation, 'R' = Reject
    String? menuLinkCode,
    required String defaultMenuLinkCode,
    Map<String, dynamic>? itemData,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.trim().isEmpty) {
        print('❌ [InboxService.submitApprovalAction] Aborted: accessPoint is null/empty');
        return const InboxApprovalResult(
          success: false,
          errorMessage: 'Company access point not configured.',
        );
      }
      final trimmedAccessPoint = accessPoint.trim();

      final user = await LocalStorageService.getUser();
      if (user == null || user.userId <= 0) {
        print('❌ [InboxService.submitApprovalAction] Aborted: logged-in user/UserID missing');
        return const InboxApprovalResult(
          success: false,
          errorMessage: 'User session expired. Please log in again.',
        );
      }
      final userIdStr = user.userId.toString();

      if (recordId <= 0) {
        print('❌ [InboxService.submitApprovalAction] Aborted: invalid recordId=$recordId');
        return const InboxApprovalResult(
          success: false,
          errorMessage: 'Invalid request record ID.',
        );
      }

      final raw = itemData?['raw'] is Map
          ? Map<String, dynamic>.from(itemData!['raw'] as Map)
          : null;

      final savedBranchId = await LocalStorageService.getSelectedBranchId();
      String branchIdStr;
      if (savedBranchId != null && savedBranchId > 0) {
        branchIdStr = savedBranchId.toString();
      } else {
        final cachedBranches = await LocalStorageService.getBranches();
        if (cachedBranches.isNotEmpty && cachedBranches.first.value > 0) {
          branchIdStr = cachedBranches.first.value.toString();
        } else {
          final fallbackBranch = raw?['BranchID']?.toString() ??
              raw?['BranchId']?.toString() ??
              itemData?['branchId']?.toString() ??
              '1';
          branchIdStr = fallbackBranch.trim().isNotEmpty ? fallbackBranch.trim() : '1';
        }
      }

      String resolvedMenuLinkCode = '';
      if (menuLinkCode != null &&
          menuLinkCode.trim().isNotEmpty &&
          menuLinkCode.trim() != '0') {
        resolvedMenuLinkCode = menuLinkCode.trim();
      } else {
        final rawMenuLink = raw?['MenuLinkCode']?.toString().trim() ?? '';
        if (rawMenuLink.isNotEmpty && rawMenuLink != '0') {
          resolvedMenuLinkCode = rawMenuLink;
        } else {
          resolvedMenuLinkCode = defaultMenuLinkCode;
        }
      }

      final normalizedAction = action.trim().toUpperCase();
      String url;
      String actionEndpointName;
      if (normalizedAction == 'A') {
        url = AppUrls.getGeneralApproveUrl(accessPoint: trimmedAccessPoint);
        actionEndpointName = 'Approve';
      } else if (normalizedAction == 'F') {
        url = AppUrls.getGeneralRecommendationUrl(accessPoint: trimmedAccessPoint);
        actionEndpointName = 'Recommendation';
      } else if (normalizedAction == 'R') {
        url = AppUrls.getGeneralRejectUrl(accessPoint: trimmedAccessPoint);
        actionEndpointName = 'Reject';
      } else {
        print('❌ [InboxService.submitApprovalAction] Unsupported action="$action"');
        return const InboxApprovalResult(
          success: false,
          errorMessage: 'Unsupported approval action.',
        );
      }

      final payload = {
        "Head": {
          "UserID": userIdStr,
          "ID": recordId.toString(),
          "MenuLinkCode": resolvedMenuLinkCode,
          "BranchID": branchIdStr,
        }
      };

      print('------------------------------------------------------------');
      print('📡 [GENERAL $actionEndpointName -> POST /api/HRM/General/v1/$actionEndpointName]');
      print('🌐 URL            : $url');
      print('🏢 AccessPoint    : $trimmedAccessPoint | UserID: $userIdStr | BranchID: $branchIdStr');
      print('🔑 Record ID      : $recordId | MenuLinkCode: "$resolvedMenuLinkCode" | Action: "$normalizedAction"');
      print('📦 Payload JSON   : ${jsonEncode(payload)}');
      print('------------------------------------------------------------');

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

      print('📥 [GENERAL $actionEndpointName RESPONSE]');
      print('HTTP Status   : ${response.statusCode}');
      print('Response Body : ${response.data}');
      print('------------------------------------------------------------');

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          final value = data['value'];
          if (value is List && value.isNotEmpty) {
            final first = value.first;
            if (first is Map) {
              final errCol = first['ERRORMESSAGE']?.toString() ??
                  first['ErrorMessage']?.toString() ??
                  first['errormessage']?.toString() ??
                  '';
              if (errCol.trim().isNotEmpty) {
                print('⚠️ [InboxService.submitApprovalAction] Backend ERRORMESSAGE: ${errCol.trim()}');
                return InboxApprovalResult(
                  success: false,
                  errorMessage: errCol.trim(),
                  statusCode: response.statusCode,
                );
              }
            }
          }

          if (data['error'] != null) {
            final errStr = _extractError(data['error']);
            if (errStr.isNotEmpty) {
              print('⚠️ [InboxService.submitApprovalAction] Backend error object: $errStr');
              return InboxApprovalResult(
                success: false,
                errorMessage: errStr,
                statusCode: response.statusCode,
              );
            }
          }

          final hasFailureFlag = data['IsSuccess'] == false ||
              data['Status'] == false ||
              data['status'] == false ||
              data['StatusCode'] == 0 ||
              data['statusCode'] == 0 ||
              data['StatusCode'] == -1 ||
              data['statusCode'] == -1;
          if (hasFailureFlag) {
            final errStr = _extractError(data);
            return InboxApprovalResult(
              success: false,
              errorMessage: errStr.isNotEmpty
                  ? errStr
                  : 'Request failed server validation.',
              statusCode: response.statusCode,
            );
          }
        }

        return InboxApprovalResult(
          success: true,
          statusCode: response.statusCode,
        );
      }

      final errStr = _extractError(response.data);
      return InboxApprovalResult(
        success: false,
        errorMessage: errStr.isNotEmpty
            ? errStr
            : 'Server returned HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (dioErr) {
      print('❌❌❌ [InboxService.submitApprovalAction] DIO EXCEPTION:');
      print('   Message     : ${dioErr.message}');
      print('   Type        : ${dioErr.type}');
      print('   Endpoint    : ${dioErr.requestOptions.uri}');
      print('   Req Payload : ${dioErr.requestOptions.data}');
      print('   HTTP Status : ${dioErr.response?.statusCode}');
      print('   Resp Body   : ${dioErr.response?.data}');

      final errStr = _extractError(dioErr.response?.data ?? dioErr.message);
      return InboxApprovalResult(
        success: false,
        errorMessage: errStr.isNotEmpty ? errStr : null,
        statusCode: dioErr.response?.statusCode,
      );
    } catch (e, stack) {
      print('❌❌❌ [InboxService.submitApprovalAction] UNEXPECTED EXCEPTION: $e');
      print('Stack: $stack');
      return const InboxApprovalResult(success: false);
    }
  }

  static String _extractError(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      if (raw.isEmpty) return '';
      if (raw['error'] != null) {
        final nested = _extractError(raw['error']);
        if (nested.isNotEmpty) return nested;
      }
      for (final key in [
        'ERRORMESSAGE',
        'ErrorMessage',
        'errormessage',
        'Message',
        'message',
      ]) {
        final val = raw[key]?.toString().trim() ?? '';
        if (val.isNotEmpty) return val;
      }
      return '';
    }
    final s = raw.toString().trim();
    if (s.isEmpty || s == '{}' || s == '[]') return '';
    return s.length > 140 ? '${s.substring(0, 137)}...' : s;
  }
}

class InboxApprovalResult {
  final bool success;
  final String? errorMessage;
  final int? statusCode;

  const InboxApprovalResult({
    required this.success,
    this.errorMessage,
    this.statusCode,
  });
}
