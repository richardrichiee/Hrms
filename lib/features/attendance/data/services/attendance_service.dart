import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/app_urls.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../models/attendance_log_model.dart';
import '../models/last_attendance_model.dart';

class AttendanceService {
  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  Future<List<AttendanceLogModel>> fetchMonthlyAttendanceLogs({String? date}) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) return [];
      final user = await LocalStorageService.getUser();
      final employeeId = user?.employeeId ?? 1;

      final url = AppUrls.getEmployeeDashboardUrl(
        accessPoint: accessPoint,
        employeeId: employeeId,
        param: 'D',
        date: date,
      );

      final response = await _dio.get(
        url,
        options: Options(
          headers: {'Accept': 'application/json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null && data['value']['Table'] != null) {
          final tableList = data['value']['Table'] as List;
          return tableList
              .map((item) => AttendanceLogModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// GET /api/HRM/Mobile/v1/GetLastAttendance/{accessPoint}/{timeStamp}/{BranchID}/{EmployeeID}
  Future<LastAttendanceModel?> fetchLastAttendance({
    required int branchId,
    int? employeeId,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) return null;
      final user = await LocalStorageService.getUser();
      final empId = employeeId ?? user?.employeeId ?? 1;

      final url = AppUrls.getLastAttendanceUrl(
        accessPoint: accessPoint,
        branchId: branchId,
        employeeId: empId,
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
          if (list.isNotEmpty) {
            return LastAttendanceModel.fromJson(
              Map<String, dynamic>.from(list[0] as Map),
            );
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// GET /api/HRM/Mobile/v1/GetHistoryAttendance/{accessPoint}/{timeStamp}/{BranchID}/{EmployeeID}
  Future<List<LastAttendanceModel>> fetchHistoryAttendance({
    required int branchId,
    int? employeeId,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) return [];
      final user = await LocalStorageService.getUser();
      final empId = employeeId ?? user?.employeeId ?? 1;

      final url = AppUrls.getHistoryAttendanceUrl(
        accessPoint: accessPoint,
        branchId: branchId,
        employeeId: empId,
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
              .map((item) => LastAttendanceModel.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// POST /api/HRM/Attendance/v1/Save/{id}/{userId}/{timeStamp}/{accessPoint}
  Future<AttendanceSaveResult> saveAttendanceWithResult({
    required int branchId,
    required int employeeId,
    required String inOutTime,
    required int timeFlag, // 0 = Check In, 1 = Check Out
    required String date, // dd/MM/yyyy
    String? reason,
    String? inTime,
    String? outTime,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint == null || accessPoint.isEmpty) {
        return const AttendanceSaveResult(
          success: false,
          errorMessage: 'Company access point not configured.',
        );
      }
      final user = await LocalStorageService.getUser();
      final userId = user?.userId ?? 2;

      final url = AppUrls.getSaveAttendanceUrl(
        accessPoint: accessPoint,
        userId: userId,
      );

      // 1. Strictly sanitize times to 24-hour HH:mm:ss format (never 12-hour AM/PM)
      final sanitizedInOutTime = formatTo24HourTime(inOutTime);
      final sanitizedInTime = formatTo24HourTime(inTime);
      final sanitizedOutTime = formatTo24HourTime(outTime);

      // In Tail: When checking in (timeFlag == 0), OutTime MUST strictly be empty ("") because the employee is checked IN, not OUT!
      // When checking out (timeFlag == 1), OutTime is sanitizedOutTime or sanitizedInOutTime.
      final finalInTime = sanitizedInTime.isNotEmpty
          ? sanitizedInTime
          : (timeFlag == 0 ? sanitizedInOutTime : "");
      final finalOutTime = timeFlag == 1
          ? (sanitizedOutTime.isNotEmpty ? sanitizedOutTime : sanitizedInOutTime)
          : "";

      final payload = {
        "Head": {
          "BranchID": branchId.toString(),
          "Date": date,
        },
        "Tail": [
          {
            "EmployeeID": employeeId.toString(),
            "InTime": finalInTime,
            "OutTime": finalOutTime,
          }
        ],
        "Tail2": [
          {
            "EmployeeID": employeeId.toString(),
            "InOutTime": sanitizedInOutTime,
            "Reason": reason ??
                (timeFlag == 0 ? "Mobile Check In" : "Mobile Check Out"),
            "TimeFlag": timeFlag.toString(),
            "Latitude": latitude?.toString(),
            "Longitude": longitude?.toString(),
          }
        ]
      };

      print('----------------------------------------------------------------------');
      print('📡 [CHECK IN API CALL -> POST /api/HRM/Attendance/v1/Save]');
      print('🌐 URL    : $url');
      print('🏢 Branch : $branchId | Emp: $employeeId | User: $userId');
      print('📍 Latitude sent in Tail2 : ${latitude?.toString()}');
      print('📍 Longitude sent in Tail2: ${longitude?.toString()}');
      print('📦 Full JSON Payload:');
      print(jsonEncode(payload));
      print('----------------------------------------------------------------------');

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

      print('📥 [CHECK IN API RESPONSE]');
      print('HTTP Status: ${response.statusCode}');
      print('Response Body: ${response.data}');
      print('----------------------------------------------------------------------');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;
        if (data['value'] != null &&
            data['value'] is List &&
            (data['value'] as List).isNotEmpty) {
          final first = (data['value'] as List).first;
          final errorMsg = first['ERRORMESSAGE']?.toString() ?? '';
          if (errorMsg.isEmpty) {
            debugPrint('✅ [AttendanceService] Punch successfully recorded on server!');
            return AttendanceSaveResult(
              success: true,
              statusCode: response.statusCode,
              data: data,
            );
          } else {
            debugPrint('⚠️ [AttendanceService] Server returned ERRORMESSAGE: $errorMsg');
            return AttendanceSaveResult(
              success: false,
              errorMessage: errorMsg,
              statusCode: response.statusCode,
              data: data,
            );
          }
        } else {
          debugPrint('⚠️ [AttendanceService] Unexpected value format in response: ${data['value']}');
          return AttendanceSaveResult(
            success: false,
            errorMessage: 'Unexpected server response structure: ${data['value']}',
            statusCode: response.statusCode,
            data: data,
          );
        }
      }

      debugPrint('❌ [AttendanceService] HTTP Error: Status ${response.statusCode}');
      return AttendanceSaveResult(
        success: false,
        errorMessage: 'Server returned HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    } on DioException catch (dioErr) {
      debugPrint('❌❌❌ [AttendanceService DIO EXCEPTION]:');
      debugPrint('[AttendanceService] Message: ${dioErr.message}');
      debugPrint('[AttendanceService] Type: ${dioErr.type}');
      debugPrint('[AttendanceService] Endpoint: ${dioErr.requestOptions.uri}');
      debugPrint('[AttendanceService] Response Status: ${dioErr.response?.statusCode}');
      debugPrint('[AttendanceService] Response Body: ${dioErr.response?.data}');

      // Auto-fallback: if SQL Server fails to parse dd/MM/yyyy date format, retry with ISO yyyy-MM-dd
      final responseBody = dioErr.response?.data?.toString() ?? '';
      if (dioErr.response?.statusCode == 500 &&
          responseBody.contains('Conversion failed') &&
          date.contains('/')) {
        final parts = date.split('/');
        if (parts.length == 3) {
          final isoDate = '${parts[2]}-${parts[1].padLeft(2, '0')}-${parts[0].padLeft(2, '0')}';
          debugPrint('🔄 [AttendanceService] Retrying with ISO date ($isoDate)...');
          try {
            final retryPayload = {
              "Head": {
                "BranchID": branchId.toString(),
                "Date": isoDate,
              },
              "Tail": [
                {
                  "EmployeeID": employeeId.toString(),
                  "InTime": formatTo24HourTime(inTime).isNotEmpty
                      ? formatTo24HourTime(inTime)
                      : (timeFlag == 0 ? formatTo24HourTime(inOutTime) : ""),
                  "OutTime": timeFlag == 1
                      ? (formatTo24HourTime(outTime).isNotEmpty
                          ? formatTo24HourTime(outTime)
                          : formatTo24HourTime(inOutTime))
                      : "",
                }
              ],
              "Tail2": [
                {
                  "EmployeeID": employeeId.toString(),
                  "InOutTime": formatTo24HourTime(inOutTime),
                  "Reason": reason ??
                      (timeFlag == 0 ? "Mobile Check In" : "Mobile Check Out"),
                  "TimeFlag": timeFlag.toString(),
                  "Latitude": latitude?.toString(),
                  "Longitude": longitude?.toString(),
                }
              ]
            };

            final retryResponse = await _dio.post(
              dioErr.requestOptions.uri.toString(),
              data: retryPayload,
              options: Options(
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            );

            debugPrint('📥 [AttendanceService] Retry Response: ${retryResponse.statusCode} - ${retryResponse.data}');
            if (retryResponse.statusCode == 200 && retryResponse.data != null) {
              final data = retryResponse.data;
              if (data['value'] != null &&
                  data['value'] is List &&
                  (data['value'] as List).isNotEmpty) {
                final first = (data['value'] as List).first;
                final errorMsg = first['ERRORMESSAGE']?.toString() ?? '';
                if (errorMsg.isEmpty) {
                  return AttendanceSaveResult(
                    success: true,
                    statusCode: retryResponse.statusCode,
                    data: data,
                  );
                }
              }
            }
          } catch (retryErr) {
            debugPrint('[AttendanceService] Retry also failed: $retryErr');
          }
        }
      }

      final cleanMsg = _extractCleanErrorMessage(dioErr.response?.data ?? dioErr.message);
      return AttendanceSaveResult(
        success: false,
        errorMessage: cleanMsg,
        statusCode: dioErr.response?.statusCode,
      );
    } catch (e, stack) {
      debugPrint('❌❌❌ [AttendanceService UNEXPECTED EXCEPTION]: $e');
      debugPrint('[AttendanceService] Stack: $stack');
      return AttendanceSaveResult(
        success: false,
        errorMessage: _extractCleanErrorMessage(e),
      );
    }
  }

  static String _extractCleanErrorMessage(dynamic raw) {
    if (raw == null) return 'Server connection error';
    if (raw is Map) {
      if (raw['error'] != null && raw['error'] is Map) {
        final m = raw['error']['Message']?.toString();
        if (m != null && m.isNotEmpty) return m;
      }
      if (raw['Message'] != null) {
        return raw['Message'].toString();
      }
    }
    final s = raw.toString();
    final match = RegExp(r'Message:\s*([^,\n}]+)').firstMatch(s);
    if (match != null && match.group(1) != null) {
      return match.group(1)!.trim();
    }
    return s.length > 100 ? '${s.substring(0, 97)}...' : s;
  }

  /// Converts any time string (including 12-hour "2:41 PM") to 24-hour "HH:mm:ss"
  static String formatTo24HourTime(String? timeStr) {
    if (timeStr == null) return '';
    final trimmed = timeStr.trim();
    if (trimmed.isEmpty || trimmed == '--:--' || trimmed == '00:00') return '';

    // If it's already HH:mm:ss or HH:mm
    final match24h = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(trimmed);
    if (match24h != null) {
      final h = int.parse(match24h.group(1)!);
      final m = int.parse(match24h.group(2)!);
      final s = match24h.group(3) != null ? int.parse(match24h.group(3)!) : 0;
      if (h >= 0 && h <= 23 && m >= 0 && m <= 59 && s >= 0 && s <= 59) {
        return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      }
    }

    // If it contains AM or PM (e.g. "2:41 PM", "02:41:00 PM")
    final formats = [
      DateFormat('h:mm a'),
      DateFormat('hh:mm a'),
      DateFormat('h:mm:ss a'),
      DateFormat('hh:mm:ss a'),
      DateFormat('HH:mm:ss'),
      DateFormat('HH:mm'),
    ];
    for (final fmt in formats) {
      try {
        final parsed = fmt.parse(trimmed);
        return '${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}:${parsed.second.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    return trimmed;
  }

  /// Backward-compatible wrapper
  Future<bool> saveAttendance({
    required int branchId,
    required int employeeId,
    required String inOutTime,
    required int timeFlag,
    required String date,
    String? reason,
    String? inTime,
    String? outTime,
    double? latitude,
    double? longitude,
  }) async {
    final res = await saveAttendanceWithResult(
      branchId: branchId,
      employeeId: employeeId,
      inOutTime: inOutTime,
      timeFlag: timeFlag,
      date: date,
      reason: reason,
      inTime: inTime,
      outTime: outTime,
      latitude: latitude,
      longitude: longitude,
    );
    return res.success;
  }
}

class AttendanceSaveResult {
  final bool success;
  final String? errorMessage;
  final int? statusCode;
  final dynamic data;

  const AttendanceSaveResult({
    required this.success,
    this.errorMessage,
    this.statusCode,
    this.data,
  });
}
