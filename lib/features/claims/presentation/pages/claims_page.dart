import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../auth/data/models/user_rights_model.dart';
import '../../data/models/claim_models.dart';
import '../../data/services/claim_service.dart';
import '../widgets/apply_claim_dialog.dart';

class ClaimsPage extends StatefulWidget {
  const ClaimsPage({super.key});

  @override
  State<ClaimsPage> createState() => _ClaimsPageState();
}

class _ClaimsPageState extends State<ClaimsPage> {
  final _claimService = ClaimService();

  List<ClaimModel> _claims = [];
  UserRightsModel? _userRights;
  bool _isLoading = true;

  DateTime? _filterFromDate;
  DateTime? _filterToDate;

  @override
  void initState() {
    super.initState();
    _loadClaimsData();
  }

  Future<void> _loadClaimsData() async {
    setState(() => _isLoading = true);
    final rightsFuture = _claimService.fetchClaimUserRights();

    final fDate = _filterFromDate != null
        ? DateFormat('dd/MM/yyyy').format(_filterFromDate!)
        : "";
    final tDate = _filterToDate != null
        ? DateFormat('dd/MM/yyyy').format(_filterToDate!)
        : "";

    // Use EmpSearch endpoint to isolate data to the logged-in employee
    final claimsFuture = _claimService.searchEmployeeClaims(
      fromDate: fDate,
      toDate: tDate,
    );

    final results = await Future.wait([rightsFuture, claimsFuture]);

    if (mounted) {
      setState(() {
        _userRights = results[0] as UserRightsModel?;
        _claims = results[1] as List<ClaimModel>;
        _isLoading = false;
      });
    }
  }

  void _showApplyClaimModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ApplyClaimDialog(),
    ).then((val) {
      if (val == true) {
        _loadClaimsData();
      }
    });
  }

  void _showFilterModal() {
    DateTime? tempFromDate = _filterFromDate;
    DateTime? tempToDate = _filterToDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final fFormatted = tempFromDate != null
                ? DateFormat('dd/MM/yyyy').format(tempFromDate!)
                : 'From Date';
            final tFormatted = tempToDate != null
                ? DateFormat('dd/MM/yyyy').format(tempToDate!)
                : 'To Date';

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
                        'Filter by Claim Date',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (tempFromDate != null || tempToDate != null)
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempFromDate = null;
                              tempToDate = null;
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
                              initialDate: tempFromDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => tempFromDate = picked);
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
                                    fFormatted,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: tempFromDate != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: tempFromDate != null
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
                              initialDate: tempToDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setModalState(() => tempToDate = picked);
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
                                    tFormatted,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: tempToDate != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: tempToDate != null
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
                          _filterFromDate = tempFromDate;
                          _filterToDate = tempToDate;
                        });
                        _loadClaimsData();
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

  void _showClaimDetailsModal(ClaimModel item) {
    final canDelete = _userRights?.delRight ?? true;
    final isPending = item.approvalStatus.toUpperCase() == 'N' ||
        item.approvalStatus.toUpperCase() == 'PENDING';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        Color statusBgColor = Colors.green.withValues(alpha: 0.1);
        Color statusTextColor = Colors.green;
        if (item.approvalStatusText == 'Pending') {
          statusBgColor = Colors.orange.withValues(alpha: 0.1);
          statusTextColor = Colors.orange;
        } else if (item.approvalStatusText == 'Rejected') {
          statusBgColor = Colors.red.withValues(alpha: 0.1);
          statusTextColor = Colors.red;
        } else if (item.approvalStatusText == 'Forward') {
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
                      'Claim Details #${item.id > 0 ? item.id : item.claimNumber}',
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
                        item.approvalStatusText,
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
                if (item.employeeName.isNotEmpty)
                  _DetailRow(
                    label: 'Employee',
                    value: item.employeeName,
                  ),
                _DetailRow(
                  label: 'Submitted Date',
                  value: item.claimDate.isNotEmpty ? item.claimDate : 'Today',
                ),
                _DetailRow(
                  label: 'Total Amount',
                  value: '₹ ${item.amount.toStringAsFixed(2)}',
                ),
                _DetailRow(
                  label: 'Remarks',
                  value: item.remarks.isNotEmpty ? item.remarks : 'None',
                ),
                if (item.tailItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Line Items Breakdown',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...item.tailItems.map((tail) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '• ${tail.claimName} (${tail.reason})',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            ),
                            Text(
                              '₹ ${tail.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                ],
                const SizedBox(height: 20),

                Row(
                  children: [
                    if (canDelete && isPending) ...[
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
                                await _claimService.deleteClaim(item.id);
                            if (mounted && success) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Claim deleted successfully!'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              _loadClaimsData();
                            }
                          },
                          child: const Text('Delete Claim'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
          'Claims & Reimbursements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list_rounded, size: 22),
                if (_filterFromDate != null || _filterToDate != null)
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
            onPressed: _loadClaimsData,
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
                          'You do not have permission (ViewRight) to access Claims & Reimbursements. Please contact your system administrator.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildClaimsView(),
      floatingActionButton: (canView && canAdd)
          ? FloatingActionButton.extended(
              onPressed: _showApplyClaimModal,
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text(
                'Apply Claim',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildClaimsView() {
    double totalClaimed = 0.0;
    double approvedAmount = 0.0;
    for (final claim in _claims) {
      totalClaimed += claim.amount;
      if (claim.approvalStatusText == 'Approved') {
        approvedAmount += claim.amount;
      }
    }

    final fDateFormatted = _filterFromDate != null
        ? DateFormat('dd/MM/yyyy').format(_filterFromDate!)
        : 'From Date';
    final tDateFormatted = _filterToDate != null
        ? DateFormat('dd/MM/yyyy').format(_filterToDate!)
        : 'To Date';

    return RefreshIndicator(
      onRefresh: _loadClaimsData,
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
            // Claims Summary Cards
            Row(
              children: [
                Expanded(
                  child: _ClaimSummaryCard(
                    title: 'Total Claimed',
                    amount: '₹ ${totalClaimed.toStringAsFixed(2)}',
                    icon: Icons.account_balance_wallet_outlined,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ClaimSummaryCard(
                    title: 'Approved Amount',
                    amount: '₹ ${approvedAmount.toStringAsFixed(2)}',
                    icon: Icons.check_circle_outline_rounded,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Active Date Filter Indicator (if filter applied)
            if (_filterFromDate != null || _filterToDate != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined, size: 16, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Filtered: $fDateFormatted - $tDateFormatted',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _filterFromDate = null;
                          _filterToDate = null;
                        });
                        _loadClaimsData();
                      },
                      child: const Icon(Icons.close_rounded, size: 16, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Claim History',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${_claims.length} records',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_claims.isEmpty)
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
                    Icon(Icons.receipt_long_outlined,
                        size: 40, color: AppColors.textMuted),
                    SizedBox(height: 8),
                    Text(
                      'No claims found for this period',
                      style: TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _claims.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _claims[index];
                  final statusLower = item.approvalStatusText.toLowerCase();
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
                    onTap: () => _showClaimDetailsModal(item),
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
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: statusBg,
                                    child: Icon(
                                      Icons.receipt_long_rounded,
                                      size: 18,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.remarks.isNotEmpty
                                            ? item.remarks
                                            : 'Expense Claim',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Claim #${item.id > 0 ? item.id : item.claimNumber}${item.employeeName.isNotEmpty ? " • ${item.employeeName}" : ""}',
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
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item.approvalStatusText,
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
                              height: 20, color: AppColors.cardBorder),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.date_range_outlined,
                                      size: 15, color: AppColors.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.claimDate.isNotEmpty
                                        ? item.claimDate
                                        : 'Today',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '₹ ${item.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimSummaryCard extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final Color color;

  const _ClaimSummaryCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
