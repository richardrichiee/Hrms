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

  static const String keyCompanyImageUrl = 'key_company_image_url';

  static Future<void> saveCompanyImageUrl(String imageUrl) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(keyCompanyImageUrl, imageUrl);
      await _storage.write(key: keyCompanyImageUrl, value: imageUrl);
    } catch (_) {}
  }

  static Future<String?> getCompanyImageUrl() async {
    try {
      final prefs = await _getPrefs();
      final val = prefs.getString(keyCompanyImageUrl);
      if (val != null && val.isNotEmpty) return val;
      return await _storage.read(key: keyCompanyImageUrl);
    } catch (_) {
      return null;
    }
  }

  static const String keyBranchStartTime = 'key_branch_start_time';
  static const String keyBranchEndTime = 'key_branch_end_time';
  static const String keySessionPassword = 'key_session_password';
  static const String keyPendingLeaveCancellationKeys = 'key_pending_leave_cancellation_keys';

  static Future<void> saveUser(UserModel user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      final prefs = await _getPrefs();
      await prefs.setString(keyUserData, userJson);
      await prefs.setBool(keyIsLoggedIn, true);
      await prefs.setString(keyBranchStartTime, user.branchStartTime);
      await prefs.setString(keyBranchEndTime, user.branchEndTime);
      if (user.branchId > 0) {
        await prefs.setInt(keyUserDefaultBranchId, user.branchId);
        await _storage.write(
          key: keyUserDefaultBranchId,
          value: user.branchId.toString(),
        );
      }
      if (user.branchName.isNotEmpty) {
        await prefs.setString(keyUserDefaultBranchName, user.branchName);
        await _storage.write(
          key: keyUserDefaultBranchName,
          value: user.branchName,
        );
      }
      await _storage.write(key: keyUserData, value: userJson);
      await _storage.write(key: keyIsLoggedIn, value: 'true');
      await _storage.write(key: keyBranchStartTime, value: user.branchStartTime);
      await _storage.write(key: keyBranchEndTime, value: user.branchEndTime);
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

  static const String keyOnlinePunchAnywhere = 'key_online_punch_anywhere';

  static Future<void> saveOnlinePunchAnywhere(int value) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setInt(keyOnlinePunchAnywhere, value);
      await _storage.write(key: keyOnlinePunchAnywhere, value: value.toString());
    } catch (_) {}
  }

  static Future<int> getOnlinePunchAnywhere() async {
    try {
      final prefs = await _getPrefs();
      if (prefs.containsKey(keyOnlinePunchAnywhere)) {
        return prefs.getInt(keyOnlinePunchAnywhere) ?? 0;
      }
      final str = await _storage.read(key: keyOnlinePunchAnywhere);
      if (str != null && str.isNotEmpty) {
        return int.tryParse(str) ?? 0;
      }
      final user = await getUser();
      return user?.onlinePunchAnywhere ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> canPunchAnywhere() async {
    final flag = await getOnlinePunchAnywhere();
    return flag == 1;
  }

  static Future<void> clearUserSession() async {
    try {
      _biometricVerified = false;
      final prefs = await _getPrefs();
      await prefs.remove(keyUserData);
      await prefs.setBool(keyIsLoggedIn, false);
      await prefs.remove(keyOnlinePunchAnywhere);
      await prefs.remove(keyLastLoginTimestamp);
      await prefs.remove(keyTodayPunchHistory);
      await prefs.remove(keyTodayPunchDate);
      await prefs.remove(keyLastPunchDate);
      await prefs.remove(keyLastPunchStatus);
      await prefs.remove(keyLastPunchTime);
      await prefs.remove(keyCachedBranches);
      await prefs.remove(keySelectedBranchId);
      await prefs.remove(keyUserDefaultBranchId);
      await prefs.remove(keyUserDefaultBranchName);
      await prefs.remove(keyBranchStartTime);
      await prefs.remove(keyBranchEndTime);
      await prefs.remove(keySessionPassword);
      await prefs.remove(keyPendingLeaveCancellationKeys);
      await _storage.delete(key: keyUserData);
      await _storage.delete(key: keyIsLoggedIn);
      await _storage.delete(key: keyOnlinePunchAnywhere);
      await _storage.delete(key: keyBranchStartTime);
      await _storage.delete(key: keyBranchEndTime);
      await _storage.delete(key: keyUserDefaultBranchId);
      await _storage.delete(key: keyUserDefaultBranchName);
      await _storage.delete(key: keySessionPassword);
    } catch (_) {}
  }

  // =========================================================================
  // Biometric Credentials, Flags & Daily Re-Authentication
  // =========================================================================
  static const String keyBiometricLoginId = 'key_biometric_login_id';
  static const String keyBiometricPassword = 'key_biometric_password';
  static const String keyBiometricEnabled = 'key_biometric_enabled';
  static const String keyBiometricOnlyMode = 'key_biometric_only_mode';
  static const String keyLastLoginTimestamp = 'key_last_login_timestamp';

  /// In-memory session flag: resets to false on fresh app launch or sign-out.
  static bool _biometricVerified = false;

  static Future<void> saveBiometricCredentials({
    required String loginId,
    required String password,
  }) async {
    try {
      await _storage.write(key: keyBiometricLoginId, value: loginId);
      await _storage.write(key: keyBiometricPassword, value: password);
    } catch (_) {}
  }

  static Future<({String loginId, String password})?>
      getBiometricCredentials() async {
    try {
      final loginId = await _storage.read(key: keyBiometricLoginId);
      final password = await _storage.read(key: keyBiometricPassword);
      if (loginId != null &&
          loginId.trim().isNotEmpty &&
          password != null &&
          password.isNotEmpty) {
        return (loginId: loginId.trim(), password: password);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> clearBiometricCredentials() async {
    try {
      _biometricVerified = false;
      await setBiometricEnabled(false);
    } catch (_) {}
  }

  static Future<void> updateBiometricPasswordIfEnabled(
    String newPassword,
  ) async {
    try {
      final enabled = await isBiometricEnabled();
      final onlyMode = await isBiometricOnlyMode();
      final existing = await getBiometricCredentials();
      if ((enabled || onlyMode) && existing != null) {
        await saveBiometricCredentials(
          loginId: existing.loginId,
          password: newPassword,
        );
      }
    } catch (_) {}
  }

  static Future<void> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(keyBiometricEnabled, enabled);
      await _storage.write(
        key: keyBiometricEnabled,
        value: enabled ? 'true' : 'false',
      );
      if (!enabled) {
        await setBiometricOnlyMode(false);
        await _storage.delete(key: keyBiometricLoginId);
        await _storage.delete(key: keyBiometricPassword);
      }
    } catch (_) {}
  }

  static Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await _getPrefs();
      if (prefs.containsKey(keyBiometricEnabled)) {
        return prefs.getBool(keyBiometricEnabled) ?? false;
      }
      final val = await _storage.read(key: keyBiometricEnabled);
      return val == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> activateBiometricLockAfterVerification() async {
    try {
      final creds = await getBiometricCredentials();
      if (creds == null) return;
      await setBiometricEnabled(true);
      await setBiometricOnlyMode(true);
    } catch (_) {}
  }

  static Future<void> setBiometricOnlyMode(bool enabled) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setBool(keyBiometricOnlyMode, enabled);
    } catch (_) {}
  }

  static Future<bool> isBiometricOnlyMode() async {
    try {
      final prefs = await _getPrefs();
      return prefs.getBool(keyBiometricOnlyMode) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setBiometricVerified(bool verified) async {
    _biometricVerified = verified;
  }

  static Future<bool> isBiometricVerified() async {
    return _biometricVerified;
  }

  static Future<void> saveLoginTimestamp({DateTime? timestamp}) async {
    try {
      final prefs = await _getPrefs();
      final ts = (timestamp ?? DateTime.now()).toIso8601String();
      await prefs.setString(keyLastLoginTimestamp, ts);
    } catch (_) {}
  }

  static Future<bool> isSessionExpiredForNewDay() async {
    try {
      final prefs = await _getPrefs();
      final tsStr = prefs.getString(keyLastLoginTimestamp);
      if (tsStr == null || tsStr.isEmpty) {
        return true;
      }
      final lastLogin = DateTime.tryParse(tsStr);
      if (lastLogin == null) {
        return true;
      }
      final now = DateTime.now();
      return lastLogin.year != now.year ||
          lastLogin.month != now.month ||
          lastLogin.day != now.day;
    } catch (_) {
      return false;
    }
  }

  static Future<void> invalidateSessionForNewDay() async {
    await clearUserSession();
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

  static Future<void> clearPunchCache({int? userId}) async {
    try {
      final prefs = await _getPrefs();
      final suffix = await _userSuffix(userId);
      await prefs.remove('${keyTodayPunchHistory}_$suffix');
      await prefs.remove('${keyTodayPunchDate}_$suffix');
      await prefs.remove('${keyLastPunchDate}_$suffix');
      await prefs.remove('${keyLastPunchStatus}_$suffix');
      await prefs.remove('${keyLastPunchTime}_$suffix');
      await prefs.remove(keyTodayPunchHistory);
      await prefs.remove(keyTodayPunchDate);
      await prefs.remove(keyLastPunchDate);
      await prefs.remove(keyLastPunchStatus);
      await prefs.remove(keyLastPunchTime);
    } catch (_) {}
  }

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
        'TimeFlag': status.toUpperCase() == 'IN' ? 0 : 1,
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
              timeFlag: status.toUpperCase() == 'IN' ? 0 : 1,
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

  static const String keyUserDefaultBranchId = 'key_user_default_branch_id';

  static Future<void> saveUserDefaultBranchId(int branchId) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setInt(keyUserDefaultBranchId, branchId);
      await _storage.write(
        key: keyUserDefaultBranchId,
        value: branchId.toString(),
      );
    } catch (_) {}
  }

  static Future<int?> getUserDefaultBranchId() async {
    try {
      final prefs = await _getPrefs();
      final cached = prefs.getInt(keyUserDefaultBranchId);
      if (cached != null && cached > 0) return cached;
      final secVal = await _storage.read(key: keyUserDefaultBranchId);
      if (secVal != null && secVal.isNotEmpty) {
        final parsed = int.tryParse(secVal);
        if (parsed != null && parsed > 0) return parsed;
      }
      final user = await getUser();
      if (user != null && user.branchId > 0) {
        return user.branchId;
      }
    } catch (_) {}
    return null;
  }

  /// Returns the employee's dedicated home/default branch ID (from login/profile).
  static Future<int> getEffectiveUserBranchId() async {
    try {
      final defaultBranchId = await getUserDefaultBranchId();
      if (defaultBranchId != null && defaultBranchId > 0) {
        return defaultBranchId;
      }
      final selectedBranchId = await getSelectedBranchId();
      if (selectedBranchId != null && selectedBranchId > 0) {
        return selectedBranchId;
      }
    } catch (_) {}
    return 1;
  }

  static const String keyUserDefaultBranchName = 'key_user_default_branch_name';

  static Future<void> saveUserDefaultBranchName(String branchName) async {
    try {
      final prefs = await _getPrefs();
      await prefs.setString(keyUserDefaultBranchName, branchName);
      await _storage.write(key: keyUserDefaultBranchName, value: branchName);
    } catch (_) {}
  }

  static Future<String?> getUserDefaultBranchName() async {
    try {
      final prefs = await _getPrefs();
      final cached = prefs.getString(keyUserDefaultBranchName);
      if (cached != null && cached.isNotEmpty) return cached;
      final secVal = await _storage.read(key: keyUserDefaultBranchName);
      if (secVal != null && secVal.isNotEmpty) return secVal;
      final user = await getUser();
      if (user != null && user.branchName.isNotEmpty) {
        return user.branchName;
      }
    } catch (_) {}
    return null;
  }

  /// Returns the employee's dedicated home/default branch Name (from login/profile).
  static Future<String> getEffectiveUserBranchName() async {
    try {
      final defaultName = await getUserDefaultBranchName();
      if (defaultName != null && defaultName.isNotEmpty) {
        return defaultName;
      }
      final defaultId = await getUserDefaultBranchId();
      final branches = await getBranches();
      if (defaultId != null && defaultId > 0 && branches.isNotEmpty) {
        for (final b in branches) {
          if (b.value == defaultId && b.name.isNotEmpty) {
            return b.name;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  static Future<void> saveSessionPassword(String password) async {
    try {
      await _storage.write(key: keySessionPassword, value: password);
    } catch (_) {}
  }

  static Future<String?> getSessionPassword() async {
    try {
      return await _storage.read(key: keySessionPassword);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getBranchStartTime() async {
    try {
      final prefs = await _getPrefs();
      final v = prefs.getString(keyBranchStartTime);
      if (v != null && v.isNotEmpty) return v;
      return await _storage.read(key: keyBranchStartTime);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> getBranchEndTime() async {
    try {
      final prefs = await _getPrefs();
      final v = prefs.getString(keyBranchEndTime);
      if (v != null && v.isNotEmpty) return v;
      return await _storage.read(key: keyBranchEndTime);
    } catch (_) {
      return null;
    }
  }

  static Future<Set<int>> getPendingLeaveCancellationKeys() async {
    try {
      final prefs = await _getPrefs();
      final list = prefs.getStringList(keyPendingLeaveCancellationKeys);
      if (list != null) {
        return list.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
      }
    } catch (_) {}
    return {};
  }

  static Future<void> addPendingLeaveCancellationKey(int key) async {
    if (key <= 0) return;
    try {
      final prefs = await _getPrefs();
      final current = await getPendingLeaveCancellationKeys();
      current.add(key);
      await prefs.setStringList(
        keyPendingLeaveCancellationKeys,
        current.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  static Future<void> removePendingLeaveCancellationKey(int key) async {
    if (key <= 0) return;
    try {
      final prefs = await _getPrefs();
      final current = await getPendingLeaveCancellationKeys();
      current.remove(key);
      await prefs.setStringList(
        keyPendingLeaveCancellationKeys,
        current.map((e) => e.toString()).toList(),
      );
    } catch (_) {}
  }

  static Future<void> clearAll() async {
    try {
      final prefs = await _getPrefs();
      await prefs.clear();
      await _storage.deleteAll();
    } catch (_) {}
  }
}
