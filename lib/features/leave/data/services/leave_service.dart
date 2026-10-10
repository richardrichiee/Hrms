import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/services/user_rights_service.dart';
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

  Future<List<LeaveApplicationModel>> fetchLeaveApplications() async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      final url = AppUrls.getLeaveApplicationListUrl(
        userId: userId,
        accessPoint: accessPoint,
      );

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is List) {
          final list = data['value'] as List;
          return list
              .map((item) => LeaveApplicationModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }

      return [];
    } catch (e) {
      return [];
    }
  }

  Future<LeaveDetailsModel?> fetchLeaveApplicationDetails(int key) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';

      final url = AppUrls.getLeaveApplicationDetailsUrl(
        key: key,
        accessPoint: accessPoint,
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
          return LeaveDetailsModel.fromJson(firstItem);
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// POST /api/HRM/LeaveApplication/v1/Calculation/{timeStamp}/{accessPoint}
  Future<double> calculateLeaveDays({
    required String leaveId,
    required String leaveType,
    required String fromDate,
    required String toDate,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final empId = user?.employeeId.toString() ?? '1';

      final url = AppUrls.getLeaveApplicationCalculationUrl(accessPoint: accessPoint);

      final payload = {
        "Head": {
          "BranchID": null,
          "LeaveID": leaveId,
          "EmpID": empId,
          "LeaveType": leaveType,
          "FromDate": fromDate,
          "ToDate": toDate,
          "NoOfLeaves": null,
          "ApprovalStatus": null,
          "Reason": null
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
        if (data['value'] != null) {
          final val = data['value'];
          if (val is Map && val['NoOfLeaves'] != null) {
            return double.tryParse(val['NoOfLeaves'].toString()) ?? 1.0;
          } else if (val is num) {
            return val.toDouble();
          }
        }
      }

      final start = DateTime.tryParse(fromDate) ?? DateTime.now();
      final end = DateTime.tryParse(toDate) ?? DateTime.now();
      final diff = end.difference(start).inDays + 1;
      return leaveType == '1' ? diff.toDouble() : 0.5;
    } catch (e) {
      final start = DateTime.tryParse(fromDate) ?? DateTime.now();
      final end = DateTime.tryParse(toDate) ?? DateTime.now();
      final diff = end.difference(start).inDays + 1;
      return leaveType == '1' ? diff.toDouble() : 0.5;
    }
  }

  /// POST /api/HRM/LeaveApplication/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  Future<bool> saveLeaveApplication({
    required String leaveId,
    required String leaveType,
    required String fromDate,
    required String toDate,
    required String noOfLeaves,
    required String reason,
    String? approvalStatus,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;
      final empId = (user?.employeeId != null && user!.employeeId > 0)
          ? user.employeeId.toString()
          : (user?.userId != null && user!.userId > 0 ? user.userId.toString() : '26');

      // Check transaction hierarchy from UserRights (MenuCode 19):
      // 1 = No hierarchy, 2 = Forward, 3 = Approve/Reject
      // If transactions == 3, the applicant is an approver, so leave is straight approved ('A')
      String finalApprovalStatus = approvalStatus ?? 'N';
      if (finalApprovalStatus != 'A') {
        try {
          final rights = await UserRightsService().fetchUserRights(menuCode: 19);
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
          "BranchID": "1",
          "LeaveID": leaveId,
          "EmpID": empId,
          "LeaveType": leaveType,
          "FromDate": _formatToIsoDate(fromDate),
          "ToDate": _formatToIsoDate(toDate),
          "NoOfLeaves": noOfLeaves,
          "ApprovalStatus": finalApprovalStatus,
          "Reason": reason,
          "addBy": userId.toString(),
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

      if (response.statusCode == 200) {
        if (finalApprovalStatus == 'A') {
          // If response provides the created record Key/ID, also trigger approveOrForwardLeave
          // to guarantee both database tables and workflow state mark it as Approved
          try {
            int? createdKey;
            if (response.data != null && response.data is Map) {
              final val = response.data['value'];
              if (val is int) {
                createdKey = val;
              } else if (val is Map && val['Key'] != null) {
                createdKey = int.tryParse(val['Key'].toString());
              } else if (val is List && val.isNotEmpty && val.first is Map) {
                createdKey = int.tryParse(
                    val.first['Key']?.toString() ?? val.first['ID']?.toString() ?? '');
              }
            }
            if (createdKey != null && createdKey > 0) {
              await approveOrForwardLeave(key: createdKey, approvalStatus: 'A');
            }
          } catch (_) {}
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
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
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      // Retrieve existing details to retain proper dates and emp IDs
      final details = await fetchLeaveApplicationDetails(key);

      final raw = itemData?['raw'] as Map<String, dynamic>?;

      final branchId = details?.branchId.toString() ??
          raw?['BranchID']?.toString() ??
          raw?['BranchId']?.toString() ??
          itemData?['branchId']?.toString() ??
          "1";
      final leaveId = details?.leaveId.toString() ??
          raw?['LeaveID']?.toString() ??
          raw?['LeaveId']?.toString() ??
          itemData?['leaveId']?.toString() ??
          "1";
      final empId = details?.empId.toString() ??
          raw?['EmpID']?.toString() ??
          raw?['EmpId']?.toString() ??
          raw?['EmployeeID']?.toString() ??
          itemData?['empId']?.toString() ??
          "26";
      final leaveType = details?.leaveType.toString() ??
          raw?['LeaveType']?.toString() ??
          itemData?['leaveType']?.toString() ??
          "1";
      final noOfLeaves = details?.noOfLeaves.toString() ??
          raw?['NoOfLeaves']?.toString() ??
          raw?['Days']?.toString() ??
          "1";
      final reason = remarks ??
          details?.reason ??
          raw?['Reason']?.toString() ??
          itemData?['reason']?.toString() ??
          (approvalStatus == 'A'
              ? "Approved via Mobile App"
              : "Rejected via Mobile App");

      final fromDate = details?.fromDate ??
          raw?['FromDate']?.toString() ??
          itemData?['fromDate']?.toString() ??
          '2026-08-01';
      final toDate = details?.toDate ??
          raw?['ToDate']?.toString() ??
          itemData?['toDate']?.toString() ??
          '2026-08-01';

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
          "ApprovalStatus": approvalStatus, // "A" or "R"
          "Reason": reason,
          "addBy": userId.toString(),
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

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// POST /api/HRM/LeaveCancellation/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  Future<bool> saveLeaveCancellation({
    required String lvApplicationId,
    required String remarks,
    String approvalStatus = "N", // "N" for Request, "A" for Manager Approval, "R" for Manager Reject
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'hrmdemo';
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 12;

      final url = AppUrls.getSaveLeaveCancellationUrl(
        id: 0,
        userId: userId,
        accessPoint: accessPoint,
      );

      final payload = {
        "Head": {
          "Remarks": remarks,
          "LvApplicationID": lvApplicationId,
          "ApprovalStatus": approvalStatus,
          "BranchID": "1",
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

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// GET /api/HRM/General/v1/DashBoard/{accessPoint}/{timeStamp}?MonthCode={date}&Type=A
  /// Returns Table4 containing Leaves (For The Month) matching web portal
  Future<List<Map<String, dynamic>>> fetchDashboardLeaves({String? date}) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint() ?? 'HRMDemo';
      final url = AppUrls.getGeneralDashboardUrl(
        accessPoint: accessPoint,
        monthCode: date,
        type: 'A',
      );

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value'] is Map) {
          final table4 = data['value']['Table4'];
          if (table4 != null && table4 is List) {
            return table4.map((e) => Map<String, dynamic>.from(e as Map)).toList();
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
      final accessPoint =
          await LocalStorageService.getAccessPoint() ?? 'HRMDEMO';
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
          return (data['value'] as List)
              .map((e) => LeaveApplicationModel.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// POST /api/HRM/LeaveApplication/v1/Approve_Or_Forward/{timeStamp}/{accessPoint}
  /// ApprovalStatus: "A" (Approve), "F" (Forward), "R" (Reject)
  Future<bool> approveOrForwardLeave({
    required int key,
    required String approvalStatus,
    Map<String, dynamic>? itemData,
  }) async {
    try {
      final accessPoint =
          await LocalStorageService.getAccessPoint() ?? 'HRMDEMO';
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      final url = AppUrls.getLeaveApproveOrForwardUrl(accessPoint: accessPoint);

      final payload = {
        "Head": {
          "ApprovalStatus": approvalStatus,
          "UserID": userId.toString(),
          "Key": key.toString(),
        }
      };

      try {
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

        if (response.statusCode == 200) {
          return true;
        }
      } catch (inner) {
        // Fallback to Save endpoint if backend stored procedure for Approve_Or_Forward has SQL JSON formatting issue
        return await updateLeaveApprovalStatus(
          key: key,
          approvalStatus: approvalStatus,
          itemData: itemData,
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
