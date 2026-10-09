import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../attendance/data/services/attendance_service.dart';
import '../../../attendance/data/models/attendance_log_model.dart';
import '../../../attendance/data/models/last_attendance_model.dart';
import '../../../profile/data/services/employee_service.dart';
import '../../../profile/data/models/employee_details_model.dart';
import '../../data/models/branch_model.dart';
import '../../data/models/financial_year_model.dart';
import '../../data/services/branch_service.dart';
import '../../data/services/financial_year_service.dart';
import '../../data/services/notification_service.dart';
import '../../../leave/data/services/leave_service.dart';
import '../../../auth/data/services/access_point_service.dart';
import '../widgets/attendance_calendar_widget.dart';
import '../widgets/dashboard_metrics.dart';
import '../widgets/leave_balance_chart.dart';
import '../widgets/today_punch_history_sheet.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _branchService = BranchService();
  final _financialYearService = FinancialYearService();
  final _employeeService = EmployeeService();
  final _attendanceService = AttendanceService();
  final _notificationService = NotificationService();

  bool _isCheckedIn = false;
  bool _isLocationChecking = false;
  String _checkInTime = '--:--';
  String _checkOutTime = '';
  String _rawCheckInTime = '';
  String _userName = '';
  String _userDesignation = '';
  String _userAvatarLetter = '';
  String? _companyImageUrl;

  List<BranchModel> _branches = [];
  BranchModel? _selectedBranch;

  List<FinancialYearModel> _financialYears = [];
  FinancialYearModel? _selectedFinancialYear;

  final Map<int, Color> _liveDayStatus = {};
  final Map<int, Map<String, String>> _liveDayDetails = {};
  int _attendanceCount = 0;
  num _leavesCount = 0;
  int _notificationCount = 0;
  List<LeaveSummaryItem> _leaveSummaryItems = [];

  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // 1. Immediately show cached user info, cached branches & selected branch
    final user = await LocalStorageService.getUser();
    final cachedBranches = await LocalStorageService.getBranches();
    final savedBranchId = await LocalStorageService.getSelectedBranchId();
    final cachedCompanyLogo = await LocalStorageService.getCompanyImageUrl();
    await LocalStorageService.clearPunchCache();

    if (mounted) {
      setState(() {
        if (cachedCompanyLogo != null && cachedCompanyLogo.isNotEmpty) {
          _companyImageUrl = cachedCompanyLogo;
        }
        if (user != null && _userName.isEmpty) {
          _userName = user.userName;
          _userAvatarLetter = user.userName.isNotEmpty
              ? user.userName[0].toUpperCase()
              : 'U';
        }
        if (cachedBranches.isNotEmpty && _branches.isEmpty) {
          _branches = cachedBranches;
          if (savedBranchId != null) {
            _selectedBranch = _branches.firstWhere(
              (b) => b.value == savedBranchId,
              orElse: () => _branches.first,
            );
          } else {
            _selectedBranch = _branches.first;
          }
        }
      });
    }

    if (_companyImageUrl == null || _companyImageUrl!.isEmpty) {
      AccessPointService().ensureCompanyImageUrl().then((img) {
        if (mounted && img != null && img.isNotEmpty) {
          setState(() {
            _companyImageUrl = img;
          });
        }
      });
    }

    final leaveService = LeaveService();
    final branchId = _selectedBranch?.id ?? savedBranchId ?? 1;
    final empId = user?.employeeId;

    // 2. Fetch all dashboard data concurrently in parallel using Future.wait
    try {
      final results = await Future.wait([
        _employeeService.fetchEmployeeDashboard(date: formattedDate),
        _notificationService.fetchNotificationCount(),
        leaveService.fetchDashboardLeaves(date: formattedDate),
        _branchService.fetchBranches(),
        _financialYears.isEmpty
            ? _financialYearService.fetchFinancialYears()
            : Future.value(_financialYears),
        _attendanceService.fetchMonthlyAttendanceLogs(date: formattedDate),
        _attendanceService.fetchLastAttendance(
          branchId: branchId,
          employeeId: empId,
        ),
        _attendanceService.fetchHistoryAttendance(
          branchId: branchId,
          employeeId: empId,
        ),
      ]);

      if (!mounted) return;

      final employeeDetails = results[0] as EmployeeDetailsModel?;
      final notifCount = results[1] as int;
      final dashboardLeaves = results[2] as List<dynamic>;
      final branches = results[3] as List<BranchModel>;
      final financialYears = results[4] as List<FinancialYearModel>;
      final attendanceLogs = results[5] as List<AttendanceLogModel>;
      final lastAttendance = results[6] as LastAttendanceModel?;
      final historyAttendance = (results.length > 7 && results[7] is List)
          ? results[7] as List<LastAttendanceModel>
          : <LastAttendanceModel>[];

      final summaryItems = <LeaveSummaryItem>[];
      final defaultColors = [
        const Color(0xFFB06A44),
        const Color(0xFF5B9E94),
        const Color(0xFF1E88E5),
        const Color(0xFFE53935),
        const Color(0xFFFB8C00),
        const Color(0xFF8E24AA),
      ];
      int colorIdx = 0;

      if (employeeDetails != null && employeeDetails.leaveBalances.isNotEmpty) {
        for (final bal in employeeDetails.leaveBalances) {
          final name = bal.leaveName;
          final color = name.toLowerCase().contains('casual')
              ? const Color(0xFFB06A44)
              : name.toLowerCase().contains('sick')
              ? const Color(0xFF5B9E94)
              : defaultColors[colorIdx % defaultColors.length];
          colorIdx++;

          summaryItems.add(
            LeaveSummaryItem(
              leaveName: name,
              totalLeaves: bal.closing,
              employeesTaken: 0,
              balanceLeaves: bal.closing,
              color: color,
            ),
          );
        }
      } else if (dashboardLeaves.isNotEmpty) {
        for (final item in dashboardLeaves) {
          final name = item['LeaveName']?.toString() ?? 'Leave';
          final total =
              (item['EmployeesTakenLeave'] as num?)?.toDouble() ?? 0.0;
          final taken = (item['TotalLeaveDays'] as num?)?.toDouble() ?? 0.0;
          final balance = (total - taken) >= 0 ? (total - taken) : 0.0;

          final color = name.toLowerCase().contains('casual')
              ? const Color(0xFFB06A44)
              : name.toLowerCase().contains('sick')
              ? const Color(0xFF5B9E94)
              : defaultColors[colorIdx % defaultColors.length];
          colorIdx++;

          summaryItems.add(
            LeaveSummaryItem(
              leaveName: name,
              totalLeaves: total,
              employeesTaken: taken,
              balanceLeaves: balance,
              color: color,
            ),
          );
        }
      }

      setState(() {
        _notificationCount = notifCount;
        _leaveSummaryItems = summaryItems;

        if (employeeDetails != null) {
          _userName = employeeDetails.name;
          _userDesignation = employeeDetails.designation;
          _attendanceCount = employeeDetails.attendanceForTheMonth;
          _leavesCount = employeeDetails.noOfLeavesForTheMonth;
        } else if (user != null && _userName.isEmpty) {
          _userName = user.userName;
        }
        _userAvatarLetter = _userName.isNotEmpty
            ? _userName[0].toUpperCase()
            : 'U';

        _branches = branches;
        if (savedBranchId != null && _branches.isNotEmpty) {
          _selectedBranch = _branches.firstWhere(
            (b) => b.value == savedBranchId,
            orElse: () => _branches.first,
          );
        } else if (_selectedBranch == null && _branches.isNotEmpty) {
          _selectedBranch = _branches.first;
        } else if (_selectedBranch != null && _branches.isNotEmpty) {
          _selectedBranch = _branches.firstWhere(
            (b) => b.value == _selectedBranch!.value,
            orElse: () => _selectedBranch!,
          );
        }

        _financialYears = financialYears;
        if (_selectedFinancialYear == null && _financialYears.isNotEmpty) {
          _selectedFinancialYear = _financialYears.first;
        }

        _liveDayStatus.clear();
        _liveDayDetails.clear();
        int pCount = 0;

        if (attendanceLogs.isNotEmpty) {
          final now = DateTime.now();
          final isCurrentMonth =
              _selectedDate.year == now.year &&
              _selectedDate.month == now.month;

          for (final log in attendanceLogs) {
            final day = log.day;
            final pres = log.present.trim().toUpperCase();
            final inT = log.inTime.trim().toUpperCase();

            if (day > 0) {
              _liveDayDetails[day] = {
                'inTime': log.inTime,
                'outTime': log.outTime,
                'present': log.present,
              };
            }

            final isSunday = pres == 'SUN' || inT == 'SUN';
            final isPresent =
                pres == 'X' ||
                pres == 'P' ||
                pres == 'PR' ||
                pres == 'PRESENT' ||
                (!isSunday &&
                    inT != 'AB' &&
                    inT.isNotEmpty &&
                    inT != '--:--' &&
                    inT != '00:00');
            final isAbsent = pres == 'AB' || pres == 'A' || pres == 'ABSENT';

            if (isSunday) {
              continue;
            } else if (isPresent) {
              if (day > 0) _liveDayStatus[day] = Colors.green;
              pCount++;
            } else if (isAbsent) {
              if (day > 0) _liveDayStatus[day] = Colors.red;
            }
          }

          if (isCurrentMonth) {
            final todayDetails = _liveDayDetails[now.day];
            if (todayDetails != null) {
              final todayIn = todayDetails['inTime'];
              final todayOut = todayDetails['outTime'];

              bool isValidTime(String? time) {
                if (time == null) return false;
                final t = time.trim().toUpperCase();
                if (t.isEmpty ||
                    t == 'AB' ||
                    t == 'A' ||
                    t == 'ABSENT' ||
                    t == 'SUN' ||
                    t == 'SL' ||
                    t == 'CL' ||
                    t == 'PL' ||
                    t == 'HL' ||
                    t == 'WO' ||
                    t == 'OFF' ||
                    t == 'HD' ||
                    t == 'L' ||
                    t == '--:--' ||
                    t == '00:00' ||
                    t == '0:00' ||
                    t == 'NULL') {
                  return false;
                }
                // Must contain digits and a time separator (e.g. 09:30 or 9:30AM)
                return RegExp(r'\d{1,2}[:.]\d{2}').hasMatch(t);
              }

              final hasIn = isValidTime(todayIn);
              final hasOut =
                  isValidTime(todayOut) &&
                  (todayOut?.trim() != todayIn?.trim());

              if (hasIn && !hasOut) {
                _isCheckedIn = true;
                _checkInTime = todayIn!.trim();
                _checkOutTime = '';
              } else if (hasIn && hasOut) {
                _isCheckedIn = false;
                _checkInTime = todayIn!.trim();
                _checkOutTime = todayOut!.trim();
              } else {
                _isCheckedIn = false;
              }
            }
          }
        }

        if (employeeDetails != null) {
          _attendanceCount = employeeDetails.attendanceForTheMonth;
          _leavesCount = employeeDetails.noOfLeavesForTheMonth;
        } else {
          _attendanceCount = pCount;
        }

        // Apply first check-in and last check-out from today's history
        _applyAttendanceFromHistory(historyAttendance, lastAttendance);
      });
    } catch (_) {}
  }

  void _applyAttendanceFromHistory(
    List<LastAttendanceModel> history,
    LastAttendanceModel? lastAttendance,
  ) {
    if (history.isNotEmpty) {
      final inPunches = history.where((p) => p.timeFlag == 0).toList();
      final outPunches = history.where((p) => p.timeFlag == 1).toList();

      // Current checked-in status is determined by the most recent punch overall
      final sortedAll = List<LastAttendanceModel>.from(history)
        ..sort(
          (a, b) => _parseTimeToSeconds(
            b.inOutTime,
          ).compareTo(_parseTimeToSeconds(a.inOutTime)),
        );
      final latestPunch = sortedAll.first;
      _isCheckedIn = latestPunch.isCheckedIn;

      // First check-in = earliest in-punch of today
      if (inPunches.isNotEmpty) {
        inPunches.sort(
          (a, b) => _parseTimeToSeconds(
            a.inOutTime,
          ).compareTo(_parseTimeToSeconds(b.inOutTime)),
        );
        _checkInTime = inPunches.first.formattedTime;
        _rawCheckInTime = inPunches.first.inOutTime;
      }

      // Last check-out = latest out-punch of today
      if (outPunches.isNotEmpty) {
        outPunches.sort(
          (a, b) => _parseTimeToSeconds(
            b.inOutTime,
          ).compareTo(_parseTimeToSeconds(a.inOutTime)),
        );
        _checkOutTime = outPunches.first.formattedTime;
      } else {
        _checkOutTime = '';
      }

      final now = DateTime.now();
      final isCurrentMonth =
          _selectedDate.year == now.year && _selectedDate.month == now.month;
      if (isCurrentMonth) {
        final currentDetails = _liveDayDetails[now.day] ?? {};
        _liveDayDetails[now.day] = {
          'inTime': _checkInTime,
          'outTime': _checkOutTime.isNotEmpty
              ? _checkOutTime
              : (currentDetails['outTime'] ?? '--:--'),
          'present': currentDetails['present'] ?? 'P',
        };
        _liveDayStatus[now.day] = Colors.green;
      }
    } else if (lastAttendance != null && lastAttendance.inOutTime.isNotEmpty) {
      _isCheckedIn = lastAttendance.isCheckedIn;
      if (lastAttendance.isCheckedIn) {
        _checkInTime = lastAttendance.formattedTime;
        _rawCheckInTime = lastAttendance.inOutTime;
      } else {
        _checkOutTime = lastAttendance.formattedTime;
      }
    }
  }

  Future<void> _fetchAndApplyLastAttendance() async {
    final currentBranch = _selectedBranch;
    if (currentBranch == null) return;
    try {
      final user = await LocalStorageService.getUser();
      final results = await Future.wait([
        _attendanceService.fetchLastAttendance(
          branchId: currentBranch.id,
          employeeId: user?.employeeId,
        ),
        _attendanceService.fetchHistoryAttendance(
          branchId: currentBranch.id,
          employeeId: user?.employeeId,
        ),
      ]);
      if (!mounted) return;
      final last = results[0] as LastAttendanceModel?;
      final history = (results[1] is List)
          ? results[1] as List<LastAttendanceModel>
          : <LastAttendanceModel>[];

      setState(() {
        _applyAttendanceFromHistory(history, last);
      });
    } catch (_) {}
  }

  Future<void> _showTodayPunchHistory() async {
    final currentBranch = _selectedBranch;
    if (currentBranch == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FutureBuilder<List<LastAttendanceModel>>(
          future: () async {
            final user = await LocalStorageService.getUser();
            final serverHistory = await _attendanceService
                .fetchHistoryAttendance(
                  branchId: currentBranch.id,
                  employeeId: user?.employeeId,
                );

            serverHistory.sort((a, b) {
              final timeA = _parseTimeToSeconds(a.inOutTime);
              final timeB = _parseTimeToSeconds(b.inOutTime);
              if (timeB != timeA) {
                return timeB.compareTo(
                  timeA,
                ); // Descending (latest punch first)
              }
              return b.timeFlag.compareTo(a.timeFlag);
            });

            // Deduplicate exact duplicate punches (same timestamp & flag)
            // e.g., if a user double-clicks 'Check Out' on the web portal
            final uniqueHistory = <LastAttendanceModel>[];
            for (final punch in serverHistory) {
              final isDuplicate = uniqueHistory.any(
                (existing) =>
                    existing.inOutTime == punch.inOutTime &&
                    existing.timeFlag == punch.timeFlag,
              );
              if (!isDuplicate) {
                uniqueHistory.add(punch);
              }
            }

            return uniqueHistory;
          }(),
          builder: (context, snapshot) {
            final history = snapshot.data ?? [];
            return TodayPunchHistorySheet(
              history: history,
              isLoading: snapshot.connectionState == ConnectionState.waiting,
            );
          },
        );
      },
    );
  }

  static int _parseTimeToSeconds(String timeStr) {
    try {
      final clean = timeStr.trim().toUpperCase();
      final isPM = clean.contains('PM');
      final isAM = clean.contains('AM');
      final timeOnly = clean.replaceAll(RegExp(r'[^\d:]'), '');
      final parts = timeOnly.split(':');
      if (parts.isNotEmpty) {
        int hours = int.tryParse(parts[0]) ?? 0;
        int minutes = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
        int seconds = parts.length > 2 ? (int.tryParse(parts[2]) ?? 0) : 0;
        if (isPM && hours < 12) hours += 12;
        if (isAM && hours == 12) hours = 0;
        return hours * 3600 + minutes * 60 + seconds;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _selectDashboardDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
      await _loadInitialData();
    }
  }

  Future<void> _toggleCheckIn() async {
    if (_isLocationChecking) return;

    // Refresh branch data from local storage to ensure fresh coordinates
    final savedBranchId =
        await LocalStorageService.getSelectedBranchId() ??
        _selectedBranch?.value ??
        1;
    final cachedBranches = await LocalStorageService.getBranches();
    BranchModel? branch;
    try {
      branch = cachedBranches.firstWhere((b) => b.value == savedBranchId);
    } catch (_) {
      branch = _selectedBranch;
    }

    if (branch != null) {
      _selectedBranch = branch;
    }

    if (branch == null ||
        branch.latitude == null ||
        branch.longitude == null ||
        branch.latitude == 0.0 ||
        branch.longitude == 0.0 ||
        branch.radius == null) {
      _showLocationDialog(
        title: 'Location Not Configured',
        message:
            'Branch GPS coordinates (Latitude & Longitude) are not configured for ${branch?.name ?? "this branch"}.\n\nPlease configure the office coordinates in Settings > Configure Branch Location or contact your administrator.',
        icon: Icons.location_off_rounded,
        iconColor: AppColors.error,
      );
      return;
    }

    setState(() => _isLocationChecking = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showLocationDialog(
          title: 'Location Services Disabled',
          message:
              'Please enable GPS/Location services on your device to verify branch attendance.',
          icon: Icons.location_disabled_rounded,
          iconColor: Colors.orange,
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          _showLocationDialog(
            title: 'Permission Denied',
            message:
                'Location permission is required to verify your branch attendance.',
            icon: Icons.security_rounded,
            iconColor: AppColors.error,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showLocationDialog(
          title: 'Permission Permanently Denied',
          message:
              'Location permissions are permanently denied. Please enable them in your device settings to check in or out.',
          icon: Icons.settings_rounded,
          iconColor: AppColors.error,
        );
        return;
      }

      Position? position;
      try {
        // 1. Allow GPS up to 8s to lock onto satellites during cold app starts
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        // 2. Only use lastKnownPosition if fresh (< 120s old). Never trust stale locations!
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          final age = DateTime.now()
              .difference(lastKnown.timestamp)
              .inSeconds
              .abs();
          if (age < 120) {
            position = lastKnown;
          }
        }

        // 3. If stale or null, retry with low/balanced accuracy for 5 seconds
        if (position == null) {
          try {
            position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low,
                timeLimit: Duration(seconds: 5),
              ),
            );
          } catch (_) {}
        }

        // 4. Last resort fallback
        position ??= lastKnown;
      }

      if (position == null) {
        throw TimeoutException(
          'Unable to acquire current location. Please ensure GPS is enabled and try again.',
        );
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        branch.latitude!,
        branch.longitude!,
      );

      // Account for realistic mobile device indoor GPS accuracy margin (up to 30m)
      final tolerance = position.accuracy.clamp(0.0, 30.0);
      final effectiveDistance = (distance - tolerance) > 0
          ? (distance - tolerance)
          : 0.0;

      if (effectiveDistance > branch.radius!) {
        if (!mounted) return;
        _showLocationDialog(
          title: 'Outside Branch Area',
          message:
              'You are outside the branch area for ${branch.name}. Please ensure you are within your branch premises to check in or out.',
          icon: Icons.wrong_location_rounded,
          iconColor: AppColors.error,
        );
        return;
      }

      if (!mounted) return;
      final now = DateTime.now();
      final timeStr =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      final newFlag = _isCheckedIn ? 1 : 0; // 0 = Check In, 1 = Check Out
      final formattedDisplay = LastAttendanceModel(
        inOutTime: timeStr,
        timeFlag: newFlag,
      ).formattedTime;
      final dateFormatted = DateFormat('dd/MM/yyyy').format(now);
      final user = await LocalStorageService.getUser();
      final empId = user?.employeeId ?? 1;

      // 1. Post punch live to server (preserves first inTime on daily attendance Tail, logs every swipe to Tail2)
      final inTimeForTail = _rawCheckInTime.isNotEmpty
          ? _rawCheckInTime
          : timeStr;
      final outTimeForTail = newFlag == 1
          ? timeStr
          : (_checkOutTime.isNotEmpty ? _checkOutTime : '');

      await _attendanceService.saveAttendance(
        branchId: branch.id,
        employeeId: empId,
        inOutTime: timeStr,
        timeFlag: newFlag,
        date: dateFormatted,
        reason: newFlag == 0 ? 'Mobile Check In' : 'Mobile Check Out',
        inTime: inTimeForTail,
        outTime: outTimeForTail,
      );

      if (!mounted) return;

      setState(() {
        _isCheckedIn = !_isCheckedIn;
        if (_isCheckedIn) {
          // If first check-in of the day, save it. If re-checking in, keep the day's first check-in!
          if (_checkInTime == '--:--' || _checkInTime.isEmpty) {
            _checkInTime = formattedDisplay;
            _rawCheckInTime = timeStr;
          }
          _liveDayDetails[now.day] = {
            'inTime': _checkInTime,
            'outTime': _checkOutTime.isNotEmpty ? _checkOutTime : '--:--',
            'present': 'P',
          };
          _liveDayStatus[now.day] = Colors.green;
        } else {
          // Last check-out is updated to this latest check-out
          _checkOutTime = formattedDisplay;
          _liveDayDetails[now.day] = {
            'inTime': _checkInTime,
            'outTime': formattedDisplay,
            'present': 'X',
          };
          _liveDayStatus[now.day] = Colors.green;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isCheckedIn
                      ? 'Checked in successfully at ${branch.name}!'
                      : 'Checked out successfully at ${branch.name}!',
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // 2. Fetch latest attendance & monthly logs from server to guarantee sync
      await _loadInitialData();
    } catch (e) {
      if (!mounted) return;
      _showLocationDialog(
        title: 'Location Error',
        message:
            'Unable to determine your current location. Please verify your GPS settings and try again.\n\nError: $e',
        icon: Icons.error_outline_rounded,
        iconColor: AppColors.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isLocationChecking = false);
      }
    }
  }

  void _showLocationDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text(
          'Are you sure you want to log out of your session?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              Navigator.pop(context);
              await LocalStorageService.clearUserSession();
              if (context.mounted) {
                context.go('/login');
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showHeaderPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Office & Financial Year Configuration',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Branch Section
                    const Text(
                      'Branch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._branches.map((branch) {
                      final isSelected = branch.value == _selectedBranch?.value;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.business_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        title: Text(
                          branch.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedBranch = branch;
                          });
                          LocalStorageService.saveSelectedBranchId(
                            branch.value,
                          );
                          setBottomSheetState(() {});
                          _fetchAndApplyLastAttendance();
                        },
                      );
                    }),

                    const Divider(height: 24),

                    // Financial Year Section
                    const Text(
                      'Financial Year',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._financialYears.map((fy) {
                      final isSelected =
                          fy.value == _selectedFinancialYear?.value;
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.calendar_today_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textMuted,
                        ),
                        title: Text(
                          fy.name,
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : null,
                        onTap: () {
                          setState(() {
                            _selectedFinancialYear = fy;
                          });
                          setBottomSheetState(() {});
                        },
                      );
                    }),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _loadInitialData();
                        },
                        child: const Text('Apply Changes'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = _selectedDate.day;
    final selectedDayDetails = _liveDayDetails[selectedDay];
    final selectedInTime = selectedDayDetails?['inTime'];
    final selectedOutTime = selectedDayDetails?['outTime'];
    final now = DateTime.now();
    final isSelectedToday =
        _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;

    final displayInTime = (isSelectedToday && _checkInTime != '--:--')
        ? _checkInTime
        : (selectedInTime != null &&
              selectedInTime.isNotEmpty &&
              selectedInTime != '--:--' &&
              selectedInTime != '00:00' &&
              selectedInTime != 'CL' &&
              selectedInTime != 'SL' &&
              selectedInTime != 'PL' &&
              selectedInTime != 'AB')
        ? selectedInTime
        : '--:--';

    final displayOutTime =
        (isSelectedToday &&
            _checkOutTime.isNotEmpty &&
            _checkOutTime != '--:--')
        ? _checkOutTime
        : (selectedOutTime != null &&
              selectedOutTime.isNotEmpty &&
              selectedOutTime != '--:--' &&
              selectedOutTime != '00:00' &&
              selectedOutTime != 'CL' &&
              selectedOutTime != 'SL' &&
              selectedOutTime != 'PL' &&
              selectedOutTime != 'AB')
        ? selectedOutTime
        : '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Align(
          alignment: Alignment.centerLeft,
          child: _buildAppBarLogo(context),
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none_rounded, size: 24),
                onPressed: () => context.push('/notifications'),
              ),
              if (_notificationCount > 0)
                Positioned(
                  right: 4,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$_notificationCount',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 6),
          Padding(
            padding: const EdgeInsets.only(right: 14, left: 4),
            child: GestureDetector(
              onTap: () => context.go('/profile'),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary,
                child: Text(
                  _userAvatarLetter,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Profile & App Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            _buildDrawerLogo(),
                            const SizedBox(width: 10),
                            const Text(
                              'Cryptone HRMS',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF059669),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Live',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF047857),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // User Profile Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _userAvatarLetter,
                                  style: const TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _userName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _userDesignation,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.pop(context);
                                      _showHeaderPicker();
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.18,
                                          ),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.storefront_rounded,
                                            size: 11.5,
                                            color: AppColors.primary,
                                          ),
                                          const SizedBox(width: 4),
                                          Flexible(
                                            child: Text(
                                              _selectedBranch != null
                                                  ? '${_selectedBranch!.name}${_selectedFinancialYear != null ? " • ${_selectedFinancialYear!.name}" : ""}'
                                                  : (_branches.isNotEmpty
                                                        ? _branches.first.name
                                                        : 'Select Branch'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            size: 15,
                                            color: AppColors.primary,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),

              // Menu Navigation List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'MAIN WORKSPACE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildDrawerTile(
                      icon: Icons.grid_view_rounded,
                      title: 'Home Dashboard',
                      isActive: true,
                      iconBg: const Color(0xFFEFF6FF),
                      iconColor: AppColors.primary,
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/dashboard');
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.fingerprint_rounded,
                      title: "Today's Punch History",
                      isActive: false,
                      iconBg: const Color(0xFFECFDF5),
                      iconColor: const Color(0xFF059669),
                      badge: 'Live',
                      onTap: () {
                        Navigator.pop(context);
                        _showTodayPunchHistory();
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.calendar_today_rounded,
                      title: 'Leave Management',
                      isActive: false,
                      iconBg: const Color(0xFFFEF3C7),
                      iconColor: const Color(0xFFD97706),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/leave');
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Claims & Expenses',
                      isActive: false,
                      iconBg: const Color(0xFFEDE9FE),
                      iconColor: const Color(0xFF7C3AED),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/claims');
                      },
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        'ACCOUNT & SETTINGS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    _buildDrawerTile(
                      icon: Icons.person_outline_rounded,
                      title: 'My Profile',
                      isActive: false,
                      iconBg: const Color(0xFFE0F2FE),
                      iconColor: const Color(0xFF0284C7),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/profile');
                      },
                    ),
                    _buildDrawerTile(
                      icon: Icons.settings_outlined,
                      title: 'App Settings',
                      isActive: false,
                      iconBg: const Color(0xFFF1F5F9),
                      iconColor: const Color(0xFF475569),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/settings');
                      },
                    ),
                  ],
                ),
              ),

              // Bottom Logout & Version Footer
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _showLogoutConfirmation(context);
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFEE2E2)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(
                                  Icons.logout_rounded,
                                  color: Color(0xFFDC2626),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sign Out',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                  Text(
                                    'End active session',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 12,
                                color: Color(0xFFEF4444),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cryptone HRMS • v2.4.0 Enterprise',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Warm Greeting Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                'Welcome, $_userName',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$_userDesignation • Cryptone HRMS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // User Avatar Tile with verified check badge
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _userAvatarLetter,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Positioned(
                          right: -3,
                          bottom: -3,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Hero Punch & Today's Attendance Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Today's In Time Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: _isCheckedIn
                                          ? AppColors.secondary
                                          : (displayOutTime.isNotEmpty
                                                ? Colors.orange
                                                : AppColors.textMuted),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _isCheckedIn
                                          ? "Today's In Time"
                                          : (displayOutTime.isNotEmpty
                                                ? "Today's Out Time"
                                                : "Today's In Time"),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  if (!_isCheckedIn &&
                                      displayOutTime.isNotEmpty &&
                                      displayInTime != '--:--') ...[
                                    const SizedBox(width: 6),
                                    Text(
                                      '(In: $displayInTime)',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  (!_isCheckedIn && displayOutTime.isNotEmpty)
                                      ? displayOutTime
                                      : displayInTime,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: _showTodayPunchHistory,
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.0,
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: const [
                                        Text(
                                          'Tap to view punch history',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        SizedBox(width: 3),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Right: Punch Action Button
                        // Right: Punch Action Button
                        ElevatedButton.icon(
                          onPressed: _isLocationChecking
                              ? null
                              : _toggleCheckIn,
                          icon: _isLocationChecking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isCheckedIn
                                      ? Icons.logout_rounded
                                      : Icons.login_rounded,
                                  size: 18,
                                ),
                          label: Text(
                            _isLocationChecking
                                ? 'Verifying...'
                                : (_isCheckedIn ? 'Check Out' : 'Check In'),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isCheckedIn
                                ? AppColors.error
                                : AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Verification Status Chip - ONLY show when user is checked in
                    if (_isCheckedIn) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.verified_rounded,
                                size: 14,
                                color: AppColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Verified at ${_selectedBranch?.name ?? "Head Office"} • On Time',
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. Overview Header & Date Selector Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Overview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _selectDashboardDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF0F172A,
                            ).withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 15,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM yyyy').format(_selectedDate),
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 4. Metric Cards Row (Attendance & Leaves Taken)
              DashboardMetrics(
                attendanceCount: _attendanceCount,
                leavesTakenCount: _leavesCount,
              ),
              const SizedBox(height: 16),

              // 5. Attendance Monthly Calendar
              AttendanceCalendarWidget(
                liveDayStatus: _liveDayStatus,
                liveDayDetails: _liveDayDetails,
                selectedDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
              ),
              const SizedBox(height: 16),

              // 6. Leave Balance Overview (Donut Chart / Table View)
              LeaveBalanceChart(items: _leaveSummaryItems),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBarLogo(BuildContext context) {
    return GestureDetector(
      onTap: () => Scaffold.of(context).openDrawer(),
      child: _companyImageUrl != null && _companyImageUrl!.isNotEmpty
          ? Container(
              height: 36,
              constraints: const BoxConstraints(maxWidth: 160),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Image.network(
                _companyImageUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _buildAppBarFallback(),
              ),
            )
          : _buildAppBarFallback(),
    );
  }

  Widget _buildAppBarFallback() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_rounded, color: AppColors.primary, size: 19),
          SizedBox(width: 6),
          Text(
            'Cryptone HRMS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerLogo() {
    if (_companyImageUrl != null && _companyImageUrl!.isNotEmpty) {
      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.cardBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: Image.network(
            _companyImageUrl!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _buildDrawerFallbackLogo(),
          ),
        ),
      );
    }
    return _buildDrawerFallbackLogo();
  }

  Widget _buildDrawerFallbackLogo() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.hub_rounded, color: Colors.white, size: 20),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    required bool isActive,
    required Color iconBg,
    required Color iconColor,
    required VoidCallback onTap,
    String? badge,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: iconColor.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: iconColor, size: 19),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: isActive
                          ? AppColors.primary
                          : const Color(0xFF334155),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (badge != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (trailing != null)
                  trailing
                else if (isActive)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  )
                else
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFFCBD5E1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
