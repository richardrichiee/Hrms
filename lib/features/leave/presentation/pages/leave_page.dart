import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/models/user_rights_model.dart';
import '../../../auth/data/services/user_rights_service.dart';
import '../../../profile/data/models/employee_details_model.dart';
import '../../../profile/data/services/employee_service.dart';
import '../../data/models/leave_application_model.dart';
import '../../data/models/leave_details_model.dart';
import '../../data/services/leave_service.dart';
import 'apply_leave_page.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final _leaveService = LeaveService();
  final _userRightsService = UserRightsService();
  final _employeeService = EmployeeService();

  List<LeaveApplicationModel> _leaveApplications = [];
  UserRightsModel? _userRights;
  bool _isLoading = true;

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  Set<int> _pendingCancellationKeys = {};

  @override
  void initState() {
    super.initState();
    _loadLeaveData();
  }

  Future<void> _loadLeaveData() async {
    setState(() => _isLoading = true);
    final user = await LocalStorageService.getUser();
    final effectiveBranchId =
        await LocalStorageService.getEffectiveUserBranchId();
    final rights = await _userRightsService.fetchUserRights(
      menuCode: 19,
      branchId: effectiveBranchId,
    );

    final results = await Future.wait([
      _leaveService.fetchLeaveApplications(),
      _employeeService.fetchEmployeeDashboard(),
    ]);

    final allApps = results[0] as List<LeaveApplicationModel>;
    final empDetails = results[1] as EmployeeDetailsModel?;

    final currentUserName = (empDetails != null && empDetails.name.isNotEmpty)
        ? empDetails.name
        : (user?.userName ?? '');

    debugPrint(
      '📋 [LeavePage] _loadLeaveData: Current user="$currentUserName" (login userName="${user?.userName}", empName="${empDetails?.name}")',
    );
    debugPrint(
      '📋 [LeavePage] Fetched ${allApps.length} raw leaves from server',
    );

    // Filter to show ONLY the logged-in user's own leave applications
    final myLeaves = allApps.where((item) {
      final matches = _isCurrentUser(item.employee, currentUserName);
      debugPrint(
        '   👉 Leave #${item.key}: emp="${item.employee}", dates=${item.fromDate} to ${item.toDate}, status="${item.status}", matchesCurrentUser=$matches',
      );
      return matches;
    }).toList();

    debugPrint('📋 [LeavePage] Filtered leaves count: ${myLeaves.length}');

    // Sort descending by key so the most recent applications appear first
    myLeaves.sort((a, b) => b.key.compareTo(a.key));

    final pendingKeys = await _leaveService.resolvePendingCancellationKeys(myLeaves);

    if (mounted) {
      setState(() {
        _userRights = rights;
        _leaveApplications = myLeaves;
        _pendingCancellationKeys = pendingKeys;
        _isLoading = false;
      });
    }
  }

  bool _isCurrentUser(String employeeName, String currentUserName) {
    if (currentUserName.trim().isEmpty) return true;
    final empTrim = employeeName.trim();
    // If the record doesn't specify employee name (defaults to 'Employee' or empty),
    // and the list was fetched for the current user's userId, it belongs to this user!
    if (empTrim.isEmpty || empTrim.toLowerCase() == 'employee') {
      return true;
    }
    final cleanEmp = empTrim.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final cleanUser = currentUserName
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    if (cleanEmp.isEmpty || cleanUser.isEmpty) return true;
    if (cleanEmp == cleanUser ||
        cleanEmp.contains(cleanUser) ||
        cleanUser.contains(cleanEmp)) {
      return true;
    }
    // Token matching: e.g. "arun" in "arun p a"
    final userTokens = cleanUser.split(' ').where((t) => t.isNotEmpty);
    final empTokens = cleanEmp.split(' ').where((t) => t.isNotEmpty);
    for (final ut in userTokens) {
      if (empTokens.contains(ut)) return true;
    }
    return false;
  }

  DateTime? _parseLeaveDate(String dateStr) {
    try {
      final parts = dateStr.trim().split('/');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime.tryParse(dateStr);
  }

  String _formatStatus(String? rawStatus, {int? key}) {
    if (key != null && _pendingCancellationKeys.contains(key)) {
      return 'Cancellation Pending';
    }
    if (rawStatus == null || rawStatus.isEmpty) return 'Pending';
    final s = rawStatus.trim().toUpperCase();
    if (s == 'A' || s == 'APPROVED' || s == 'APPROVE') return 'Approved';
    if (s == 'R' || s == 'REJECTED' || s == 'REJECT') return 'Rejected';
    if (s == 'F' || s == 'FORWARD' || s == 'FORWARDED') return 'Forwarded';
    if (s == 'C' || s == 'CANCEL' || s == 'CANCELLED') return 'Cancelled';
    if (s == 'N' || s == 'P' || s == 'PENDING') return 'Pending';
    return rawStatus;
  }

  Color _getStatusBg(String? status) {
    final s = (status ?? '').trim().toUpperCase();
    if (s == 'CANCELLATION PENDING' || s.contains('CANCELLATION')) {
      return const Color(0xFFFEF3C7);
    }
    if (s == 'A' || s == 'APPROVED' || s == 'APPROVE') {
      return Colors.green.withValues(alpha: 0.1);
    } else if (s == 'R' || s == 'REJECTED' || s == 'REJECT') {
      return Colors.red.withValues(alpha: 0.1);
    } else if (s == 'F' || s == 'FORWARD' || s == 'FORWARDED') {
      return Colors.blue.withValues(alpha: 0.1);
    } else if (s == 'C' || s == 'CANCEL' || s == 'CANCELLED') {
      return Colors.grey.withValues(alpha: 0.15);
    }
    return Colors.orange.withValues(alpha: 0.1);
  }

  Color _getStatusColor(String? status) {
    final s = (status ?? '').trim().toUpperCase();
    if (s == 'CANCELLATION PENDING' || s.contains('CANCELLATION')) {
      return const Color(0xFFD97706);
    }
    if (s == 'A' || s == 'APPROVED' || s == 'APPROVE') {
      return Colors.green;
    } else if (s == 'R' || s == 'REJECTED' || s == 'REJECT') {
      return Colors.red;
    } else if (s == 'F' || s == 'FORWARD' || s == 'FORWARDED') {
      return Colors.blue;
    } else if (s == 'C' || s == 'CANCEL' || s == 'CANCELLED') {
      return Colors.grey;
    }
    return Colors.orange;
  }

  bool _isStatusCancellable(String? status, {int? key}) {
    if (key != null && _pendingCancellationKeys.contains(key)) {
      return false;
    }
    if (status == null || status.isEmpty) return true;
    final s = status.trim().toUpperCase();
    if (s == 'C' ||
        s == 'CANCEL' ||
        s == 'CANCELLED' ||
        s == 'R' ||
        s == 'REJECTED' ||
        s == 'REJECT' ||
        s == 'CANCELLATION PENDING' ||
        s.contains('CANCELLATION')) {
      return false;
    }
    // Pending, Forwarded, and Approved requests can all be cancelled by the user
    return true;
  }

  List<LeaveApplicationModel> get _filteredApplications {
    return _leaveApplications.where((item) {
      if (_filterStartDate != null || _filterEndDate != null) {
        final from = _parseLeaveDate(item.fromDate);
        final to = _parseLeaveDate(item.toDate) ?? from;
        if (from != null) {
          if (_filterStartDate != null) {
            final startDay = DateTime(
              _filterStartDate!.year,
              _filterStartDate!.month,
              _filterStartDate!.day,
            );
            if (to != null && to.isBefore(startDay)) return false;
          }
          if (_filterEndDate != null) {
            final endDay = DateTime(
              _filterEndDate!.year,
              _filterEndDate!.month,
              _filterEndDate!.day,
              23,
              59,
              59,
            );
            if (from.isAfter(endDay)) return false;
          }
        }
      }
      return true;
    }).toList();
  }

  void _navigateToApplyLeave() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ApplyLeavePage()),
    ).then((_) => _loadLeaveData());
  }

  void _showFilterModal() {
    DateTime? tempStartDate = _filterStartDate;
    DateTime? tempEndDate = _filterEndDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final sFormatted = tempStartDate != null
                ? DateFormat('dd/MM/yyyy').format(tempStartDate!)
                : 'Start Date';
            final eFormatted = tempEndDate != null
                ? DateFormat('dd/MM/yyyy').format(tempEndDate!)
                : 'End Date';

            return Padding(
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter by Date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (tempStartDate != null || tempEndDate != null)
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempStartDate = null;
                              tempEndDate = null;
                            });
                          },
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              color: AppColors.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempStartDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => tempStartDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    sFormatted,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: tempStartDate != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: tempStartDate != null
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '-',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: tempEndDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => tempEndDate = picked);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 15,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    eFormatted,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: tempEndDate != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: tempEndDate != null
                                          ? AppColors.textPrimary
                                          : AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _filterStartDate = tempStartDate;
                          _filterEndDate = tempEndDate;
                        });
                        _loadLeaveData();
                      },
                      child: const Text(
                        'Apply Filter',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLeaveDetailsModal(LeaveApplicationModel summaryItem) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return FutureBuilder<LeaveDetailsModel?>(
          future: _leaveService.fetchLeaveApplicationDetails(summaryItem.key),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final details = snapshot.data;
            final isPendingCancel =
                _pendingCancellationKeys.contains(summaryItem.key);
            final rawStatus = summaryItem.status.isNotEmpty
                ? summaryItem.status
                : (details?.approvalStatusText ?? 'Pending');
            final approvalStatus =
                _formatStatus(rawStatus, key: summaryItem.key);
            final reason = summaryItem.reason.isNotEmpty
                ? summaryItem.reason
                : (details?.reason ?? 'N/A');
            final noOfLeaves = summaryItem.noOfLeaves > 0
                ? summaryItem.noOfLeaves
                : (details?.noOfLeaves ?? 1.0);

            final isCancellable = !isPendingCancel &&
                _isStatusCancellable(rawStatus, key: summaryItem.key);
            final isApproved = approvalStatus == 'Approved';
            final statusBgColor = _getStatusBg(approvalStatus);
            final statusTextColor = _getStatusColor(approvalStatus);

            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: MediaQuery.of(context).padding.bottom + 20.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Leave Application Details',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            approvalStatus,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _DetailRow(label: 'Leave', value: summaryItem.leaveName),
                    _DetailRow(
                      label: 'Leave Duration',
                      value:
                          '${(noOfLeaves % 1 == 0) ? noOfLeaves.toInt() : noOfLeaves} ${(noOfLeaves == 1) ? "Day" : "Days"} (${summaryItem.formattedLeaveType})',
                    ),
                    _DetailRow(label: 'From Date', value: summaryItem.fromDate),
                    _DetailRow(label: 'To Date', value: summaryItem.toDate),
                    _DetailRow(
                      label: 'Reason',
                      value: reason.isNotEmpty ? reason : 'No reason specified',
                    ),
                    if (isPendingCancel) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.hourglass_top_rounded,
                                color: Color(0xFFD97706), size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cancellation request has been submitted and is awaiting approval.',
                                style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (isCancellable) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    title: const Row(
                                      children: [
                                        Icon(
                                          Icons.warning_amber_rounded,
                                          color: AppColors.error,
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'Cancel Leave Request',
                                            style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Text(
                                      isApproved
                                          ? 'Are you sure you want to cancel this approved leave application?'
                                          : 'Are you sure you want to cancel this leave application?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Keep Leave'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Yes, Cancel'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm != true || !context.mounted) return;

                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(context);

                                messenger.showSnackBar(
                                  const SnackBar(
                                    content: Row(
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 12),
                                        Text('Cancelling leave request...'),
                                      ],
                                    ),
                                    duration: Duration(seconds: 2),
                                  ),
                                );

                                final isApproverLevel3 =
                                    _userRights?.transactions == 3;
                                final success = await _leaveService
                                    .saveLeaveCancellation(
                                      lvApplicationId: summaryItem.key
                                          .toString(),
                                      remarks: 'Cancel leave request',
                                      approvalStatus: isApproverLevel3
                                          ? 'A'
                                          : 'N',
                                    );

                                if (mounted) {
                                  messenger.hideCurrentSnackBar();
                                  if (success) {
                                    await LocalStorageService
                                        .addPendingLeaveCancellationKey(
                                            summaryItem.key);
                                    setState(() {
                                      _pendingCancellationKeys
                                          .add(summaryItem.key);
                                    });
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Leave cancellation request sent successfully!',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadLeaveData();
                                  } else {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Failed to cancel leave request. Please try again.',
                                        ),
                                        backgroundColor: AppColors.error,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Cancel Leave'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Close',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
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
    final canView = _userRights?.viewRight ?? true;
    final canAdd = _userRights?.addRight ?? true;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Leave Management',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list_rounded, size: 22),
                if (_filterStartDate != null || _filterEndDate != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            tooltip: 'Filter by Date',
            onPressed: _showFilterModal,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadLeaveData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !canView
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.lock_person_outlined,
                      size: 56,
                      color: AppColors.error,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Access Restricted',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'You do not have permission (ViewRight) to access Leave Applications. Please contact your system administrator.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : _buildLeavesView(),
      floatingActionButton: (canView && canAdd)
          ? FloatingActionButton.extended(
              onPressed: _navigateToApplyLeave,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Apply Leave',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildLeavesView() {
    final sDateFormatted = _filterStartDate != null
        ? DateFormat('dd/MM/yyyy').format(_filterStartDate!)
        : 'Start Date';
    final eDateFormatted = _filterEndDate != null
        ? DateFormat('dd/MM/yyyy').format(_filterEndDate!)
        : 'End Date';

    final displayList = _filteredApplications;

    return RefreshIndicator(
      onRefresh: _loadLeaveData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          top: 14.0,
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_filterStartDate != null || _filterEndDate != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.filter_alt_outlined,
                          size: 15,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Filtered: $sDateFormatted - $eDateFormatted',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _filterStartDate = null;
                          _filterEndDate = null;
                        });
                        _loadLeaveData();
                      },
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Recent Leave Applications Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Leave Applications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${displayList.length} records',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (displayList.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: const [
                    Icon(
                      Icons.event_busy_rounded,
                      size: 40,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No leave applications found',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayList.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = displayList[index];
                  final statusText =
                      _formatStatus(item.status, key: item.key);
                  final statusBg = _getStatusBg(statusText);
                  final statusColor = _getStatusColor(statusText);

                  return GestureDetector(
                    onTap: () => _showLeaveDetailsModal(item),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color:
                                            (item.leaveName
                                                        .toLowerCase()
                                                        .contains('sick')
                                                    ? const Color(0xFF0D9488)
                                                    : const Color(0xFF1E88E5))
                                                .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        item.leaveName.toLowerCase().contains(
                                              'sick',
                                            )
                                            ? Icons.local_hospital_outlined
                                            : Icons.flight_takeoff_rounded,
                                        size: 18,
                                        color:
                                            item.leaveName
                                                .toLowerCase()
                                                .contains('sick')
                                            ? const Color(0xFF0D9488)
                                            : const Color(0xFF1E88E5),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.leaveName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.textPrimary,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            item.formattedLeaveType,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            height: 20,
                            color: AppColors.cardBorder,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.date_range_outlined,
                                      size: 15,
                                      color: AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.fromDate == item.toDate
                                            ? 'Leave Date: ${item.fromDate}'
                                            : 'Leave Date: ${item.fromDate} - ${item.toDate}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.2,
                                          color: AppColors.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.08,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${(item.noOfLeaves % 1 == 0) ? item.noOfLeaves.toInt() : item.noOfLeaves} ${(item.noOfLeaves == 1) ? "Day" : "Days"}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (item.reason.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Reason: ${item.reason}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 84),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
