import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../profile/data/models/employee_details_model.dart';
import '../../../profile/data/services/employee_service.dart';
import '../widgets/apply_leave_dialog.dart';

class ApplyLeavePage extends StatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _employeeService = EmployeeService();
  List<LeaveBalanceItem>? _leaveBalances;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBalances();
  }

  Future<void> _loadBalances() async {
    final details = await _employeeService.fetchEmployeeDashboard();
    if (mounted) {
      setState(() {
        _leaveBalances = details?.leaveBalances ?? [];
        _isLoading = false;
      });
    }
  }

  String _formatBalance(int leaveId) {
    if (_isLoading) return 'Loading...';
    if (_leaveBalances == null || _leaveBalances!.isEmpty) return '0 Days';
    final match = _leaveBalances!.firstWhere(
      (b) => b.leaveId == leaveId,
      orElse: () => LeaveBalanceItem(leaveId: 0, leaveName: '', closing: 0.0),
    );
    final val = match.closing;
    if (val % 1 == 0) {
      return '${val.toInt()} ${val == 1 ? "Day" : "Days"}';
    }
    return '$val Days';
  }

  void _openApplyModal(BuildContext context, String leaveId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ApplyLeaveDialog(initialLeaveId: leaveId),
    ).then((result) {
      if (context.mounted && result == true) {
        Navigator.pop(context, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply Leave')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Leave Category',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose the type of leave you wish to apply for',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Casual Leave Card
            _LeaveCategoryCard(
              title: 'Casual Leave',
              balanceText: _formatBalance(1),
              icon: Icons.flight_takeoff_rounded,
              color: const Color(0xFF1E88E5),
              onTap: () => _openApplyModal(context, '1'),
            ),
            const SizedBox(height: 14),

            // Sick Leave Card
            _LeaveCategoryCard(
              title: 'Sick Leave',
              balanceText: _formatBalance(2),
              icon: Icons.local_hospital_outlined,
              color: const Color(0xFF0D9488),
              onTap: () => _openApplyModal(context, '2'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LeaveCategoryCard extends StatelessWidget {
  final String title;
  final String balanceText;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _LeaveCategoryCard({
    required this.title,
    required this.balanceText,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: color.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Balance: ',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              balanceText,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
