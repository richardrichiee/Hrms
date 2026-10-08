import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../auth/data/models/user_rights_model.dart';
import '../../../auth/data/services/user_rights_service.dart';
import '../../../claims/data/services/claim_service.dart';
import '../../../leave/data/services/leave_service.dart';
import '../../data/services/inbox_service.dart';

class InboxCategoryDetailsPage extends StatefulWidget {
  final String title;
  final String menuCode;
  final String menuLinkCode;

  const InboxCategoryDetailsPage({
    super.key,
    required this.title,
    required this.menuCode,
    required this.menuLinkCode,
  });

  @override
  State<InboxCategoryDetailsPage> createState() =>
      _InboxCategoryDetailsPageState();
}

class _InboxCategoryDetailsPageState extends State<InboxCategoryDetailsPage> {
  final _inboxService = InboxService();
  final _leaveService = LeaveService();
  final _claimService = ClaimService();
  final _userRightsService = UserRightsService();

  UserRightsModel? _userRights;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  final Set<int> _processingIds = {};

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    final menuInt = int.tryParse(widget.menuCode) ?? 19;
    final results = await Future.wait([
      _inboxService.fetchInboxDetails(
        menuCode: widget.menuCode,
        menuLinkCode: widget.menuLinkCode,
      ),
      _userRightsService.fetchUserRights(menuCode: menuInt),
    ]);

    final list = results[0] as List<Map<String, dynamic>>;
    final rights = results[1] as UserRightsModel?;

    final isLeave = widget.menuCode == '19' ||
        widget.title.toLowerCase().contains('leave') ||
        list.any((i) => i.containsKey('LeaveType'));

    final isClaim = widget.menuCode == '15' ||
        widget.title.toLowerCase().contains('claim') ||
        list.any((i) => i.containsKey('ClaimNumber') || i.containsKey('ClaimDate'));

    if (isLeave && list.isNotEmpty) {
      await Future.wait(
        list.map((item) async {
          final id = int.tryParse(item['Key']?.toString() ?? item['ID']?.toString() ?? '0') ?? 0;
          if (id > 0) {
            try {
              final leaveDetails = await _leaveService.fetchLeaveApplicationDetails(id);
              if (leaveDetails != null && leaveDetails.reason.trim().isNotEmpty) {
                item['Reason'] = leaveDetails.reason.trim();
              }
            } catch (_) {}
          }
        }),
      );
    } else if (isClaim && list.isNotEmpty) {
      await Future.wait(
        list.map((item) async {
          final id = int.tryParse(item['Key']?.toString() ?? item['ID']?.toString() ?? '0') ?? 0;
          if (id > 0) {
            try {
              final claimDetails = await _claimService.fetchClaimRawDetails(id);
              if (claimDetails != null) {
                final table = claimDetails['Table'] as List?;
                final table1 = claimDetails['Table1'] as List?;
                final remarks = (table != null && table.isNotEmpty)
                    ? table[0]['Remarks']?.toString()
                    : null;
                final reason1 = (table1 != null && table1.isNotEmpty)
                    ? table1[0]['Reason']?.toString()
                    : null;
                final reason = (remarks != null && remarks.isNotEmpty)
                    ? remarks
                    : (reason1 ?? '');
                if (reason.isNotEmpty) {
                  item['Reason'] = reason;
                }
              }
            } catch (_) {}
          }
        }),
      );
    }

    if (mounted) {
      setState(() {
        _userRights = rights;
        if (list.isNotEmpty) {
          _items = list.map((item) {
            final emp = item['EmployeeName']?.toString() ??
                item['Employee']?.toString() ??
                item['EmpName']?.toString() ??
                item['Name']?.toString() ??
                item['UserName']?.toString() ??
                'Applicant';
            final rawDetails = item['Reason']?.toString() ??
                item['Remarks']?.toString() ??
                item['Details']?.toString() ??
                '';
            final cleanDetails =
                (rawDetails.contains('.aspx') || rawDetails.startsWith('..'))
                    ? ''
                    : rawDetails;

            final type = item['ClaimType']?.toString() ??
                item['LeaveType']?.toString() ??
                item['ExpenseType']?.toString() ??
                item['Category']?.toString();

            final claimNo = (item['ClaimNumber'] != null &&
                    item['ClaimNumber'].toString().isNotEmpty &&
                    item['ClaimNumber'].toString() != '0')
                ? item['ClaimNumber'].toString()
                : null;

            final fromDate = item['ClaimDate']?.toString() ??
                item['FromDate']?.toString() ??
                item['Date']?.toString();
            final toDate = item['ToDate']?.toString();
            final branch = item['BranchName']?.toString() ??
                item['Branch']?.toString();
            final amount =
                item['Amount'] != null ? '₹ ${item['Amount']}' : null;

            return {
              'id': int.tryParse(
                      item['Key']?.toString() ?? item['ID']?.toString() ?? '0') ??
                  0,
              'raw': item,
              'applicant': emp,
              'avatar': emp.isNotEmpty ? emp[0].toUpperCase() : 'A',
              'category': widget.title,
              'claimNo': claimNo,
              'type': type,
              'fromDate': fromDate,
              'toDate': toDate,
              'branch': branch,
              'amount': amount,
              'reason': cleanDetails,
              'status': item['Status']?.toString() ?? 'Pending',
            };
          }).toList();
        } else {
          _items = [];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApproval(int id, String action) async {
    final currentItem = _items.firstWhere((element) => element['id'] == id);
    final actionTitle = action == 'A'
        ? 'Approve'
        : action == 'F'
            ? 'Forward'
            : 'Reject';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              action == 'A'
                  ? Icons.check_circle_outline_rounded
                  : action == 'F'
                      ? Icons.forward_rounded
                      : Icons.cancel_outlined,
              color: action == 'A'
                  ? Colors.green
                  : action == 'F'
                      ? AppColors.primary
                      : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text('$actionTitle Request'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to $actionTitle request #$id for ${currentItem['applicant']}?',
            ),
            if (currentItem['reason'] != null &&
                (currentItem['reason'] as String).trim().isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Reason:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentItem['reason'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'A'
                  ? Colors.green
                  : action == 'F'
                      ? AppColors.primary
                      : AppColors.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionTitle),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _processingIds.add(id);
    });

    final messenger = ScaffoldMessenger.of(context);
    bool success = false;
    final titleLower = widget.title.toLowerCase();

    if (widget.menuCode == '19' || titleLower.contains('leave')) {
      success = await _leaveService.approveOrForwardLeave(
        key: id,
        approvalStatus: action,
        itemData: currentItem,
      );
    } else if (widget.menuCode == '15' || titleLower.contains('claim')) {
      success = await _claimService.approveOrForwardClaim(
        key: id,
        approvalStatus: action,
        itemData: currentItem,
      );
    } else if (titleLower.contains('cancel') ||
        titleLower.contains('cancellation')) {
      success = await _leaveService.saveLeaveCancellation(
        lvApplicationId: id.toString(),
        remarks: action == 'A'
            ? 'Approved via Mobile App'
            : action == 'F'
                ? 'Forwarded via Mobile App'
                : 'Rejected via Mobile App',
        approvalStatus: action,
      );
    }

    if (mounted) {
      setState(() {
        _processingIds.remove(id);
        _items.removeWhere((element) => element['id'] == id);
      });

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Request #$id $actionTitle in database successfully!'
                : 'Request #$id marked as $actionTitle.',
          ),
          backgroundColor: action == 'A'
              ? Colors.green
              : action == 'F'
                  ? AppColors.primary
                  : AppColors.error,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text(
                            'No pending requests found',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(context).padding.bottom + 24,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final itemId = item['id'] as int;
                        final isProcessing = _processingIds.contains(itemId);
                        final statusStr =
                            (item['status']?.toString() ?? 'Pending')
                                .trim()
                                .toLowerCase();
                        final isApproved = statusStr == 'approved';
                        final isForwarded = statusStr == 'forwarded';
                        final isRejected = statusStr == 'rejected';
                        final isPending =
                            !isApproved && !isForwarded && !isRejected;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
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
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 18,
                                        backgroundColor:
                                            AppColors.primary.withValues(alpha: 0.1),
                                        child: Text(
                                          item['avatar'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['applicant'],
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            'Request #${item['id']}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isPending
                                          ? Colors.orange.withValues(alpha: 0.1)
                                          : isApproved
                                              ? Colors.green.withValues(alpha: 0.1)
                                              : isForwarded
                                                  ? AppColors.primary.withValues(alpha: 0.1)
                                                  : Colors.red.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      isPending
                                          ? 'Pending'
                                          : isApproved
                                              ? 'Approved'
                                              : isForwarded
                                                  ? 'Forwarded'
                                                  : 'Rejected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: isPending
                                            ? Colors.orange
                                            : isApproved
                                                ? Colors.green
                                                : isForwarded
                                                    ? AppColors.primary
                                                    : Colors.red,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20, color: AppColors.cardBorder),
                              if (item['claimNo'] != null)
                                _DetailInfoRow(label: 'Claim Number', value: item['claimNo'] as String),
                              if (item['type'] != null && (item['type'] as String).isNotEmpty)
                                _DetailInfoRow(
                                  label: (widget.menuCode == '15' || widget.title.toLowerCase().contains('claim'))
                                      ? 'Category'
                                      : 'Type',
                                  value: item['type'] as String,
                                ),
                              if (item['amount'] != null)
                                _DetailInfoRow(label: 'Amount', value: item['amount'] as String),
                              if (item['fromDate'] != null && (item['fromDate'] as String).isNotEmpty)
                                _DetailInfoRow(
                                  label: 'Date',
                                  value: (item['toDate'] != null && item['toDate'] != item['fromDate'])
                                      ? '${item['fromDate']} - ${item['toDate']}'
                                      : item['fromDate'] as String,
                                ),
                              if (item['branch'] != null && (item['branch'] as String).isNotEmpty)
                                _DetailInfoRow(label: 'Branch', value: item['branch'] as String),
                              Builder(
                                builder: (context) {
                                  final isLeaveCategory = widget.menuCode == '19' ||
                                      widget.title.toLowerCase().contains('leave') ||
                                      (item['type'] != null &&
                                          item['type'].toString().toLowerCase().contains('day'));
                                  final reasonVal = (item['reason'] as String?)?.trim() ?? '';

                                  return Container(
                                    width: double.infinity,
                                    margin: const EdgeInsets.only(top: 10),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(
                                            Icons.notes_rounded,
                                            size: 16,
                                            color: AppColors.primary,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isLeaveCategory ? 'Reason for Leave' : 'Remarks / Reason',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                reasonVal.isNotEmpty
                                                    ? reasonVal
                                                    : 'No reason specified',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  fontStyle: reasonVal.isEmpty
                                                      ? FontStyle.italic
                                                      : FontStyle.normal,
                                                  color: reasonVal.isEmpty
                                                      ? AppColors.textMuted
                                                      : AppColors.textPrimary,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                              if (isPending) ...[
                                const SizedBox(height: 16),
                                isProcessing
                                    ? const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2.5),
                                        ),
                                      )
                                    : Builder(
                                        builder: (context) {
                                          final transactions = _userRights?.transactions ?? 3;

                                          // 1 = No Hierarchy: Show convenient info message
                                          if (transactions == 1) {
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                                              ),
                                              child: Row(
                                                children: const [
                                                  Icon(Icons.info_outline_rounded, size: 16, color: Colors.blue),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'No approval hierarchy assigned to your account for this module (Transactions = 1).',
                                                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }

                                          // 2 = Authority to Forward
                                          if (transactions == 2) {
                                            return Row(
                                              children: [
                                                Expanded(
                                                  child: OutlinedButton(
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: AppColors.error,
                                                      side: const BorderSide(color: AppColors.error),
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      minimumSize: const Size(0, 36),
                                                    ),
                                                    onPressed: () => _handleApproval(itemId, 'R'),
                                                    child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    icon: const Icon(Icons.forward_rounded, size: 14),
                                                    label: const Text('Forward', style: TextStyle(fontSize: 12)),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: AppColors.primary,
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                      minimumSize: const Size(0, 36),
                                                    ),
                                                    onPressed: () => _handleApproval(itemId, 'F'),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }

                                          // 3 = Authority to Approve
                                          return Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  style: OutlinedButton.styleFrom(
                                                    foregroundColor: AppColors.error,
                                                    side: const BorderSide(color: AppColors.error),
                                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                                    minimumSize: const Size(0, 36),
                                                  ),
                                                  onPressed: () => _handleApproval(itemId, 'R'),
                                                  child: const Text('Reject', style: TextStyle(fontSize: 12)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  icon: const Icon(
                                                      Icons.check_circle_outline_rounded,
                                                      size: 14),
                                                  label: const Text('Approve',
                                                      style: TextStyle(fontSize: 12)),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors.green,
                                                    padding:
                                                        const EdgeInsets.symmetric(vertical: 8),
                                                    minimumSize: const Size(0, 36),
                                                  ),
                                                  onPressed: () =>
                                                      _handleApproval(itemId, 'A'),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailInfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 12,
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
