import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/models/user_rights_model.dart';
import '../../../auth/data/services/user_rights_service.dart';
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

  List<LeaveApplicationModel> _allLeaveApplications = [];
  UserRightsModel? _userRights;
  String _currentUserName = '';
  bool _isLoading = true;
  int _selectedTabIndex = 0; // 0 = All, 1 = To Approve, 2 = My Leaves

  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _loadLeaveData();
  }

  Future<void> _loadLeaveData() async {
    setState(() => _isLoading = true);
    final rights = await _userRightsService.fetchUserRights(menuCode: 19);
    final user = await LocalStorageService.getUser();

    // Fetch all leave applications assigned to this user (approver list + own leaves)
    var list = await _leaveService.fetchLeaveApplications();
    if (list.isEmpty) {
      list = await _leaveService.searchEmployeeLeaves();
    }

    // Sort descending by key so the most recent applications appear first
    list.sort((a, b) => b.key.compareTo(a.key));

    if (mounted) {
      setState(() {
        _userRights = rights;
        _currentUserName = user?.userName ?? '';
        _allLeaveApplications = list;
        _isLoading = false;
      });
    }
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

  int get _pendingApprovalsCount {
    return _allLeaveApplications.where((item) {
      final isOwn = _currentUserName.isNotEmpty &&
          item.employee.toLowerCase().contains(_currentUserName.toLowerCase());
      final isForward = item.status.toLowerCase() == 'forward' ||
          item.status.toLowerCase() == 'pending';
      return isForward && !isOwn;
    }).length;
  }

  int get _myLeavesCount {
    return _allLeaveApplications.where((item) {
      return _currentUserName.isNotEmpty &&
          item.employee.toLowerCase().contains(_currentUserName.toLowerCase());
    }).length;
  }

  List<LeaveApplicationModel> get _filteredApplications {
    return _allLeaveApplications.where((item) {
      // 1. Date filter
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

      // 2. Tab filter
      final isOwn = _currentUserName.isNotEmpty &&
          item.employee.toLowerCase().contains(_currentUserName.toLowerCase());
      final isForward = item.status.toLowerCase() == 'forward' ||
          item.status.toLowerCase() == 'pending';

      if (_selectedTabIndex == 1) {
        // "To Approve": Forward / Pending leaves from team members
        return isForward && !isOwn;
      } else if (_selectedTabIndex == 2) {
        // "My Leaves": Leaves applied by the logged-in user
        return isOwn;
      }
      return true; // "All"
    }).toList();
  }

  Future<void> _handleApproveOrForward(
      LeaveApplicationModel item, String status) async {
    final actionName = status == 'A' ? 'Approve' : 'Forward';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              status == 'A'
                  ? Icons.check_circle_outline_rounded
                  : Icons.forward_rounded,
              color: status == 'A' ? Colors.green : AppColors.primary,
            ),
            const SizedBox(width: 8),
            Text('$actionName Leave'),
          ],
        ),
        content: Text(
            'Are you sure you want to $actionName leave application #${item.key} for ${item.employee}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  status == 'A' ? Colors.green : AppColors.primary,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionName),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await _leaveService.approveOrForwardLeave(
      key: item.key,
      approvalStatus: status,
    );

    if (mounted && success) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
              'Leave #${item.key} (${item.employee}) marked as $actionName!'),
          backgroundColor: Colors.green,
        ),
      );
      _loadLeaveData();
    } else if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Failed to $actionName leave application #${item.key}.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 15, color: AppColors.primary),
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
                        child: Text('-',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textMuted)),
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
                                horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded,
                                    size: 15, color: AppColors.primary),
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
            final approvalStatus = summaryItem.status.isNotEmpty
                ? summaryItem.status
                : (details?.approvalStatusText ?? 'Approved');
            final reason = summaryItem.reason.isNotEmpty
                ? summaryItem.reason
                : (details?.reason ?? 'N/A');
            final noOfLeaves = summaryItem.noOfLeaves > 0
                ? summaryItem.noOfLeaves
                : (details?.noOfLeaves ?? 1.0);
            final empId = details?.empId ?? 26;

            final isOwnLeave = _currentUserName.isNotEmpty &&
                summaryItem.employee
                    .toLowerCase()
                    .contains(_currentUserName.toLowerCase());
            final isPending = approvalStatus.toLowerCase() == 'forward' ||
                approvalStatus.toLowerCase() == 'pending' ||
                summaryItem.status.toLowerCase() == 'forward' ||
                summaryItem.status.toLowerCase() == 'pending';

            Color statusBgColor = Colors.green.withValues(alpha: 0.1);
            Color statusTextColor = Colors.green;
            if (approvalStatus.toLowerCase() == 'pending') {
              statusBgColor = Colors.orange.withValues(alpha: 0.1);
              statusTextColor = Colors.orange;
            } else if (approvalStatus.toLowerCase() == 'rejected') {
              statusBgColor = Colors.red.withValues(alpha: 0.1);
              statusTextColor = Colors.red;
            } else if (approvalStatus.toLowerCase() == 'forward') {
              statusBgColor = Colors.blue.withValues(alpha: 0.1);
              statusTextColor = Colors.blue;
            }

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
                        Text(
                          'Application Details #${summaryItem.key}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            approvalStatus,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    _DetailRow(
                      label: 'Applicant',
                      value: '${summaryItem.employee} (ID: $empId)',
                    ),
                    _DetailRow(
                      label: 'Leave Category',
                      value: summaryItem.leaveName,
                    ),
                    _DetailRow(
                      label: 'Leave Duration',
                      value: '$noOfLeaves Days (${summaryItem.leaveType})',
                    ),
                    _DetailRow(
                      label: 'From Date',
                      value: summaryItem.fromDate,
                    ),
                    _DetailRow(
                      label: 'To Date',
                      value: summaryItem.toDate,
                    ),
                    _DetailRow(
                      label: 'Reason',
                      value: reason.isNotEmpty ? reason : 'No reason specified',
                    ),
                    const SizedBox(height: 8),
                    if (isPending && !isOwnLeave) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.forward_rounded, size: 16),
                              label: const Text('Forward'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side:
                                    const BorderSide(color: AppColors.primary),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _handleApproveOrForward(summaryItem, 'F');
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 16),
                              label: const Text('Approve'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _handleApproveOrForward(summaryItem, 'A');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
                        ),
                      ),
                    ] else if (isPending && isOwnLeave) ...[
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                              ),
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                Navigator.pop(context);
                                final success =
                                    await _leaveService.saveLeaveCancellation(
                                  lvApplicationId: summaryItem.key.toString(),
                                  remarks: 'Cancel leave request',
                                );
                                if (mounted && success) {
                                  messenger.showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Leave Cancellation submitted for approval!'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                  _loadLeaveData();
                                }
                              },
                              child: const Text('Cancel Leave'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close'),
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
        title: const Text('Leave Management'),
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
                        Icon(Icons.lock_person_outlined,
                            size: 56, color: AppColors.error),
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
                              fontSize: 13, color: AppColors.textMuted),
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
              label: const Text('Apply Leave',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
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
          top: 10.0,
          bottom: MediaQuery.of(context).padding.bottom + 80,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Tabs: All, To Approve, My Leaves
            _buildTabsBar(),

            if (_filterStartDate != null || _filterEndDate != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.filter_alt_outlined,
                            size: 15, color: AppColors.primary),
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
                      child: const Icon(Icons.close_rounded,
                          size: 16, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedTabIndex == 1
                      ? 'Applications For Your Approval'
                      : _selectedTabIndex == 2
                          ? 'My Leave Applications'
                          : 'Recent Leave Applications',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${displayList.length} records',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
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
                  children: [
                    const Icon(Icons.event_busy_rounded,
                        size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 8),
                    Text(
                      _selectedTabIndex == 1
                          ? 'No pending applications to approve'
                          : _selectedTabIndex == 2
                              ? 'No personal leave applications found'
                              : 'No leave applications found',
                      style: const TextStyle(color: AppColors.textMuted),
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
                  final isOwn = _currentUserName.isNotEmpty &&
                      item.employee
                          .toLowerCase()
                          .contains(_currentUserName.toLowerCase());
                  final statusLower = item.status.toLowerCase();
                  Color statusBg = Colors.orange.withValues(alpha: 0.1);
                  Color statusColor = Colors.orange;
                  if (statusLower == 'approved') {
                    statusBg = Colors.green.withValues(alpha: 0.1);
                    statusColor = Colors.green;
                  } else if (statusLower == 'rejected') {
                    statusBg = Colors.red.withValues(alpha: 0.1);
                    statusColor = Colors.red;
                  } else if (statusLower == 'forward') {
                    statusBg = Colors.blue.withValues(alpha: 0.1);
                    statusColor = Colors.blue;
                  }

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
                                        color: (item.leaveName
                                                    .toLowerCase()
                                                    .contains('sick')
                                                ? const Color(0xFF0D9488)
                                                : const Color(0xFF1E88E5))
                                            .withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        item.leaveName
                                                .toLowerCase()
                                                .contains('sick')
                                            ? Icons.local_hospital_outlined
                                            : Icons.flight_takeoff_rounded,
                                        size: 18,
                                        color: item.leaveName
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
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  item.employee,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (isOwn) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                      horizontal: 6, vertical: 1),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.primary
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'You',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${item.leaveName} • ${item.leaveType}',
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
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.status.isNotEmpty
                                      ? item.status
                                      : 'Pending',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20, color: AppColors.cardBorder),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.date_range_outlined,
                                      size: 15, color: AppColors.primary),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.fromDate == item.toDate
                                        ? 'Leave Date: ${item.fromDate}'
                                        : 'Leave Date: ${item.fromDate} - ${item.toDate}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          _buildTabItem(0, 'All', _allLeaveApplications.length),
          _buildTabItem(1, 'To Approve', _pendingApprovalsCount, isBadge: true),
          _buildTabItem(2, 'My Leaves', _myLeavesCount),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label, int count,
      {bool isBadge = false}) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isBadge && count > 0
                      ? Colors.orange
                      : (isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isBadge && count > 0
                        ? Colors.white
                        : (isSelected
                            ? AppColors.primary
                            : Colors.grey.shade700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMuted,
            ),
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

