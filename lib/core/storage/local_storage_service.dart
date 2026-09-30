import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/data/models/user_model.dart';
import '../../features/dashboard/data/models/branch_model.dart';
import '../../features/attendance/data/models/last_attendance_model.dart';

class LocalStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  static const String keyAccessPoint = 'key_access_point';
  static const String keyAccessId = 'key_access_id';
  static const String keyUserData = 'key_user_data';
  static const String keyIsLoggedIn = 'key_is_logged_in';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
  }

  static Future<void> saveAccessPoint(String accessPoint) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(keyAccessPoint, accessPoint);
      await _storage.write(key: keyAccessPoint, value: accessPoint);
    } catch (_) {}
  }

  static Future<String?> getAccessPoint() async {
    try {
      final prefs = await _getPrefs();
      final val = prefs.getString(keyAccessPoint);
      if (val != null && val.isNotEmpty) return val;
      return await _storage.read(key: keyAccessPoint);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAccessId(String accessId) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(keyAccessId, accessId);
      await _storage.write(key: keyAccessId, value: accessId);
    } catch (_) {}
  }

  static Future<String?> getAccessId() async {
    try {
      final prefs = await _getPrefs();
      final val = prefs.getString(keyAccessId);
      if (val != null && val.isNotEmpty) return val;
      return await _storage.read(key: keyAccessId);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveUser(UserModel user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      final prefs = await _getPrefs();
      await prefs.setString(keyUserData, userJson);
      await prefs.setBool(keyIsLoggedIn, true);
      await _storage.write(key: keyUserData, value: userJson);
      await _storage.write(key: keyIsLoggedIn, value: 'true');
    } catch (_) {}
  }

  static Future<UserModel?> getUser() async {
    try {
      final prefs = await _getPrefs();
      var userJson = prefs.getString(keyUserData);
      if (userJson == null || userJson.isEmpty) {
        userJson = await _storage.read(key: keyUserData);
      }
      if (userJson != null && userJson.isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(userJson);
        return UserModel.fromJson(map);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> isLoggedIn() async {
    try {
      final prefs = await _getPrefs();
      if (prefs.containsKey(keyIsLoggedIn)) {
        return prefs.getBool(keyIsLoggedIn) ?? false;
      }
      final val = await _storage.read(key: keyIsLoggedIn);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> clearUserSession() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(keyUserData);
      await prefs.setBool(keyIsLoggedIn, false);
      await prefs.remove(keyTodayPunchHistory);
      await prefs.remove(keyTodayPunchDate);
      await prefs.remove(keyLastPunchDate);
      await prefs.remove(keyLastPunchStatus);
      await prefs.remove(keyLastPunchTime);
      await _storage.delete(key: keyUserData);
      await _storage.delete(key: keyIsLoggedIn);
    } catch (_) {}
  }

  static Future<String> _userSuffix([int? userId]) async {
    final uid = userId ?? (await getUser())?.userId ?? 0;
    return uid.toString();
  }

  static const String keyLastPunchDate = 'key_last_punch_date';
  static const String keyLastPunchStatus = 'key_last_punch_status';
  static const String keyLastPunchTime = 'key_last_punch_time';
  static const String keyTodayPunchHistory = 'key_today_punch_history';
  static const String keyTodayPunchDate = 'key_today_punch_date';

  static Future<void> saveLastPunch({
    required String status,
    required String time,
    int? userId,
  }) async {
    try {
      final prefs = await _getPrefs();
      final suffix = await _userSuffix(userId);
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      await prefs.setString('${keyLastPunchDate}_$suffix', todayStr);
      await prefs.setString('${keyLastPunchStatus}_$suffix', status);
      await prefs.setString('${keyLastPunchTime}_$suffix', time);
    } catch (_) {}
  }

  static Future<Map<String, String>?> getLastPunch({int? userId}) async {
    try {
      final prefs = await _getPrefs();
      final suffix = await _userSuffix(userId);
      final punchDate = prefs.getString('${keyLastPunchDate}_$suffix');
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      if (punchDate == todayStr) {
        final status = prefs.getString('${keyLastPunchStatus}_$suffix');
        final time = prefs.getString('${keyLastPunchTime}_$suffix');
        if (status != null && time != null) {
          return {
            'status': status,
            'time': time,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> addTodayPunch({
    required String status,
    required String time,
    String? reason,
    int? userId,
  }) async {
    try {
      final prefs = await _getPrefs();
      final suffix = await _userSuffix(userId);
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final storedDate = prefs.getString('${keyTodayPunchDate}_$suffix');

      List<Map<String, dynamic>> punchList = [];
      if (storedDate == todayStr) {
        final existingJson = prefs.getString('${keyTodayPunchHistory}_$suffix');
        if (existingJson != null && existingJson.isNotEmpty) {
          try {
            final List decoded = jsonDecode(existingJson);
            punchList = decoded
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } catch (_) {}
        }
      }

      final newPunch = {
        'InOutTime': time,
        'TimeFlag': status.toUpperCase() == 'IN' ? 1 : 0,
        'Reason': reason ??
            (status.toUpperCase() == 'IN'
                ? 'Mobile Check In'
                : 'Mobile Check Out'),
      };

      // Insert at the front so the latest punch is always first (index 0)
      punchList.insert(0, newPunch);

      await prefs.setString('${keyTodayPunchDate}_$suffix', todayStr);
      await prefs.setString(
          '${keyTodayPunchHistory}_$suffix', jsonEncode(punchList));

      // Also synchronize keyLastPunch for backwards compatibility
      await prefs.setString('${keyLastPunchDate}_$suffix', todayStr);
      await prefs.setString('${keyLastPunchStatus}_$suffix', status);
      await prefs.setString('${keyLastPunchTime}_$suffix', time);
    } catch (_) {}
  }

  static Future<List<LastAttendanceModel>> getTodayPunchHistory(
      {int? userId}) async {
    try {
      final prefs = await _getPrefs();
      final suffix = await _userSuffix(userId);
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final storedDate = prefs.getString('${keyTodayPunchDate}_$suffix');

      if (storedDate == todayStr) {
        final jsonStr = prefs.getString('${keyTodayPunchHistory}_$suffix');
        if (jsonStr != null && jsonStr.isNotEmpty) {
          final List list = jsonDecode(jsonStr);
          final items = list
              .map((e) => LastAttendanceModel.fromJson(
                  Map<String, dynamic>.from(e as Map)))
              .toList();
          if (items.isNotEmpty) return items;
        }
      }

      // Fallback: If punch list is empty, but getLastPunch() has a punch from today, synthesize it
      final lastPunch = await getLastPunch(userId: userId);
      if (lastPunch != null) {
        final status = lastPunch['status'] ?? 'IN';
        final time = lastPunch['time'] ?? '';
        if (time.isNotEmpty) {
          return [
            LastAttendanceModel(
              inOutTime: time,
              timeFlag: status.toUpperCase() == 'IN' ? 1 : 0,
              reason: status.toUpperCase() == 'IN'
                  ? 'Mobile Check In'
                  : 'Mobile Check Out',
            ),
          ];
        }
      }
    } catch (_) {}
    return [];
  }

  static const String keyCachedBranches = 'key_cached_branches';
  static const String keySelectedBranchId = 'key_selected_branch_id';

  static Future<void> saveBranches(List<BranchModel> branches) async {
    try {
      final prefs = await _getPrefs();
      final listJson = jsonEncode(branches.map((b) => b.toJson()).toList());
      await prefs.setString(keyCachedBranches, listJson);
    } catch (_) {}
  }

  static Future<List<BranchModel>> getBranches() async {
    try {
      final prefs = await _getPrefs();
      final jsonStr = prefs.getString(keyCachedBranches);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List list = jsonDecode(jsonStr);
        return list
            .map((e) => BranchModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> saveSelectedBranchId(int branchId) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setInt(keySelectedBranchId, branchId);
    } catch (_) {}
  }

  static Future<int?> getSelectedBranchId() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getInt(keySelectedBranchId);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      await prefs.clear();
      await _storage.deleteAll();
    } catch (_) {}
  }
}
