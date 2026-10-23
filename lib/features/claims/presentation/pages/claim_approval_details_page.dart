import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../auth/data/models/user_rights_model.dart';
import '../../data/services/claim_service.dart';

class ClaimApprovalDetailsPage extends StatefulWidget {
  final int claimId;
  final Map<String, dynamic> itemData;
  final UserRightsModel? userRights;
  final bool isApprover;

  const ClaimApprovalDetailsPage({
    super.key,
    required this.claimId,
    required this.itemData,
    this.userRights,
    this.isApprover = true,
  });

  @override
  State<ClaimApprovalDetailsPage> createState() =>
      _ClaimApprovalDetailsPageState();
}

class _ClaimApprovalDetailsPageState extends State<ClaimApprovalDetailsPage> {
  final _claimService = ClaimService();

  bool _isLoading = true;
  bool _isProcessing = false;

  Map<String, dynamic>? _headData;
  List<Map<String, dynamic>> _tailItems = [];

  @override
  void initState() {
    super.initState();
    _loadClaimDetails();
  }

  Future<void> _loadClaimDetails() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rawDetails =
          await _claimService.fetchClaimRawDetails(widget.claimId);

      if (rawDetails != null && mounted) {
        final table = rawDetails['Table'] as List?;
        final table1 = rawDetails['Table1'] as List?;

        setState(() {
          if (table != null && table.isNotEmpty) {
            _headData = Map<String, dynamic>.from(table.first as Map);
          }
          if (table1 != null) {
            _tailItems = table1
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAction(String action) async {
    final actionWord = action == 'A'
        ? 'approve'
        : action == 'F'
            ? 'forward'
            : 'reject';

    final applicantName = widget.itemData['applicant']?.toString() ?? 'applicant';
    final amountText = _getFormattedAmount();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Confirm ${action == 'A' ? 'Approval' : action == 'F' ? 'Forward' : 'Rejection'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to $actionWord this claim of $amountText for $applicantName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'A'
                  ? Colors.green
                  : action == 'F'
                      ? AppColors.primary
                      : AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action == 'A' ? 'Approve' : action == 'F' ? 'Forward' : 'Reject'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    final success = await _claimService.approveOrForwardClaim(
      key: widget.claimId,
      approvalStatus: action,
      itemData: widget.itemData,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Claim application ${action == 'A' ? 'approved' : action == 'F' ? 'forwarded' : 'rejected'} successfully!',
            ),
            backgroundColor: action == 'R' ? AppColors.error : Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to process claim. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final claimNo = _getClaimNumber();
    final amountText = _getFormattedAmount();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Claim',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete claim #$claimNo ($amountText)? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isProcessing = true;
    });

    final success = await _claimService.deleteClaim(widget.claimId);

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim application deleted successfully!'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete claim. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _getFormattedAmount() {
    if (_headData != null && _headData!['Amount'] != null) {
      final amt = double.tryParse(_headData!['Amount'].toString()) ?? 0.0;
      return '₹ ${amt.toStringAsFixed(2)}';
    }
    final rawAmt = widget.itemData['amount']?.toString();
    if (rawAmt != null && rawAmt.isNotEmpty) {
      return rawAmt.startsWith('₹') ? rawAmt : '₹ $rawAmt';
    }
    return '₹ 0.00';
  }

  String _getClaimNumber() {
    final fromHead = _headData?['ClaimNumber']?.toString();
    if (fromHead != null && fromHead.isNotEmpty && fromHead != '0') {
      return fromHead;
    }
    final fromItem = widget.itemData['claimNo']?.toString();
    if (fromItem != null && fromItem.isNotEmpty && fromItem != '0') {
      return fromItem;
    }
    return widget.claimId.toString();
  }

  String _getClaimDate() {
    final fromHead = _headData?['ClaimDate']?.toString();
    if (fromHead != null && fromHead.isNotEmpty) {
      return fromHead;
    }
    return widget.itemData['fromDate']?.toString() ??
        widget.itemData['date']?.toString() ??
        'N/A';
  }

  String _getRemarks() {
    final fromHead = _headData?['Remarks']?.toString();
    if (fromHead != null && fromHead.trim().isNotEmpty) {
      return fromHead.trim();
    }
    final fromItem = widget.itemData['reason']?.toString();
    if (fromItem != null && fromItem.trim().isNotEmpty) {
      return fromItem.trim();
    }
    if (_tailItems.isNotEmpty) {
      final firstReason = _tailItems.first['Reason']?.toString();
      if (firstReason != null && firstReason.trim().isNotEmpty) {
        return firstReason.trim();
      }
    }
    return 'None specified';
  }

  String _formatApplicantName(String raw) {
    if (raw.isEmpty) return 'Applicant';
    return raw.replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}').trim();
  }

  @override
  Widget build(BuildContext context) {
    final statusStr = (_headData?['Status']?.toString() ??
            widget.itemData['status']?.toString() ??
            'Pending')
        .trim();
    final isApproved = statusStr.toUpperCase() == 'A' ||
        statusStr.toLowerCase() == 'approved';
    final isRejected = statusStr.toUpperCase() == 'R' ||
        statusStr.toLowerCase() == 'rejected';
    final isForwarded = statusStr.toUpperCase() == 'F' ||
        statusStr.toLowerCase() == 'forwarded' ||
        statusStr.toLowerCase() == 'forward';
    final isPending = !isApproved && !isRejected && !isForwarded;

    final rawApplicant = _headData?['Employee']?.toString() ??
        _headData?['EmployeeName']?.toString() ??
        _headData?['EmpName']?.toString() ??
        widget.itemData['applicant']?.toString() ??
        'Applicant';
    final applicant = _formatApplicantName(rawApplicant);
    final avatarLetter = applicant.isNotEmpty ? applicant[0].toUpperCase() : 'A';
    final branchName = _headData?['Branch']?.toString() ??
        _headData?['BranchName']?.toString() ??
        widget.itemData['branch']?.toString() ??
        'Head Office';
    final claimNo = _getClaimNumber();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isApprover ? 'Claim Approval Details' : 'Claim Details',
              style: const TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              'Claim #$claimNo',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            alignment: Alignment.center,
            child: Text(
              isPending
                  ? 'Pending'
                  : isApproved
                      ? 'Approved'
                      : isForwarded
                          ? 'Forwarded'
                          : 'Rejected',
              style: TextStyle(
                fontSize: 11.5,
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
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 3),
                  SizedBox(height: 14),
                  Text(
                    'Loading claim breakdown...',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadClaimDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: isPending ? 120 : 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Total Amount Hero Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E40AF).withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.receipt_long_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          'Expense Reimbursement',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 12,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getClaimDate(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.9),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Total Claim Amount',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFFBFDBFE),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getFormattedAmount(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Employee & Branch Info Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                          const Text(
                            'APPLICANT INFORMATION',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.6,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.12),
                                child: Text(
                                  avatarLetter,
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      applicant,
                                      style: const TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.business_rounded,
                                          size: 13,
                                          color: AppColors.textMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          branchName,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24, color: AppColors.cardBorder),
                          _DetailRowItem(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Claim Number',
                            value: '#$claimNo',
                          ),
                          const SizedBox(height: 8),
                          _DetailRowItem(
                            icon: Icons.calendar_today_outlined,
                            label: 'Submission Date',
                            value: _getClaimDate(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Remarks Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
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
                          const Row(
                            children: [
                              Icon(
                                Icons.notes_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'PURPOSE & REMARKS',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getRemarks(),
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Expense Line Items Breakdown
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Expense Breakdown (${_tailItems.isNotEmpty ? _tailItems.length : 1})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_tailItems.length} ${_tailItems.length == 1 ? "Item" : "Items"}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (_tailItems.isNotEmpty)
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _tailItems.length,
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final tail = _tailItems[idx];
                          final claimName = tail['ClaimName']?.toString() ??
                              'Expense Item';
                          final lineAmt =
                              double.tryParse(tail['Amount']?.toString() ?? '0') ??
                                  0.0;
                          final dateStr = tail['Date']?.toString() ?? '';
                          final reason = tail['Reason']?.toString() ?? '';
                          final qty =
                              double.tryParse(tail['Qty']?.toString() ?? '0') ?? 0.0;
                          final rate =
                              double.tryParse(tail['Rate']?.toString() ?? '0') ?? 0.0;

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.015),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE9FE),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.receipt_rounded,
                                    size: 20,
                                    color: Color(0xFF7C3AED),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        claimName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (reason.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          reason,
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          if (dateStr.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.access_time_rounded,
                                                  size: 12,
                                                  color: AppColors.textMuted,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  dateStr,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    color: AppColors.textMuted,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          if (qty > 0 && rate > 0)
                                            Text(
                                              'Qty: ${qty % 1 == 0 ? qty.toInt() : qty} × ₹${rate.toStringAsFixed(2)}',
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AppColors.textMuted,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '₹ ${lineAmt.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                widget.itemData['type']?.toString() ??
                                    'Standard claim entry',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                            Text(
                              _getFormattedAmount(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: (isPending && (widget.isApprover || (widget.userRights?.delRight ?? true)))
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 48,
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      )
                    : (widget.isApprover
                        ? Row(
                            children: [
                              // Reject Button
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _handleAction('R'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.error,
                                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                                    backgroundColor: const Color(0xFFFEF2F2),
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.close_rounded, size: 18),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Reject',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Forward button (if transactions == 2)
                              if (widget.userRights?.transactions == 2) ...[
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _handleAction('F'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.primary,
                                      side: const BorderSide(
                                        color: Color(0xFF93C5FD),
                                      ),
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    icon: const Icon(Icons.forward_rounded, size: 18),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Forward',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],

                              // Approve Button
                              Expanded(
                                flex: 1,
                                child: ElevatedButton.icon(
                                  onPressed: () => _handleAction('A'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_rounded, size: 18),
                                  label: const FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Approve',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _handleDelete,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                backgroundColor: const Color(0xFFFEF2F2),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text(
                                'Delete Claim',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )),
              ),
            )
          : null,
    );
  }
}

class _DetailRowItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRowItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
