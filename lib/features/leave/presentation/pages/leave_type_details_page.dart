import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../profile/data/models/employee_details_model.dart';
import '../../../profile/data/services/employee_service.dart';
import '../../data/models/leave_application_model.dart';
import '../../data/models/leave_details_model.dart';
import '../../data/services/leave_service.dart';
import '../widgets/apply_leave_dialog.dart';

class LeaveTypeDetailsPage extends StatefulWidget {
  final String leaveId; // '1' = Casual, '2' = Sick
  final String leaveName;
  final IconData icon;
  final Color color;
  final String description;

  const LeaveTypeDetailsPage({
    super.key,
    required this.leaveId,
    required this.leaveName,
    required this.icon,
    required this.color,
    required this.description,
  });

  @override
  State<LeaveTypeDetailsPage> createState() => _LeaveTypeDetailsPageState();
}

class _LeaveTypeDetailsPageState extends State<LeaveTypeDetailsPage> {
  final _leaveService = LeaveService();
  final _employeeService = EmployeeService();

  List<LeaveApplicationModel> _filteredApplications = [];
  LeaveBalanceItem? _balanceItem;
  Set<int> _pendingCancellationKeys = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await LocalStorageService.getUser();
      final results = await Future.wait([
        _leaveService.fetchLeaveApplications(),
        _employeeService.fetchEmployeeDashboard(),
      ]);

      final allApps = results[0] as List<LeaveApplicationModel>;
      final empDetails = results[1] as EmployeeDetailsModel?;

      final currentUserName = (empDetails != null && empDetails.name.isNotEmpty)
          ? empDetails.name
          : (user?.userName ?? '');

      final leaveIdInt = int.tryParse(widget.leaveId) ?? 0;
      LeaveBalanceItem? balance;
      if (empDetails?.leaveBalances != null) {
        for (final b in empDetails!.leaveBalances) {
          if (b.leaveId == leaveIdInt ||
              b.leaveName.toLowerCase().contains(widget.leaveName.toLowerCase()) ||
              (widget.leaveId == '1' && b.leaveName.toLowerCase().contains('casual')) ||
              (widget.leaveId == '2' && b.leaveName.toLowerCase().contains('sick'))) {
            balance = b;
            break;
          }
        }
      }

      final filtered = allApps.where((app) {
        final isUser = _isCurrentUser(app.employee, currentUserName);
        if (!isUser) return false;
        final name = app.leaveName.toLowerCase();
        final target = widget.leaveName.toLowerCase();
        return name.contains(target) ||
            (widget.leaveId == '1' && name.contains('casual')) ||
            (widget.leaveId == '2' && name.contains('sick'));
      }).toList();

      filtered.sort((a, b) => b.key.compareTo(a.key));

      final pendingKeys =
          await _leaveService.resolvePendingCancellationKeys(filtered);

      if (mounted) {
        setState(() {
          _filteredApplications = filtered;
          _balanceItem = balance;
          _pendingCancellationKeys = pendingKeys;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
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
    final cleanEmp =
        empTrim.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    final cleanUser =
        currentUserName.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
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

  void _openApplyModal() {
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ApplyLeaveDialog(initialLeaveId: widget.leaveId),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
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
    return 'Pending';
  }

  Color _getStatusColor(String? rawStatus) {
    final s = (rawStatus ?? '').trim().toUpperCase();
    if (s == 'CANCELLATION PENDING' || s.contains('CANCELLATION')) {
      return const Color(0xFFD97706);
    }
    final status = _formatStatus(rawStatus);
    switch (status) {
      case 'Approved':
        return const Color(0xFF16A34A);
      case 'Rejected':
        return const Color(0xFFDC2626);
      case 'Forwarded':
        return const Color(0xFF2563EB);
      case 'Cancelled':
        return const Color(0xFF6B7280);
      case 'Pending':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _getStatusBg(String? rawStatus) {
    final s = (rawStatus ?? '').trim().toUpperCase();
    if (s == 'CANCELLATION PENDING' || s.contains('CANCELLATION')) {
      return const Color(0xFFFEF3C7);
    }
    final status = _formatStatus(rawStatus);
    switch (status) {
      case 'Approved':
        return const Color(0xFFDCFCE7);
      case 'Rejected':
        return const Color(0xFFFEE2E2);
      case 'Forwarded':
        return const Color(0xFFDBEAFE);
      case 'Cancelled':
        return const Color(0xFFF3F4F6);
      case 'Pending':
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  void _showLeaveDetailsModal(LeaveApplicationModel summaryItem) {
    final isPendingCancel = _pendingCancellationKeys.contains(summaryItem.key);
    final statusText = _formatStatus(summaryItem.status, key: summaryItem.key);
    final statusBgColor = _getStatusBg(statusText);
    final statusTextColor = _getStatusColor(statusText);
    final isCancellable = !isPendingCancel &&
        statusText != 'Cancelled' &&
        statusText != 'Rejected';
    final isApproved = statusText == 'Approved';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return FutureBuilder<LeaveDetailsModel?>(
          future: _leaveService.fetchLeaveApplicationDetails(summaryItem.key),
          builder: (context, snapshot) {
            final details = snapshot.data;
            final reason = details?.reason.isNotEmpty == true
                ? details!.reason
                : summaryItem.reason;
            final noOfLeaves = details?.noOfLeaves ?? summaryItem.noOfLeaves;

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            statusText,
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
                    _DetailRow(
                      label: 'Leave',
                      value: summaryItem.leaveName,
                    ),
                    _DetailRow(
                      label: 'Leave Duration',
                      value:
                          '${(noOfLeaves % 1 == 0) ? noOfLeaves.toInt() : noOfLeaves} ${(noOfLeaves == 1) ? "Day" : "Days"} (${summaryItem.formattedLeaveType})',
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
                                  builder: (dlgCtx) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(16)),
                                    title: const Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded,
                                            color: AppColors.error),
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
                                    content: Text(isApproved
                                        ? 'Are you sure you want to cancel this approved leave application?'
                                        : 'Are you sure you want to cancel this leave application?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dlgCtx, false),
                                        child: const Text('Keep Leave'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.error,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(dlgCtx, true),
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

                                final success =
                                    await _leaveService.saveLeaveCancellation(
                                  lvApplicationId: summaryItem.key.toString(),
                                  remarks: 'Cancel leave request',
                                );

                                if (mounted) {
                                  messenger.hideCurrentSnackBar();
                                  if (success) {
                                    await LocalStorageService
                                        .addPendingLeaveCancellationKey(
                                            summaryItem.key);
                                    if (mounted) {
                                      setState(() {
                                        _pendingCancellationKeys
                                            .add(summaryItem.key);
                                      });
                                    }
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Leave cancellation request submitted successfully!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    _loadData();
                                  } else {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Failed to cancel leave request. Please try again.'),
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
                                backgroundColor: widget.color,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close',
                                  style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close',
                              style: TextStyle(color: Colors.white)),
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
    final balanceVal = _balanceItem?.closing;
    final balanceStr = balanceVal != null
        ? '${(balanceVal % 1 == 0) ? balanceVal.toInt() : balanceVal} ${(balanceVal == 1) ? "Day" : "Days"}'
        : '0 Days';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(
          widget.leaveName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 90,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Dynamic Category Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      widget.color.withValues(alpha: 0.12),
                      widget.color.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: widget.color.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(widget.icon, color: widget.color, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.leaveName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const Text(
                                  'Leave Category',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: widget.color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '${_filteredApplications.length} Requests',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: widget.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Metrics Row from Live Data
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _LiveMetric(
                          label: 'Available Balance',
                          value: balanceStr,
                          color: widget.color,
                        ),
                        Container(
                          height: 32,
                          width: 1,
                          color: AppColors.cardBorder,
                        ),
                        _LiveMetric(
                          label: 'Total Applied',
                          value: '${_filteredApplications.length}',
                          color: AppColors.textPrimary,
                        ),
                        Container(
                          height: 32,
                          width: 1,
                          color: AppColors.cardBorder,
                        ),
                        _LiveMetric(
                          label: 'Recent Record',
                          value: _filteredApplications.isNotEmpty
                              ? _filteredApplications.first.fromDate
                              : 'None',
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Description & Guidelines
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Guidelines & Policy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // History Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${widget.leaveName} History',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_filteredApplications.length} records',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // History list
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_filteredApplications.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.history_rounded,
                          size: 40, color: AppColors.textMuted.withValues(alpha: 0.6)),
                      const SizedBox(height: 8),
                      Text(
                        'No previous ${widget.leaveName} applications found',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Use the floating button below to apply',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredApplications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _filteredApplications[index];
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
                                          color: widget.color.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(widget.icon, size: 18, color: widget.color),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                      horizontal: 10, vertical: 4),
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
                            const Divider(height: 20, color: AppColors.cardBorder),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.date_range_outlined,
                                          size: 15, color: AppColors.primary),
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
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openApplyModal,
        backgroundColor: widget.color,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Apply ${widget.leaveName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _LiveMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
