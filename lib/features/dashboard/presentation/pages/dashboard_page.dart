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
  bool _isCheckedOut = false;
  bool _isLocationChecking = false;
  String _checkInTime = '--:--';
  String _userName = '';
  String _userDesignation = '';
  String _userAvatarLetter = '';

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
    final localPunch = await LocalStorageService.getLastPunch();
    final cachedBranches = await LocalStorageService.getBranches();
    final savedBranchId = await LocalStorageService.getSelectedBranchId();

    if (mounted) {
      setState(() {
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

    final leaveService = LeaveService();
    final branchId = _selectedBranch?.id ?? savedBranchId ?? 1;
    final empId = user?.employeeId;

    // 2. Fetch all dashboard data concurrently in parallel using Future.wait
    try {
      final results = await Future.wait([
        _employeeService.fetchEmployeeDashboard(date: formattedDate),
        _notificationService.fetchNotificationCount(),
        leaveService.fetchDashboardLeaves(date: formattedDate),
        _branches.isEmpty
            ? _branchService.fetchBranches()
            : Future.value(_branches),
        _financialYears.isEmpty
            ? _financialYearService.fetchFinancialYears()
            : Future.value(_financialYears),
        _attendanceService.fetchMonthlyAttendanceLogs(date: formattedDate),
        _attendanceService.fetchLastAttendance(
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
                _isCheckedOut = false;
                _checkInTime = todayIn!.trim();
              } else if (hasIn && hasOut) {
                _isCheckedIn = false;
                _isCheckedOut = true;
                _checkInTime = todayIn!.trim();
              } else {
                _isCheckedIn = false;
                _isCheckedOut = false;
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

        // Prioritize live server lastAttendance, with local device fallback
        if (lastAttendance != null && lastAttendance.inOutTime.isNotEmpty) {
          _isCheckedIn = lastAttendance.isCheckedIn;
          _isCheckedOut = lastAttendance.isCheckedOut;
          _checkInTime = lastAttendance.formattedTime;
        } else if (localPunch != null) {
          final isPunchedIn = localPunch['status'] == 'IN';
          _isCheckedIn = isPunchedIn;
          _isCheckedOut = !isPunchedIn;
          if (localPunch['time'] != null && localPunch['time']!.isNotEmpty) {
            _checkInTime = LastAttendanceModel(
              inOutTime: localPunch['time']!,
              timeFlag: isPunchedIn ? 1 : 0,
            ).formattedTime;
          }
        }
      });
    } catch (_) {}
  }

  Future<void> _fetchAndApplyLastAttendance() async {
    final currentBranch = _selectedBranch;
    if (currentBranch == null) return;
    try {
      final user = await LocalStorageService.getUser();
      final last = await _attendanceService.fetchLastAttendance(
        branchId: currentBranch.id,
        employeeId: user?.employeeId,
      );
      if (!mounted) return;
      if (last != null && last.inOutTime.isNotEmpty) {
        setState(() {
          _isCheckedIn = last.isCheckedIn;
          _isCheckedOut = last.isCheckedOut;
          _checkInTime = last.formattedTime;
        });
        return;
      }

      final localPunch = await LocalStorageService.getLastPunch();
      if (localPunch != null && mounted) {
        final isPunchedIn = localPunch['status'] == 'IN';
        setState(() {
          _isCheckedIn = isPunchedIn;
          _isCheckedOut = !isPunchedIn;
          if (localPunch['time'] != null && localPunch['time']!.isNotEmpty) {
            _checkInTime = LastAttendanceModel(
              inOutTime: localPunch['time']!,
              timeFlag: isPunchedIn ? 1 : 0,
            ).formattedTime;
          }
        });
      }
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
            final localHistory =
                await LocalStorageService.getTodayPunchHistory();

            // Merge server and local history, avoiding duplicate time+flag
            final Map<String, LastAttendanceModel> map = {};
            for (final item in serverHistory) {
              final key = '${item.inOutTime}_${item.timeFlag}';
              map[key] = item;
            }
            for (final item in localHistory) {
              final key = '${item.inOutTime}_${item.timeFlag}';
              map[key] = item;
            }

            final combined = map.values.toList();
            combined.sort((a, b) {
              final timeA = _parseTimeToSeconds(a.inOutTime);
              final timeB = _parseTimeToSeconds(b.inOutTime);
              return timeB.compareTo(timeA); // Descending (latest punch first)
            });

            return combined;
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

    final branch = _selectedBranch;
    if (branch == null ||
        branch.latitude == null ||
        branch.longitude == null ||
        branch.radius == null) {
      _showLocationDialog(
        title: 'Location Not Configured',
        message:
            'Branch location or radius is not configured for ${branch?.name ?? "this branch"}.\n\nPlease configure it in Settings or contact your administrator.',
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
      final newFlag = _isCheckedIn ? 0 : 1;
      final formattedDisplay = LastAttendanceModel(
        inOutTime: timeStr,
        timeFlag: newFlag,
      ).formattedTime;
      final dateFormatted = DateFormat('dd/MM/yyyy').format(now);
      final user = await LocalStorageService.getUser();
      final empId = user?.employeeId ?? 1;

      // 1. Post punch live to server
      await _attendanceService.saveAttendance(
        branchId: branch.id,
        employeeId: empId,
        inOutTime: timeStr,
        timeFlag: newFlag,
        date: dateFormatted,
        reason: newFlag == 1 ? 'Mobile Check In' : 'Mobile Check Out',
      );

      if (!mounted) return;

      setState(() {
        _isCheckedIn = !_isCheckedIn;
        if (_isCheckedIn) {
          _checkInTime = formattedDisplay;
          _isCheckedOut = false;
        } else {
          _isCheckedOut = true;
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

      await LocalStorageService.addTodayPunch(
        status: _isCheckedIn ? 'IN' : 'OUT',
        time: timeStr,
        reason: _isCheckedIn ? 'Mobile Check In' : 'Mobile Check Out',
      );

      // 2. Fetch latest attendance from server to guarantee sync
      await _fetchAndApplyLastAttendance();
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
                        onPressed: () => Navigator.pop(context),
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
    final branchName =
        _selectedBranch?.name ??
        (_branches.isNotEmpty ? _branches.first.name : '');
    final fyName =
        _selectedFinancialYear?.name ??
        (_financialYears.isNotEmpty ? _financialYears.first.name : '');
    final headerChipText = branchName.isNotEmpty && fyName.isNotEmpty
        ? '$branchName ($fyName)'
        : (branchName.isNotEmpty ? branchName : 'Dream Team HRMS');
    final formattedDatePill = DateFormat('dd/MM/yyyy').format(_selectedDate);

    final selectedDay = _selectedDate.day;
    final selectedDayDetails = _liveDayDetails[selectedDay];
    final selectedInTime = selectedDayDetails?['inTime'];
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
              selectedInTime != '00:00')
        ? selectedInTime
        : '--:--';

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Row(
          children: [
            GestureDetector(
              onTap: _showHeaderPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      headerChipText,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: AppColors.primary),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _userAvatarLetter,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              accountName: Text(
                _userName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              accountEmail: Text(
                '$_userDesignation • Cryptone HRMS',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.grid_view_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Home Dashboard'),
              onTap: () {
                Navigator.pop(context);
                context.go('/dashboard');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.calendar_today_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Leave Management'),
              onTap: () {
                Navigator.pop(context);
                context.push('/leave');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.primary,
              ),
              title: const Text('Claims & Reimbursements'),
              onTap: () {
                Navigator.pop(context);
                context.push('/claims');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
              ),
              title: const Text('My Profile'),
              onTap: () {
                Navigator.pop(context);
                context.go('/profile');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
                context.go('/settings');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.error),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutConfirmation(context);
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Action Row & Section Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $_userName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _userDesignation,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Check In Action Button
                  ElevatedButton.icon(
                    onPressed: _isLocationChecking ? null : _toggleCheckIn,
                    icon: _isLocationChecking
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _isCheckedIn
                                ? Icons.logout_rounded
                                : Icons.login_rounded,
                            size: 15,
                          ),
                    label: Text(
                      _isLocationChecking
                          ? 'Verifying...'
                          : (_isCheckedIn ? 'Check Out' : 'Check In'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isCheckedIn
                          ? AppColors.error
                          : AppColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 36),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Interactive Date Picker Pill Chip Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overview',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _selectDashboardDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B50A1),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.calendar_month_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            formattedDatePill,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 1. Metric Cards Row
              DashboardMetrics(
                attendanceCount: _attendanceCount,
                leavesTakenCount: _leavesCount,
                inTime: displayInTime,
                isCheckedIn: _isCheckedIn,
                isCheckedOut: _isCheckedOut,
                onInTimeCardTap: _showTodayPunchHistory,
              ),
              const SizedBox(height: 16),

              // 2. Attendance Monthly Calendar
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

              // 3. Leaves For The Month (Interactive Pie Chart / Table View)
              LeaveBalanceChart(items: _leaveSummaryItems),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
