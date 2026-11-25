import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/services/user_rights_service.dart';
import '../../../notifications/data/services/inbox_service.dart';
import '../models/leave_application_model.dart';
import '../models/leave_details_model.dart';

class LeaveService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  String _formatToIsoDate(String? rawDate) {
    if (rawDate == null || rawDate.isEmpty) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
    try {
      if (rawDate.contains('/')) {
        final parts = rawDate.split('/');
        if (parts.length == 3) {
          final day = parts[0].padLeft(2, '0');
          final month = parts[1].padLeft(2, '0');
          final year = parts[2];
          return '$year-$month-$day';
        }
      }
      final parsed = DateTime.tryParse(rawDate);
      if (parsed != null) {
        return DateFormat('yyyy-MM-dd').format(parsed);
      }
    } catch (_) {}
    return rawDate;
  }

  Future<String?> _getValidAccessPoint() async {
    final ap = await LocalStorageService.getAccessPoint();
    if (ap == null || ap.trim().isEmpty) return null;
    return ap.trim();
  }

  Future<List<LeaveApplicationModel>> fetchLeaveApplications() async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return [];
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      final url = AppUrls.getLeaveApplicationListUrl(
        userId: userId,
        accessPoint: accessPoint,
      );

      debugPrint(
        '==================== [LeaveService] FETCH LEAVE APPLICATIONS ====================',
      );
      debugPrint(
        '[LeaveService] AccessPoint: $accessPoint | UserID: $userId | EmpID: ${user?.employeeId} | UserName: ${user?.userName}',
      );
      debugPrint('[LeaveService] Endpoint: $url');

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      debugPrint(
        '📥 [LeaveService] Fetch Leaves Status: ${response.statusCode}',
      );
      debugPrint('📥 [LeaveService] Fetch Leaves Body: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          final apps = <LeaveApplicationModel>[];
          for (final item in list) {
            try {
              if (item is Map) {
                apps.add(
                  LeaveApplicationModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                );
              }
            } catch (err) {
              debugPrint(
                '⚠️ [LeaveService] Error parsing leave item $item: $err',
              );
            }
          }
          debugPrint(
            '✅ [LeaveService] Successfully parsed ${apps.length} leave applications',
          );
          return apps;
        }
      }

      return [];
    } catch (e, stack) {
      debugPrint('❌ [LeaveService] Exception in fetchLeaveApplications: $e');
      debugPrint('Stack: $stack');
      return [];
    }
  }

  Future<LeaveDetailsModel?> fetchLeaveApplicationDetails(int key) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) {
        print(
          '❌ [LeaveService.fetchLeaveApplicationDetails] Aborted: accessPoint is null/empty',
        );
        return null;
      }

      final url = AppUrls.getLeaveApplicationDetailsUrl(
        key: key,
        accessPoint: accessPoint,
      );

      print(
        '🌐 [LeaveService.fetchLeaveApplicationDetails] GET $url (key=$key)',
      );

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      print(
        '📥 [LeaveService.fetchLeaveApplicationDetails] Key=$key | HTTP ${response.statusCode} | Body: ${response.data}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null &&
            data['value'] is List &&
            (data['value'] as List).isNotEmpty) {
          final firstItem =
              (data['value'] as List).first as Map<String, dynamic>;
          return LeaveDetailsModel.fromJson(firstItem);
        } else if (data['Table'] != null &&
            data['Table'] is List &&
            (data['Table'] as List).isNotEmpty) {
          final firstItem =
              (data['Table'] as List).first as Map<String, dynamic>;
          return LeaveDetailsModel.fromJson(firstItem);
        }
      }

      return null;
    } on DioException catch (dioErr) {
      print(
        '❌ [LeaveService.fetchLeaveApplicationDetails] DIO EXCEPTION Key=$key:',
      );
      print('   Message  : ${dioErr.message}');
      print('   Type     : ${dioErr.type}');
      print('   Endpoint : ${dioErr.requestOptions.uri}');
      print('   Status   : ${dioErr.response?.statusCode}');
      print('   Body     : ${dioErr.response?.data}');
      return null;
    } catch (e, stack) {
      print('❌ [LeaveService.fetchLeaveApplicationDetails] ERROR Key=$key: $e');
      print('Stack: $stack');
      return null;
    }
  }

  /// POST /api/HRM/LeaveApplication/v1/Calculation/{timeStamp}/{accessPoint}
  Future<LeaveCalculationResult> calculateLeaveDaysWithValidation({
    required String leaveId,
    required String leaveType,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) {
        return const LeaveCalculationResult(
          days: 0.0,
          errorMessage: 'Company access point not configured.',
        );
      }
      final user = await LocalStorageService.getUser();
      final empId = (user?.employeeId != null && user!.employeeId > 0)
          ? user.employeeId.toString()
          : (user?.userId != null && user!.userId > 0
                ? user.userId.toString()
                : '26');

      final savedBranchId = await LocalStorageService.getSelectedBranchId();
      final branchId = (savedBranchId != null && savedBranchId > 0)
          ? savedBranchId.toString()
          : "1";

      final url = AppUrls.getLeaveApplicationCalculationUrl(
        accessPoint: accessPoint,
      );

      final payload = {
        "Head": {
          "BranchID": branchId,
          "LeaveID": leaveId,
          "EmpID": empId,
          "LeaveType": leaveType,
          "FromDate": _formatToIsoDate(fromDate),
          "ToDate": _formatToIsoDate(toDate),
          "NoOfLeaves": null,
          "ApprovalStatus": null,
          "Reason": null,
        },
      };

      debugPrint(
        '==================== [LeaveService] CALCULATION ====================',
      );
      debugPrint(
        '[LeaveService] AccessPoint: $accessPoint | EmpID: $empId | BranchID: $branchId',
      );
      debugPrint('[LeaveService] Endpoint: $url');
      debugPrint('[LeaveService] Payload: ${jsonEncode(payload)}');

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

      debugPrint(
        '📥 [LeaveService] Calculation Response Status: ${response.statusCode}',
      );
      debugPrint(
        '📥 [LeaveService] Calculation Response Body: ${response.data}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          if (data['value'] != null) {
            final val = data['value'];
            if (val is List && val.isNotEmpty) {
              final first = val.first;
              if (first is Map) {
                final errorMsg =
                    first['ERRORMESSAGE']?.toString() ??
                    first['ErrorMessage']?.toString() ??
                    first['errormessage']?.toString() ??
                    '';
                final noOfLeaves =
                    double.tryParse(first['NoOfLeaves']?.toString() ?? '') ??
                    0.0;
                if (errorMsg.trim().isNotEmpty) {
                  debugPrint(
                    '⚠️ [LeaveService] Calculation validation error: $errorMsg',
                  );
                  return LeaveCalculationResult(
                    days: noOfLeaves,
                    errorMessage: errorMsg.trim(),
                  );
                }
                return LeaveCalculationResult(days: noOfLeaves);
              }
            } else if (val is Map) {
              final errorMsg =
                  val['ERRORMESSAGE']?.toString() ??
                  val['ErrorMessage']?.toString() ??
                  val['errormessage']?.toString() ??
                  '';
              final noOfLeaves =
                  double.tryParse(val['NoOfLeaves']?.toString() ?? '') ?? 1.0;
              if (errorMsg.trim().isNotEmpty) {
                return LeaveCalculationResult(
                  days: noOfLeaves,
                  errorMessage: errorMsg.trim(),
                );
              }
              return LeaveCalculationResult(days: noOfLeaves);
            } else if (val is num) {
              return LeaveCalculationResult(days: val.toDouble());
            }
          }

          if (data['error'] != null) {
            final errStr = _extractCleanErrorMessage(data['error']);
            if (errStr.isNotEmpty) {
              return LeaveCalculationResult(days: 0.0, errorMessage: errStr);
            }
          }
        }
      }

      final start = DateTime.tryParse(fromDate) ?? DateTime.now();
      final end = DateTime.tryParse(toDate) ?? DateTime.now();
      final diff = end.difference(start).inDays + 1;
      return LeaveCalculationResult(
        days: leaveType == '1' ? diff.toDouble() : 0.5,
      );
    } catch (e) {
      debugPrint('⚠️ [LeaveService] Calculation error: $e');
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map) {
          if (data['value'] != null &&
              data['value'] is List &&
              (data['value'] as List).isNotEmpty) {
            final first = (data['value'] as List).first;
            if (first is Map) {
              final em =
                  first['ERRORMESSAGE']?.toString() ??
                  first['ErrorMessage']?.toString();
              if (em != null && em.trim().isNotEmpty) {
                return LeaveCalculationResult(
                  days: 0.0,
                  errorMessage: em.trim(),
                );
              }
            }
          }
          final cleanErr = _extractCleanErrorMessage(data);
          if (cleanErr.isNotEmpty) {
            return LeaveCalculationResult(days: 0.0, errorMessage: cleanErr);
          }
        }
      }
      final start = DateTime.tryParse(fromDate) ?? DateTime.now();
      final end = DateTime.tryParse(toDate) ?? DateTime.now();
      final diff = end.difference(start).inDays + 1;
      return LeaveCalculationResult(
        days: leaveType == '1' ? diff.toDouble() : 0.5,
      );
    }
  }

  /// Backward-compatible wrapper
  Future<double> calculateLeaveDays({
    required String leaveId,
    required String leaveType,
    required String fromDate,
    required String toDate,
  }) async {
    final res = await calculateLeaveDaysWithValidation(
      leaveId: leaveId,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
    );
    return res.days;
  }

  /// POST /api/HRM/LeaveApplication/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  Future<LeaveSaveResult> saveLeaveApplicationWithResult({
    required String leaveId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String noOfLeaves,
    required String reason,
    String? approvalStatus,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) {
        return const LeaveSaveResult(
          success: false,
          errorMessage: 'Company access point not configured.',
        );
      }
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;
      final empId = (user?.employeeId != null && user!.employeeId > 0)
          ? user.employeeId.toString()
          : (user?.userId != null && user!.userId > 0
                ? user.userId.toString()
                : '26');

      // Dedicated default/home branch ID from user login/profile.
      // Leave application calculations strictly belong to the employee's dedicated branch.
      final effectiveBranchId =
          await LocalStorageService.getEffectiveUserBranchId();
      final branchId = effectiveBranchId.toString();

      // Check transaction hierarchy from UserRights (MenuCode 19):
      // 1 = No hierarchy, 2 = Forward, 3 = Approve/Reject
      // If transactions == 3, the applicant is an approver, so leave is straight approved ('A')
      String finalApprovalStatus = approvalStatus ?? 'N';
      if (finalApprovalStatus != 'A') {
        try {
          final rights = await UserRightsService().fetchUserRights(
            menuCode: 19,
            branchId: effectiveBranchId,
          );
          if (rights.transactions == 3) {
            finalApprovalStatus = 'A';
          }
        } catch (_) {}
      }

      final url = AppUrls.getSaveLeaveApplicationUrl(
        id: 0,
        userId: userId,
        accessPoint: accessPoint,
      );

      final payload = {
        "Head": {
          "BranchID": branchId,
          "LeaveID": leaveId,
          "EmpID": empId,
          "LeaveType": leaveType,
          "FromDate": _formatToIsoDate(fromDate),
          "ToDate": _formatToIsoDate(toDate),
          "NoOfLeaves": noOfLeaves,
          "ApprovalStatus": finalApprovalStatus,
          "Reason": reason,
          "addBy": userId.toString(),
        },
      };

      debugPrint(
        '==================== [LeaveService] SAVE LEAVE APPLICATION ====================',
      );
      debugPrint(
        '[LeaveService] AccessPoint: $accessPoint | UserID: $userId | EmpID: $empId | BranchID: $branchId',
      );
      debugPrint('[LeaveService] Endpoint: $url');
      debugPrint('[LeaveService] Payload: ${jsonEncode(payload)}');

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

      debugPrint('📥 [LeaveService] Response Status: ${response.statusCode}');
      debugPrint('📥 [LeaveService] Response Body: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        int? createdKey;
        String backendError = '';

        if (data is Map) {
          final val = data['value'];
          if (val is int) {
            if (val > 0) {
              createdKey = val;
            } else {
              backendError =
                  'Leave application could not be saved (Code: $val)';
            }
          } else if (val is List && val.isNotEmpty && val.first is Map) {
            final first = val.first as Map;
            createdKey = int.tryParse(
              first['Key']?.toString() ?? first['ID']?.toString() ?? '',
            );
            final errCol =
                first['ERRORMESSAGE']?.toString() ??
                first['ErrorMessage']?.toString() ??
                first['errormessage']?.toString() ??
                first['error']?.toString() ??
                '';
            if (errCol.trim().isNotEmpty) {
              backendError = errCol.trim();
            } else if (createdKey != null && createdKey <= 0) {
              backendError =
                  first['Message']?.toString() ??
                  first['message']?.toString() ??
                  'Leave application could not be saved';
            }
          } else if (val is Map) {
            createdKey = int.tryParse(
              val['Key']?.toString() ?? val['ID']?.toString() ?? '',
            );
          }

          // 1. If SQL Server returned an explicit validation error column, it is a genuine error:
          if (backendError.isNotEmpty) {
            debugPrint(
              '⚠️ [LeaveService] Backend validation error: $backendError',
            );
            return LeaveSaveResult(
              success: false,
              errorMessage: backendError,
              statusCode: response.statusCode,
              data: data,
            );
          }

          // 2. If a valid positive Key was generated, IT IS A SUCCESS!
          if (createdKey != null && createdKey > 0) {
            debugPrint(
              '✅ [LeaveService] Leave record successfully inserted into database with Key: $createdKey',
            );

            if (finalApprovalStatus == 'A') {
              try {
                await approveOrForwardLeave(
                  key: createdKey,
                  approvalStatus: 'A',
                );
              } catch (_) {}
            }

            return LeaveSaveResult(
              success: true,
              statusCode: response.statusCode,
              data: data,
            );
          }

          // 3. Only check 'error' if it's a non-empty error object (ignoring empty map {})
          if (data['error'] != null) {
            final errStr = _extractCleanErrorMessage(data['error']);
            if (errStr.isNotEmpty) {
              debugPrint('⚠️ [LeaveService] Backend error map: $errStr');
              return LeaveSaveResult(
                success: false,
                errorMessage: errStr,
                statusCode: response.statusCode,
                data: data,
              );
            }
          }

          final hasErrorFlag =
              data['IsSuccess'] == false ||
              data['Status'] == false ||
              data['status'] == false ||
              data['StatusCode'] == 0 ||
              data['statusCode'] == 0 ||
              data['StatusCode'] == -1 ||
              data['statusCode'] == -1;

          if (hasErrorFlag) {
            final errStr = _extractCleanErrorMessage(data);
            debugPrint('⚠️ [LeaveService] Backend error flag: $errStr');
            return LeaveSaveResult(
              success: false,
              errorMessage: errStr.isNotEmpty
                  ? errStr
                  : 'Leave application rejected by server validation.',
              statusCode: response.statusCode,
              data: data,
            );
          }
        }

        // Default to success for HTTP 200 with no errors
        return LeaveSaveResult(
          success: true,
          statusCode: response.statusCode,
          data: data,
        );
      }

      final cleanMsg = _extractCleanErrorMessage(response.data);
      return LeaveSaveResult(
        success: false,
        errorMessage: cleanMsg.isNotEmpty
            ? cleanMsg
            : 'Server returned HTTP ${response.statusCode}',
        statusCode: response.statusCode,
        data: response.data,
      );
    } on DioException catch (dioErr) {
      debugPrint('❌❌❌ [LeaveService DIO EXCEPTION]:');
      debugPrint('[LeaveService] Message: ${dioErr.message}');
      debugPrint('[LeaveService] Type: ${dioErr.type}');
      debugPrint('[LeaveService] Endpoint: ${dioErr.requestOptions.uri}');
      debugPrint(
        '[LeaveService] Request Payload: ${dioErr.requestOptions.data}',
      );
      debugPrint(
        '[LeaveService] Response Status: ${dioErr.response?.statusCode}',
      );
      debugPrint('[LeaveService] Response Body: ${dioErr.response?.data}');

      final cleanMsg = _extractCleanErrorMessage(
        dioErr.response?.data ?? dioErr.message,
      );
      return LeaveSaveResult(
        success: false,
        errorMessage: cleanMsg,
        statusCode: dioErr.response?.statusCode,
        data: dioErr.response?.data,
      );
    } catch (e, stack) {
      debugPrint('❌❌❌ [LeaveService UNEXPECTED EXCEPTION]: $e');
      debugPrint('[LeaveService] Stack: $stack');
      return LeaveSaveResult(
        success: false,
        errorMessage: _extractCleanErrorMessage(e),
      );
    }
  }

  /// Backward-compatible wrapper
  Future<bool> saveLeaveApplication({
    required String leaveId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String noOfLeaves,
    required String reason,
    String? approvalStatus,
  }) async {
    final res = await saveLeaveApplicationWithResult(
      leaveId: leaveId,
      leaveType: leaveType,
      fromDate: fromDate,
      toDate: toDate,
      noOfLeaves: noOfLeaves,
      reason: reason,
      approvalStatus: approvalStatus,
    );
    return res.success;
  }

  static String _extractCleanErrorMessage(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) {
      if (raw.isEmpty) return '';
      if (raw['error'] != null) {
        if (raw['error'] is Map) {
          final m =
              raw['error']['Message']?.toString() ??
              raw['error']['message']?.toString();
          if (m != null && m.trim().isNotEmpty) return m.trim();
        } else if (raw['error'].toString().trim().isNotEmpty &&
            raw['error'].toString() != '{}') {
          return raw['error'].toString().trim();
        }
      }
      if (raw['ERRORMESSAGE'] != null &&
          raw['ERRORMESSAGE'].toString().trim().isNotEmpty) {
        return raw['ERRORMESSAGE'].toString().trim();
      }
      if (raw['ErrorMessage'] != null &&
          raw['ErrorMessage'].toString().trim().isNotEmpty) {
        return raw['ErrorMessage'].toString().trim();
      }
      if (raw['Message'] != null &&
          raw['Message'].toString().trim().isNotEmpty) {
        return raw['Message'].toString().trim();
      }
      if (raw['message'] != null &&
          raw['message'].toString().trim().isNotEmpty) {
        return raw['message'].toString().trim();
      }
      if (raw['value'] != null &&
          raw['value'] is List &&
          (raw['value'] as List).isNotEmpty) {
        final first = (raw['value'] as List).first;
        if (first is Map) {
          final em =
              first['ERRORMESSAGE']?.toString() ??
              first['ErrorMessage']?.toString();
          if (em != null && em.trim().isNotEmpty) return em.trim();
        }
      }
      return '';
    }
    final s = raw.toString().trim();
    if (s.isEmpty || s == '{}' || s == '[]') return '';
    final match = RegExp(r'Message:\s*([^,\n}]+)').firstMatch(s);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return s.length > 120 ? '${s.substring(0, 117)}...' : s;
  }

  /// POST /api/HRM/LeaveApplication/v1/Save/{key}/{userId}/{timeStamp}/{accessPoint}
  /// Used by managers to approve ('A') or reject ('R') a leave application
  Future<bool> updateLeaveApprovalStatus({
    required int key,
    required String approvalStatus, // "A" for Approve, "R" for Reject
    Map<String, dynamic>? itemData,
    String? remarks,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) {
        print(
          '❌ [LeaveService.updateLeaveApprovalStatus] Aborted: accessPoint is null/empty',
        );
        return false;
      }
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      // Retrieve existing details to retain proper dates and emp IDs
      final details = await fetchLeaveApplicationDetails(key);

      final raw = itemData?['raw'] as Map<String, dynamic>?;

      final branchId =
          details?.branchId.toString() ??
          raw?['BranchID']?.toString() ??
          raw?['BranchId']?.toString() ??
          itemData?['branchId']?.toString() ??
          "1";
      final leaveId =
          details?.leaveId.toString() ??
          raw?['LeaveID']?.toString() ??
          raw?['LeaveId']?.toString() ??
          itemData?['leaveId']?.toString() ??
          "1";
      final empId =
          details?.empId.toString() ??
          raw?['EmpID']?.toString() ??
          raw?['EmpId']?.toString() ??
          raw?['EmployeeID']?.toString() ??
          itemData?['empId']?.toString() ??
          "26";
      final leaveType =
          details?.leaveType.toString() ??
          raw?['LeaveType']?.toString() ??
          itemData?['leaveType']?.toString() ??
          "1";
      final noOfLeaves =
          details?.noOfLeaves.toString() ??
          raw?['NoOfLeaves']?.toString() ??
          raw?['Days']?.toString() ??
          "1";
      // Find the user's original leave reason from details, itemData, or applications list
      String existingReason = '';
      if (details != null &&
          details.reason.trim().isNotEmpty &&
          !details.reason.toLowerCase().contains('via mobile')) {
        existingReason = details.reason.trim();
      }

      if (existingReason.isEmpty) {
        final fromItem =
            raw?['Reason']?.toString().trim() ??
            raw?['Remarks']?.toString().trim() ??
            itemData?['reason']?.toString().trim() ??
            itemData?['Reason']?.toString().trim() ??
            itemData?['remarks']?.toString().trim();
        if (fromItem != null &&
            fromItem.isNotEmpty &&
            !fromItem.toLowerCase().contains('via mobile')) {
          existingReason = fromItem;
        }
      }

      if (existingReason.isEmpty) {
        try {
          final apps = await fetchLeaveApplications();
          for (final a in apps) {
            if (a.key == key &&
                a.reason.trim().isNotEmpty &&
                !a.reason.toLowerCase().contains('via mobile')) {
              existingReason = a.reason.trim();
              break;
            }
          }
        } catch (_) {}
      }

      // Preserve user's original reason; do not let generic mobile remarks overwrite it
      final reason = existingReason.isNotEmpty
          ? existingReason
          : (remarks != null &&
                    remarks.trim().isNotEmpty &&
                    !remarks.toLowerCase().contains('via mobile')
                ? remarks.trim()
                : 'Leave Application');

      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final fromDate =
          details?.fromDate ??
          raw?['FromDate']?.toString() ??
          itemData?['fromDate']?.toString() ??
          todayStr;
      final toDate =
          details?.toDate ??
          raw?['ToDate']?.toString() ??
          itemData?['toDate']?.toString() ??
          todayStr;

      final url = AppUrls.getSaveLeaveApplicationUrl(
        id: key,
        userId: userId,
        accessPoint: accessPoint,
      );

      final payload = {
        "Head": {
          "BranchID": branchId,
          "LeaveID": leaveId,
          "EmpID": empId,
          "LeaveType": leaveType,
          "FromDate": _formatToIsoDate(fromDate),
          "ToDate": _formatToIsoDate(toDate),
          "NoOfLeaves": noOfLeaves,
          "ApprovalStatus": approvalStatus, // "A", "R", or "C"
          "Reason": reason,
          "addBy": userId.toString(),
        },
      };

      print('------------------------------------------------------------');
      print(
        '📡 [LEAVE APPROVAL SAVE -> POST /api/HRM/LeaveApplication/v1/Save]',
      );
      print('🌐 URL             : $url');
      print(
        '🏢 AccessPoint     : $accessPoint | UserID: $userId | Key: $key | Status: "$approvalStatus"',
      );
      print('🔍 Fetched Details : ${details?.toJson()}');
      print('📦 Payload JSON    : ${jsonEncode(payload)}');
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

      print('📥 [LEAVE APPROVAL SAVE RESPONSE]');
      print('HTTP Status   : ${response.statusCode}');
      print('Response Body : ${response.data}');
      print('------------------------------------------------------------');

      if (response.statusCode != 200) {
        print(
          '⚠️ [LeaveService.updateLeaveApprovalStatus] Non-200 HTTP status: ${response.statusCode}',
        );
      }
      return response.statusCode == 200;
    } on DioException catch (dioErr) {
      print('❌❌❌ [LeaveService.updateLeaveApprovalStatus] DIO EXCEPTION:');
      print('   Message     : ${dioErr.message}');
      print('   Type        : ${dioErr.type}');
      print('   Endpoint    : ${dioErr.requestOptions.uri}');
      print('   Req Payload : ${dioErr.requestOptions.data}');
      print('   HTTP Status : ${dioErr.response?.statusCode}');
      print('   Resp Body   : ${dioErr.response?.data}');
      return false;
    } catch (e, stack) {
      print(
        '❌❌❌ [LeaveService.updateLeaveApprovalStatus] UNEXPECTED EXCEPTION: $e',
      );
      print('Stack: $stack');
      return false;
    }
  }

  /// GET /api/HRM/LeaveCancellation/v1/List/{Page}/{timeStamp}/{accessPoint}
  Future<List<Map<String, dynamic>>> fetchLeaveCancellationList({
    int page = 1,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return [];
      final url = AppUrls.getLeaveCancellationListUrl(
        page: page,
        accessPoint: accessPoint,
      );
      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          return (data['value'] as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('⚠️ [LeaveService] fetchLeaveCancellationList error: $e');
      return [];
    }
  }

  /// Resolves the set of leave application keys that have active pending cancellation requests
  Future<Set<int>> resolvePendingCancellationKeys(
    List<LeaveApplicationModel> myLeaves,
  ) async {
    final localKeys =
        await LocalStorageService.getPendingLeaveCancellationKeys();
    final result = Set<int>.from(localKeys);

    try {
      final cancelList = await fetchLeaveCancellationList();
      for (final cancel in cancelList) {
        final cStatus = (cancel['Status']?.toString() ?? '').toLowerCase();
        // Skip completed/rejected cancellations
        if (cStatus == 'reject' || cStatus == 'rejected') continue;

        final cFrom = cancel['FromDate']?.toString().trim();
        final cTo = cancel['ToDate']?.toString().trim();
        final cLeave = (cancel['Leave']?.toString() ?? '').toLowerCase().trim();

        for (final app in myLeaves) {
          // If the application is already marked Cancelled or Rejected, clear it from pending
          if (app.status.toLowerCase() == 'cancelled' ||
              app.status.toLowerCase() == 'cancel' ||
              app.status.toLowerCase() == 'reject' ||
              app.status.toLowerCase() == 'rejected') {
            await LocalStorageService.removePendingLeaveCancellationKey(
              app.key,
            );
            result.remove(app.key);
            continue;
          }

          final aFrom = app.fromDate.trim();
          final aTo = app.toDate.trim();
          final aLeave = app.leaveName.toLowerCase().trim();

          if (cFrom == aFrom &&
              cTo == aTo &&
              (cLeave.contains(aLeave) || aLeave.contains(cLeave))) {
            result.add(app.key);
            await LocalStorageService.addPendingLeaveCancellationKey(app.key);
          }
        }
      }
    } catch (_) {}

    return result;
  }

  Future<Map<String, dynamic>?> fetchLeaveCancellationDetails(int key) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) {
        print(
          '❌ [LeaveService.fetchLeaveCancellationDetails] Aborted: accessPoint is null/empty',
        );
        return null;
      }
      final url = AppUrls.getLeaveCancellationDetailsUrl(
        key: key,
        accessPoint: accessPoint,
      );

      print(
        '🌐 [LeaveService.fetchLeaveCancellationDetails] GET $url (key=$key)',
      );

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      print(
        '📥 [LeaveService.fetchLeaveCancellationDetails] Key=$key | HTTP ${response.statusCode} | Body: ${response.data}',
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null &&
            data['value'] is List &&
            (data['value'] as List).isNotEmpty) {
          return (data['value'] as List).first as Map<String, dynamic>;
        }
      }
      return null;
    } on DioException catch (dioErr) {
      print(
        '❌ [LeaveService.fetchLeaveCancellationDetails] DIO EXCEPTION Key=$key:',
      );
      print('   Message  : ${dioErr.message}');
      print('   Endpoint : ${dioErr.requestOptions.uri}');
      print('   Status   : ${dioErr.response?.statusCode}');
      print('   Body     : ${dioErr.response?.data}');
      return null;
    } catch (e, stack) {
      print(
        '❌ [LeaveService.fetchLeaveCancellationDetails] ERROR Key=$key: $e',
      );
      print('Stack: $stack');
      return null;
    }
  }

  /// POST /api/HRM/LeaveCancellation/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  Future<bool> saveLeaveCancellation({
    String lvApplicationId = '0',
    String? remarks,
    String?
    approvalStatus, // "N" for Request, "A" for Manager Approval, "R" for Manager Reject
    int cancellationId = 0,
    Map<String, dynamic>? itemData,
  }) async {
    String resolvedLvAppId = lvApplicationId;

    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) {
        print(
          '❌ [LeaveService.saveLeaveCancellation] Aborted: accessPoint is null/empty',
        );
        return false;
      }
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;
      final raw = itemData?['raw'] as Map<String, dynamic>?;
      String branchId =
          raw?['BranchID']?.toString() ??
          raw?['BranchId']?.toString() ??
          itemData?['branchId']?.toString() ??
          "1";
      String resolvedBranchId = branchId;

      // Check transaction hierarchy from UserRights (MenuCode 19):
      // 1 = No hierarchy, 2 = Forward, 3 = Approve/Reject
      // If transactions == 3, the user has Level 3 approval authority, so cancellation is straight approved ('A')
      String finalApprovalStatus = approvalStatus ?? 'N';
      if (finalApprovalStatus != 'A') {
        try {
          final rights = await UserRightsService().fetchUserRights(
            menuCode: 19,
          );
          if (rights.transactions == 3) {
            finalApprovalStatus = 'A';
          }
        } catch (rightsErr) {
          print(
            '⚠️ [LeaveService.saveLeaveCancellation] UserRights fetch failed: $rightsErr',
          );
        }
      }

      // If cancellationId > 0, fetch the cancellation details to retrieve the true LvApplicationID, BranchID, and original remarks!
      String existingCancelRemarks = '';
      if (cancellationId > 0) {
        final details = await fetchLeaveCancellationDetails(cancellationId);
        if (details != null) {
          if (details['LvApplicationID'] != null &&
              details['LvApplicationID'].toString().isNotEmpty &&
              details['LvApplicationID'].toString() != "0") {
            resolvedLvAppId = details['LvApplicationID'].toString();
          }
          if (details['BranchID'] != null &&
              details['BranchID'].toString().isNotEmpty &&
              details['BranchID'].toString() != "0") {
            resolvedBranchId = details['BranchID'].toString();
          }
          final r = details['Remarks']?.toString().trim();
          if (r != null &&
              r.isNotEmpty &&
              !r.toLowerCase().contains('via mobile')) {
            existingCancelRemarks = r;
          }
        }
      }

      if (existingCancelRemarks.isEmpty) {
        final fromItem =
            raw?['Remarks']?.toString().trim() ??
            itemData?['remarks']?.toString().trim() ??
            itemData?['Remarks']?.toString().trim() ??
            itemData?['reason']?.toString().trim();
        if (fromItem != null &&
            fromItem.isNotEmpty &&
            !fromItem.toLowerCase().contains('via mobile')) {
          existingCancelRemarks = fromItem;
        }
      }

      final resolvedRemarks =
          (remarks != null &&
              remarks.trim().isNotEmpty &&
              !remarks.toLowerCase().contains('via mobile'))
          ? remarks.trim()
          : (existingCancelRemarks.isNotEmpty
                ? existingCancelRemarks
                : 'Leave cancellation request');

      final url = AppUrls.getSaveLeaveCancellationUrl(
        id: cancellationId > 0 ? cancellationId : 0,
        userId: userId,
        accessPoint: accessPoint,
      );

      final payload = {
        "Head": {
          "LvCancelID": cancellationId > 0 ? cancellationId.toString() : "0",
          "LvApplicationID": resolvedLvAppId,
          "ApprovalStatus": finalApprovalStatus,
          "Remarks": resolvedRemarks,
          "BranchID": resolvedBranchId,
        },
      };

      print('------------------------------------------------------------');
      print(
        '📡 [LEAVE CANCELLATION SAVE -> POST /api/HRM/LeaveCancellation/v1/Save]',
      );
      print('🌐 URL            : $url');
      print(
        '🏢 AccessPoint    : $accessPoint | UserID: $userId | CancelID: $cancellationId | Status: "$finalApprovalStatus"',
      );
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

      print('📥 [LEAVE CANCELLATION SAVE RESPONSE]');
      print('HTTP Status   : ${response.statusCode}');
      print('Response Body : ${response.data}');
      print('------------------------------------------------------------');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map &&
            (data['error'] == null ||
                (data['error'] is Map && (data['error'] as Map).isEmpty))) {
          // If manager approved ('A') the cancellation, also synchronize the underlying
          // leave application's status to 'C' (Cancelled) so it updates across all dashboards
          if (finalApprovalStatus == 'A') {
            final key = int.tryParse(resolvedLvAppId);
            if (key != null && key > 0) {
              await updateLeaveApprovalStatus(
                key: key,
                approvalStatus: 'C',
                itemData: itemData,
                remarks: null,
              );
            }
          } else {
            // Employee submitted a cancellation request; register it in pending local storage
            final key = int.tryParse(resolvedLvAppId);
            if (key != null && key > 0) {
              await LocalStorageService.addPendingLeaveCancellationKey(key);
            }
          }
          return true;
        }
        print(
          '⚠️ [LeaveService.saveLeaveCancellation] Server returned error in 200 body: ${data is Map ? data['error'] : data}',
        );
      }
    } on DioException catch (dioErr) {
      print('❌ [LeaveService.saveLeaveCancellation] DIO EXCEPTION:');
      print('   Message     : ${dioErr.message}');
      print('   Type        : ${dioErr.type}');
      print('   Endpoint    : ${dioErr.requestOptions.uri}');
      print('   Req Payload : ${dioErr.requestOptions.data}');
      print('   HTTP Status : ${dioErr.response?.statusCode}');
      print('   Resp Body   : ${dioErr.response?.data}');
    } catch (e, stack) {
      print('❌ [LeaveService.saveLeaveCancellation] ERROR: $e');
      print('Stack: $stack');
    }

    // Fallback: Directly cancel the Leave Application via 'C' status
    // This ensures leave cancellation succeeds gracefully even if the backend SQL Server
    // has not initialized the 'hrmLeaveCancellationTrack' table.
    try {
      final key = int.tryParse(resolvedLvAppId);
      if (key != null && key > 0) {
        // When manager approves ('A') or employee cancels ('C'/'N'), the leave becomes 'C' (Cancelled).
        // If manager rejects ('R') the cancellation, the leave stays 'A' (Approved).
        final fallbackStatus =
            (approvalStatus == 'A' ||
                approvalStatus == 'C' ||
                approvalStatus == 'N')
            ? 'C'
            : 'A';
        print(
          '🔄 [LeaveService.saveLeaveCancellation] Falling back to updateLeaveApprovalStatus(key=$key, status=$fallbackStatus)...',
        );
        final fallbackSuccess = await updateLeaveApprovalStatus(
          key: key,
          approvalStatus: fallbackStatus,
          itemData: itemData,
          remarks: null,
        );
        print(
          '🏁 [LeaveService.saveLeaveCancellation] Fallback result: $fallbackSuccess',
        );
        if (fallbackSuccess) {
          return true;
        }
      }
    } catch (fallbackErr) {
      print(
        '❌ [LeaveService.saveLeaveCancellation] Fallback ERROR: $fallbackErr',
      );
    }

    return false;
  }

  /// GET /api/HRM/General/v1/DashBoard/{accessPoint}/{timeStamp}?MonthCode={date}&Type=A
  /// Returns Table4 containing Leaves (For The Month) matching web portal
  Future<List<Map<String, dynamic>>> fetchDashboardLeaves({
    String? date,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return [];
      final url = AppUrls.getGeneralDashboardUrl(
        accessPoint: accessPoint,
        monthCode: date,
        type: 'A',
      );

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is Map) {
          final table4 = data['value']['Table4'];
          if (table4 != null && table4 is List) {
            return table4
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// POST /api/HRM/LeaveApplication/v1/EmpSearch/{timeStamp}/{accessPoint}
  Future<List<LeaveApplicationModel>> searchEmployeeLeaves({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return [];
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;
      const branchId = 1;

      final url = AppUrls.getLeaveEmpSearchUrl(accessPoint: accessPoint);

      final payload = {
        "Head": {
          "BranchID": branchId.toString(),
          "UserID": userId.toString(),
          "StartDate": startDate ?? "",
          "EndDate": endDate ?? "",
        },
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
          return (data['value'] as List)
              .map(
                (e) => LeaveApplicationModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// POST /api/HRM/General/v1/Reject/{accessPoint}/{timeStamp} ('R')
  /// POST /api/HRM/LeaveApplication/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint} ('A', 'F')
  Future<InboxApprovalResult> approveOrForwardLeaveWithResult({
    required int key,
    required String approvalStatus,
    String? menuLinkCode,
    Map<String, dynamic>? itemData,
    String? remarks,
  }) async {
    final normalized = approvalStatus.trim().toUpperCase();
    if (normalized == 'R') {
      print(
        '🔄 [LeaveService.approveOrForwardLeave] Rejecting via General/Reject (key=$key, menuLinkCode=$menuLinkCode)',
      );
      return InboxService().submitApprovalAction(
        recordId: key,
        action: 'R',
        menuLinkCode: menuLinkCode,
        defaultMenuLinkCode: '10',
        itemData: itemData,
      );
    }

    print(
      '🔄 [LeaveService.approveOrForwardLeave] Approving via Leave Save endpoint (key=$key, status=$normalized)',
    );
    final success = await updateLeaveApprovalStatus(
      key: key,
      approvalStatus: normalized,
      itemData: itemData,
      remarks: remarks,
    );
    if (success) {
      return const InboxApprovalResult(success: true);
    }
    return const InboxApprovalResult(
      success: false,
      errorMessage: 'Failed to approve leave application. Please try again.',
    );
  }

  /// Backward-compatible wrapper returning bool
  Future<bool> approveOrForwardLeave({
    required int key,
    required String approvalStatus,
    String? menuLinkCode,
    Map<String, dynamic>? itemData,
    String? remarks,
  }) async {
    final result = await approveOrForwardLeaveWithResult(
      key: key,
      approvalStatus: approvalStatus,
      menuLinkCode: menuLinkCode,
      itemData: itemData,
      remarks: remarks,
    );
    return result.success;
  }
}

class LeaveSaveResult {
  final bool success;
  final String? errorMessage;
  final int? statusCode;
  final dynamic data;

  const LeaveSaveResult({
    required this.success,
    this.errorMessage,
    this.statusCode,
    this.data,
  });
}

class LeaveCalculationResult {
  final double days;
  final String? errorMessage;

  const LeaveCalculationResult({required this.days, this.errorMessage});
}
