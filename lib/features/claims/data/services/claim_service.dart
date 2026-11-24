import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/models/user_rights_model.dart';
import '../../../auth/data/services/user_rights_service.dart';
import '../../../notifications/data/services/inbox_service.dart';
import '../models/claim_models.dart';

class ClaimService {
  final Dio _dio = Dio();

  String _formatToDate(dynamic rawDate) {
    if (rawDate == null || rawDate.toString().isEmpty) {
      return DateFormat('dd/MM/yyyy').format(DateTime.now());
    }
    final str = rawDate.toString();
    try {
      if (str.contains('-')) {
        final parts = str.split('-');
        if (parts.length == 3) {
          // yyyy-MM-dd -> dd/MM/yyyy
          final year = parts[0];
          final month = parts[1].padLeft(2, '0');
          final day = parts[2].padLeft(2, '0');
          return '$day/$month/$year';
        }
      }
      final parsed = DateTime.tryParse(str);
      if (parsed != null) {
        return DateFormat('dd/MM/yyyy').format(parsed);
      }
    } catch (_) {}
    return str;
  }

  Future<String?> _getValidAccessPoint() async {
    final ap = await LocalStorageService.getAccessPoint();
    if (ap == null || ap.trim().isEmpty) return null;
    return ap.trim();
  }

  /// GET /api/HRM/General/v1/GetUserRights/{accessPoint}/{timeStamp}/15/{userId}/{branchId}
  Future<UserRightsModel?> fetchClaimUserRights({int? branchId}) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return UserRightsModel.noAccess();
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;
      final targetBranchId =
          branchId ?? (await LocalStorageService.getEffectiveUserBranchId());

      final url = AppUrls.getUserRightsUrl(
        accessPoint: accessPoint,
        menuCode: 15, // Claim Form Menu Code
        userId: userId,
        branchId: targetBranchId,
      );

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null &&
            data['value'] is List &&
            (data['value'] as List).isNotEmpty) {
          final firstItem =
              (data['value'] as List).first as Map<String, dynamic>;
          return UserRightsModel.fromJson(firstItem);
        }
      }

      return UserRightsModel.noAccess();
    } catch (e) {
      return UserRightsModel.noAccess();
    }
  }

  /// GET /api/HRM/General/v1/RetrieveDataTable_GeneralDetails/{accessPoint}/{timeStamp}?iD=0&param=ClaimMaster
  Future<List<ClaimMasterItem>> fetchClaimCategories() async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return [];
      final url = AppUrls.getClaimMasterUrl(accessPoint: accessPoint);

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          return list
              .map(
                (item) =>
                    ClaimMasterItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// POST /api/HRM/ClaimForm/v1/GetRate/{timeStamp}/{accessPoint}
  Future<ClaimRateResult> getClaimRate(String claimId) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return ClaimRateResult(rate: 0.0, rateFlag: 0);
      final url = AppUrls.getClaimRateUrl(accessPoint: accessPoint);

      final payload = {
        "Head": {"ClaimID": claimId},
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
        if (data['value'] != null &&
            data['value'] is List &&
            (data['value'] as List).isNotEmpty) {
          final first = (data['value'] as List).first as Map<String, dynamic>;
          return ClaimRateResult.fromJson(first);
        }
      }

      return ClaimRateResult(rate: 0.0, rateFlag: 0);
    } catch (e) {
      return ClaimRateResult(rate: 0.0, rateFlag: 0);
    }
  }

  /// GET /api/HRM/ClaimForm/v1/List/{timeStamp}/{accessPoint}
  Future<List<ClaimModel>> fetchClaims() async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return [];
      final url = AppUrls.getClaimListUrl(accessPoint: accessPoint);

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          final allClaims = list
              .map((item) => ClaimModel.fromJson(item as Map<String, dynamic>))
              .toList();

          final user = await LocalStorageService.getUser();
          final userEmpId = user?.employeeId.toString() ?? '0';
          final userId = user?.userId.toString() ?? '0';
          final userName = user?.userName.toLowerCase().trim() ?? '';

          final userClaims = allClaims.where((c) {
            if (userEmpId != '0' && c.empId == userEmpId) return true;
            if (userId != '0' && c.empId == userId) return true;
            if (userName.isNotEmpty &&
                c.employeeName.toLowerCase().trim().contains(userName)) {
              return true;
            }
            return false;
          }).toList();

          return userClaims;
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  /// POST /api/HRM/ClaimForm/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  Future<ClaimSaveResult> saveClaimFormWithResult({
    required String claimDate,
    required String remarks,
    required double totalAmount,
    required List<ClaimTailItem> tailItems,
    String? approvalStatus,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) {
        return ClaimSaveResult(
          success: false,
          errorMessage: 'Company access point not configured.',
        );
      }
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;
      final empId = user?.employeeId != null && user!.employeeId > 0
          ? user.employeeId.toString()
          : userId.toString();

      debugPrint('====================================================');
      debugPrint('🚀 [CLAIM SERVICE - SUBMIT CLAIM]');
      debugPrint('🏢 AccessPoint: $accessPoint');
      debugPrint(
        '👤 Logged-in User: ${user?.userName} (UserID: $userId, EmpID: ${user?.employeeId}, FallbackEmpID: $empId)',
      );
      debugPrint(
        '📅 Claim Date: $claimDate -> Formatted: ${_formatToDate(claimDate)}',
      );
      debugPrint('💰 Total Amount: $totalAmount');
      debugPrint('📝 Remarks: $remarks');

      // Check transaction hierarchy from UserRights (MenuCode 15 for Claims):
      // If transactions == 3, the user has Level 3 approval authority (Manager) -> Approve directly ('A')
      String finalApprovalStatus = approvalStatus ?? 'N';
      if (finalApprovalStatus != 'A') {
        try {
          final rights = await UserRightsService().fetchUserRights(
            menuCode: 15,
          );
          debugPrint(
            '🔑 UserRights for MenuCode 15: transactions=${rights.transactions}, add=${rights.addRight}, edit=${rights.modiRight}',
          );
          if (rights.transactions == 3) {
            finalApprovalStatus = 'A';
          }
        } catch (err) {
          debugPrint('⚠️ Error fetching user rights for claims: $err');
        }
      }

      debugPrint('🛡️ Final ApprovalStatus for Claim: $finalApprovalStatus');

      final url = AppUrls.getSaveClaimUrl(
        id: 0,
        userId: userId,
        accessPoint: accessPoint,
      );
      debugPrint('🌐 Post URL: $url');

      final List<Map<String, dynamic>> tailPayload = tailItems.map((item) {
        final json = item.toJson();
        if (finalApprovalStatus == 'A') {
          json['StatusText'] = 'Approved';
        }
        return json;
      }).toList();

      final payload = {
        "Head": {
          "BranchID": "1",
          "FinYearID": "3",
          "ClaimDate": _formatToDate(claimDate),
          "ClaimNumber": "0",
          "EmpID": empId,
          "Amount": totalAmount.toStringAsFixed(2),
          "ApprovalStatus": finalApprovalStatus,
          "Remarks": remarks,
          "addBy": userId.toString(),
        },
        "Tail": tailPayload,
      };

      debugPrint('📦 Payload Head: ${jsonEncode(payload['Head'])}');
      debugPrint('📦 Payload Tail Items count: ${tailPayload.length}');
      for (int i = 0; i < tailPayload.length; i++) {
        debugPrint('   [$i] ${jsonEncode(tailPayload[i])}');
      }

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

      debugPrint('📥 Claim Response Status: ${response.statusCode}');
      debugPrint('📥 Claim Response Data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data is Map) {
          // Check ERRORMESSAGE in value list
          if (data['value'] is List && (data['value'] as List).isNotEmpty) {
            final first = (data['value'] as List).first;
            if (first is Map && first['ERRORMESSAGE'] != null) {
              final errMsg = first['ERRORMESSAGE'].toString().trim();
              if (errMsg.isNotEmpty) {
                debugPrint('❌ [CLAIM SERVICE ERROR FROM BACKEND]: $errMsg');
                debugPrint(
                  '====================================================',
                );
                return ClaimSaveResult(
                  success: false,
                  errorMessage: errMsg,
                  approvalStatus: finalApprovalStatus,
                  statusCode: response.statusCode,
                );
              }
            }
          }
          // Check top-level error object
          if (data['error'] is Map && data['error']['ErrorMessage'] != null) {
            final errMsg = data['error']['ErrorMessage'].toString().trim();
            if (errMsg.isNotEmpty) {
              debugPrint('❌ [CLAIM SERVICE ERROR OBJECT]: $errMsg');
              debugPrint(
                '====================================================',
              );
              return ClaimSaveResult(
                success: false,
                errorMessage: errMsg,
                approvalStatus: finalApprovalStatus,
                statusCode: response.statusCode,
              );
            }
          }
        }
        debugPrint('✅ [CLAIM SERVICE] Save claim SUCCESS!');
        debugPrint('====================================================');
        return ClaimSaveResult(
          success: true,
          approvalStatus: finalApprovalStatus,
          statusCode: response.statusCode,
        );
      }

      debugPrint(
        '❌ [CLAIM SERVICE] Unexpected status code or null data: ${response.statusCode}',
      );
      debugPrint('====================================================');
      return ClaimSaveResult(
        success: false,
        errorMessage: 'Server returned code ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ [CLAIM SERVICE EXCEPTION]: $e');
      String errMsg = 'Failed to submit claim. Please try again.';
      int? statusCode;
      if (e is DioException) {
        statusCode = e.response?.statusCode;
        debugPrint('❌ [DIO EXCEPTION STATUS]: $statusCode');
        debugPrint('❌ [DIO EXCEPTION DATA]: ${e.response?.data}');
        final respData = e.response?.data;
        if (respData is Map) {
          final serverErr =
              respData['error']?['ErrorMessage'] ??
              respData['message'] ??
              respData['title'];
          if (serverErr != null && serverErr.toString().trim().isNotEmpty) {
            errMsg = serverErr.toString();
          }
        } else if (e.message != null && e.message!.isNotEmpty) {
          errMsg = e.message!;
        }
      }
      debugPrint('❌ [STACK TRACE]: $stackTrace');
      debugPrint('====================================================');
      return ClaimSaveResult(
        success: false,
        errorMessage: errMsg,
        statusCode: statusCode,
      );
    }
  }

  /// Backward-compatible wrapper
  Future<bool> saveClaimForm({
    required String claimDate,
    required String remarks,
    required double totalAmount,
    required List<ClaimTailItem> tailItems,
    String? approvalStatus,
  }) async {
    final result = await saveClaimFormWithResult(
      claimDate: claimDate,
      remarks: remarks,
      totalAmount: totalAmount,
      tailItems: tailItems,
      approvalStatus: approvalStatus,
    );
    return result.success;
  }

  /// GET /api/HRM/ClaimForm/v1/Get/{id}/{timeStamp}/{accessPoint}
  Future<Map<String, dynamic>?> fetchClaimRawDetails(int key) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return null;
      final url = AppUrls.getClaimDetailsUrl(
        key: key,
        accessPoint: accessPoint,
      );

      final response = await _dio.get(
        url,
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is Map) {
          return Map<String, dynamic>.from(data['value'] as Map);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// POST /api/HRM/ClaimForm/v1/Save/{key}/{userId}/{timeStamp}/{accessPoint}
  Future<bool> updateClaimApprovalStatus({
    required int key,
    required String approvalStatus, // "A" for Approve, "R" for Reject
    Map<String, dynamic>? itemData,
    String? remarks,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return false;
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      // Fetch existing claim data from backend to ensure all fields are accurate
      final rawDetails = await fetchClaimRawDetails(key);
      Map<String, dynamic>? headTable;
      List<dynamic>? tailTable;

      if (rawDetails != null) {
        if (rawDetails['Table'] is List &&
            (rawDetails['Table'] as List).isNotEmpty) {
          headTable = Map<String, dynamic>.from(
            (rawDetails['Table'] as List).first as Map,
          );
        }
        if (rawDetails['Table1'] is List) {
          tailTable = rawDetails['Table1'] as List;
        }
      }

      final branchId =
          int.tryParse(
            headTable?['BranchID']?.toString() ??
                itemData?['branchId']?.toString() ??
                "1",
          ) ??
          1;
      final finYearId =
          int.tryParse(
            headTable?['FinYearID']?.toString() ??
                itemData?['finYearId']?.toString() ??
                "1",
          ) ??
          1;
      final empId =
          int.tryParse(
            headTable?['EmpID']?.toString() ??
                itemData?['empId']?.toString() ??
                "1",
          ) ??
          1;
      final amount =
          double.tryParse(
            headTable?['Amount']?.toString().replaceAll('₹', '').trim() ??
                itemData?['amount']?.toString().replaceAll('₹', '').trim() ??
                '0',
          ) ??
          0.0;
      final claimNumber = headTable?['ClaimNumber']?.toString() ?? "0";
      final claimDate =
          headTable?['ClaimDate']?.toString() ??
          (itemData?['date'] != null
              ? _formatToDate(itemData!['date'])
              : _formatToDate(DateTime.now().toString()));

      // Fetch existing user remarks from headTable or itemData so approval never overwrites them
      String existingRemarks = '';
      final fromHead = headTable?['Remarks']?.toString().trim();
      if (fromHead != null &&
          fromHead.isNotEmpty &&
          !fromHead.toLowerCase().contains('via mobile')) {
        existingRemarks = fromHead;
      } else {
        final fromItem =
            itemData?['remarks']?.toString().trim() ??
            itemData?['Remarks']?.toString().trim() ??
            itemData?['reason']?.toString().trim() ??
            itemData?['Reason']?.toString().trim() ??
            itemData?['description']?.toString().trim();
        if (fromItem != null &&
            fromItem.isNotEmpty &&
            !fromItem.toLowerCase().contains('via mobile')) {
          existingRemarks = fromItem;
        }
      }

      // Preserve user's original remarks; do not let generic mobile remarks overwrite them
      final resolvedRemarks =
          (remarks != null &&
              remarks.trim().isNotEmpty &&
              !remarks.toLowerCase().contains('via mobile'))
          ? remarks.trim()
          : (existingRemarks.isNotEmpty
                ? existingRemarks
                : 'Expense claim application');

      List<Map<String, dynamic>> tailList = [];
      if (tailTable != null && tailTable.isNotEmpty) {
        tailList = tailTable.map((t) {
          final m = Map<String, dynamic>.from(t as Map);
          return {
            "ClaimID": int.tryParse(m['ClaimID']?.toString() ?? "1") ?? 1,
            "ClaimName": m['ClaimName']?.toString() ?? "Expense Claim",
            "Amount": double.tryParse(m['Amount']?.toString() ?? '0') ?? 0.0,
            "Rate": double.tryParse(m['Rate']?.toString() ?? '0') ?? 0.0,
            "RateFlag": int.tryParse(m['RateFlag']?.toString() ?? "0") ?? 0,
            "Qty": double.tryParse(m['Qty']?.toString() ?? "1") ?? 1.0,
            "Reason": m['Reason']?.toString() ?? "Expense Claim",
            "Date": m['Date']?.toString() ?? claimDate,
            "Status": approvalStatus == 'A' ? 1 : 0,
            "StatusText": approvalStatus == 'A' ? "Approved" : "Rejected",
          };
        }).toList();
      } else {
        tailList = [
          {
            "ClaimID": 1,
            "ClaimName": itemData?['claimCategory'] ?? "General Expense",
            "Amount": amount,
            "Rate": 0.0,
            "RateFlag": 0,
            "Qty": 1.0,
            "Reason": itemData?['description'] ?? "Expense Claim",
            "Date": claimDate,
            "Status": approvalStatus == 'A' ? 1 : 0,
            "StatusText": approvalStatus == 'A' ? "Approved" : "Rejected",
          },
        ];
      }

      final url = AppUrls.getSaveClaimUrl(
        id: key,
        userId: userId,
        accessPoint: accessPoint,
      );

      final payload = {
        "Head": {
          "BranchID": branchId,
          "FinYearID": finYearId,
          "ClaimDate": claimDate,
          "ClaimNumber": claimNumber,
          "EmpID": empId,
          "Amount": amount,
          "ApprovalStatus": approvalStatus, // "A" or "R"
          "Remarks": resolvedRemarks,
          "addBy": userId,
        },
        "Tail": tailList,
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
        if (data is Map &&
            (data['error'] == null ||
                (data['error'] is Map && (data['error'] as Map).isEmpty))) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/HRM/ClaimForm/v1/Delete/{id}/{timeStamp}/{accessPoint}
  Future<({bool success, String? message})> deleteClaimWithResult(
    int id,
  ) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) {
        return (success: false, message: 'Access point not configured.');
      }
      final url = AppUrls.getDeleteClaimUrl(id: id, accessPoint: accessPoint);

      debugPrint(
        '==================== [ClaimService] DELETE CLAIM ====================',
      );
      debugPrint(
        '👉 [ClaimService] Endpoint: $url | ClaimID: $id | AccessPoint: $accessPoint',
      );

      final response = await _dio.post(
        url,
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 600,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      debugPrint(
        '📥 [ClaimService] Delete Response Status: ${response.statusCode}',
      );
      debugPrint('📥 [ClaimService] Delete Response Body: ${response.data}');

      final code = response.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        final rawBody = response.data?.toString().trim() ?? '';
        if (rawBody.isNotEmpty) {
          try {
            final decoded = jsonDecode(rawBody);
            if (decoded is Map) {
              final err = decoded['error'];
              if (err is Map &&
                  err['Message'] != null &&
                  err['Message'].toString().trim().isNotEmpty) {
                return (
                  success: false,
                  message: _cleanDeleteErrorMessage(
                    err['Message'].toString().trim(),
                  ),
                );
              }
              final val = decoded['value'];
              if (val is List && val.isNotEmpty && val.first is Map) {
                final first = val.first as Map;
                final rawMsg =
                    (first['ERRORMESSAGE'] ??
                            first['ErrorMessage'] ??
                            first['errormessage'] ??
                            first['Message'] ??
                            first['message'])
                        ?.toString()
                        .trim() ??
                    '';
                if (rawMsg.isNotEmpty) {
                  final lower = rawMsg.toLowerCase();
                  final isSuccessMsg =
                      lower.contains('success') ||
                      lower.contains('deleted') ||
                      lower.contains('ok') ||
                      lower == '1' ||
                      lower == 'true';
                  if (!isSuccessMsg) {
                    return (
                      success: false,
                      message: _cleanDeleteErrorMessage(rawMsg),
                    );
                  }
                  return (success: true, message: rawMsg);
                }
              }
            }
          } catch (_) {
            // Non-JSON or empty 204/200 body still counts as success
          }
        }
        return (
          success: true,
          message: 'Claim application deleted successfully!',
        );
      }

      String? serverMsg;
      if (response.data != null) {
        try {
          final decoded = jsonDecode(response.data.toString());
          if (decoded is Map) {
            serverMsg =
                decoded['error']?['Message']?.toString() ??
                decoded['Message']?.toString() ??
                decoded['ExceptionMessage']?.toString();
          }
        } catch (_) {}
      }

      return (
        success: false,
        message: _cleanDeleteErrorMessage(
          serverMsg ?? 'Server returned HTTP $code while deleting claim.',
        ),
      );
    } on DioException catch (dioErr) {
      debugPrint('❌ [ClaimService] deleteClaim DioException: $dioErr');
      final code = dioErr.response?.statusCode;
      if (code != null && code >= 200 && code < 300) {
        return (
          success: true,
          message: 'Claim application deleted successfully!',
        );
      }
      final serverData = dioErr.response?.data;
      String? msg;
      if (serverData != null) {
        try {
          final decoded = serverData is Map
              ? serverData
              : jsonDecode(serverData.toString());
          if (decoded is Map) {
            msg =
                decoded['error']?['Message']?.toString() ??
                decoded['Message']?.toString() ??
                decoded['ExceptionMessage']?.toString();
          }
        } catch (_) {}
      }
      return (
        success: false,
        message: _cleanDeleteErrorMessage(
          msg ?? 'Server error ($code) while deleting claim.',
        ),
      );
    } catch (e) {
      debugPrint('❌ [ClaimService] deleteClaim error: $e');
      return (success: false, message: _cleanDeleteErrorMessage(e.toString()));
    }
  }

  static String _cleanDeleteErrorMessage(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Failed to delete claim. Please try again.';
    if (trimmed.contains('validateStatus') ||
        trimmed.contains('status code of')) {
      return 'Server error occurred while deleting claim. Please try again later.';
    }
    if (trimmed.contains('\n')) {
      final firstLine = trimmed.split(RegExp(r'\r?\n')).first.trim();
      if (firstLine.isNotEmpty && firstLine.length <= 150) return firstLine;
    }
    return trimmed.length > 150 ? '${trimmed.substring(0, 147)}...' : trimmed;
  }

  /// Backward-compatible boolean wrapper
  Future<bool> deleteClaim(int id) async {
    final res = await deleteClaimWithResult(id);
    return res.success;
  }

  /// POST /api/HRM/ClaimForm/v1/EmpSearch/{timeStamp}/{accessPoint}
  Future<List<ClaimModel>> searchEmployeeClaims({
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final accessPoint = await _getValidAccessPoint();
      if (accessPoint == null) return [];
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;
      final effectiveBranchId =
          await LocalStorageService.getEffectiveUserBranchId();

      final url = AppUrls.getClaimEmpSearchUrl(accessPoint: accessPoint);

      final payload = {
        "Head": {
          "BranchID": effectiveBranchId.toString(),
          "UserID": userId.toString(),
          "FromDate": (fromDate != null && fromDate.isNotEmpty)
              ? fromDate
              : "01/01/2020",
          "ToDate": (toDate != null && toDate.isNotEmpty)
              ? toDate
              : "31/12/2030",
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
                (e) => ClaimModel.fromJson(Map<String, dynamic>.from(e as Map)),
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
  /// POST /api/HRM/ClaimForm/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint} ('A', 'F')
  Future<InboxApprovalResult> approveOrForwardClaimWithResult({
    required int key,
    required String approvalStatus,
    String? menuLinkCode,
    Map<String, dynamic>? itemData,
    String? remarks,
  }) async {
    final normalized = approvalStatus.trim().toUpperCase();
    if (normalized == 'R') {
      print(
        '🔄 [ClaimService.approveOrForwardClaim] Rejecting via General/Reject (key=$key, menuLinkCode=$menuLinkCode)',
      );
      return InboxService().submitApprovalAction(
        recordId: key,
        action: 'R',
        menuLinkCode: menuLinkCode,
        defaultMenuLinkCode: '3',
        itemData: itemData,
      );
    }

    print(
      '🔄 [ClaimService.approveOrForwardClaim] Approving via Claim Save endpoint (key=$key, status=$normalized)',
    );
    final success = await updateClaimApprovalStatus(
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
      errorMessage: 'Failed to approve claim application. Please try again.',
    );
  }

  /// Backward-compatible wrapper returning bool
  Future<bool> approveOrForwardClaim({
    required int key,
    required String approvalStatus,
    String? menuLinkCode,
    Map<String, dynamic>? itemData,
    String? remarks,
  }) async {
    final result = await approveOrForwardClaimWithResult(
      key: key,
      approvalStatus: approvalStatus,
      menuLinkCode: menuLinkCode,
      itemData: itemData,
      remarks: remarks,
    );
    return result.success;
  }
}
