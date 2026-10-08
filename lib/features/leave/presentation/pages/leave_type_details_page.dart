import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/models/leave_application_model.dart';
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
  List<LeaveApplicationModel> _filteredApplications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final user = await LocalStorageService.getUser();
    final currentUserName = user?.userName ?? '';
    final allApps = await _leaveService.fetchLeaveApplications();

    if (mounted) {
      setState(() {
        _filteredApplications = allApps.where((app) {
          final isUser = _isCurrentUser(app.employee, currentUserName);
          if (!isUser) return false;
          final name = app.leaveName.toLowerCase();
          final target = widget.leaveName.toLowerCase();
          return name.contains(target) ||
              (widget.leaveId == '1' && name.contains('casual')) ||
              (widget.leaveId == '2' && name.contains('sick'));
        }).toList();
        _isLoading = false;
      });
    }
  }

  bool _isCurrentUser(String employeeName, String currentUserName) {
    if (currentUserName.trim().isEmpty) return true;
    final cleanEmp =
        employeeName.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    final cleanUser =
        currentUserName.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
    if (cleanEmp.isEmpty || cleanUser.isEmpty) return false;
    return cleanEmp == cleanUser ||
        cleanEmp.contains(cleanUser) ||
        cleanUser.contains(cleanEmp);
  }

  void _openApplyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ApplyLeaveDialog(initialLeaveId: widget.leaveId),
    ).then((_) => _loadApplications());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.leaveName),
      ),
      body: RefreshIndicator(
        onRefresh: _loadApplications,
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
                          label: 'Total Applied',
                          value: '${_filteredApplications.length}',
                          color: widget.color,
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
                    '${widget.leaveName} Applications',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${_filteredApplications.length} found',
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
                    ],
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _filteredApplications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = _filteredApplications[index];
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.fromDate == item.toDate
                                    ? item.fromDate
                                    : '${item.fromDate} - ${item.toDate}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${item.leaveType} • Ref #${item.key}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: widget.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Submitted',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: widget.color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        color: Colors.white,
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
        ),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _openApplyModal,
            icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
            label: Text(
              'Apply for ${widget.leaveName}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
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
            fontSize: 16,
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
