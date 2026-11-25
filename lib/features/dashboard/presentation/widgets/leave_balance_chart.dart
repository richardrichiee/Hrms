import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';

class LeaveSummaryItem {
  final String leaveName;
  final double totalLeaves;
  final double employeesTaken;
  final double balanceLeaves;
  final Color color;

  LeaveSummaryItem({
    required this.leaveName,
    required this.totalLeaves,
    required this.employeesTaken,
    double? balanceLeaves,
    required this.color,
  }) : balanceLeaves = balanceLeaves ??
            ((totalLeaves - employeesTaken) > 0
                ? (totalLeaves - employeesTaken)
                : 0);
}

class LeaveBalanceChart extends StatefulWidget {
  final List<LeaveSummaryItem>? items;
  final bool showApplyLeave;

  const LeaveBalanceChart({
    super.key,
    this.items,
    this.showApplyLeave = true,
  });

  @override
  State<LeaveBalanceChart> createState() => _LeaveBalanceChartState();
}

class _LeaveBalanceChartState extends State<LeaveBalanceChart> {
  bool _isTableView = false;

  String _formatNum(double val) {
    if (val % 1 == 0) return val.toInt().toString();
    return val.toStringAsFixed(1);
  }

  List<LeaveSummaryItem> get _data {
    if (widget.items != null) {
      return widget.items!;
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final totalBalance = data.fold(0.0, (sum, item) => sum + item.balanceLeaves);

    return Container(
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
          // 1. Header with Title and Segmented Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Leave Balance',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              // Segmented Toggle Pill [Chart | Table]
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (_isTableView) setState(() => _isTableView = false);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: !_isTableView ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: !_isTableView
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Chart',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: !_isTableView
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        if (!_isTableView) setState(() => _isTableView = true);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _isTableView ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _isTableView
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          'Table',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _isTableView
                                ? AppColors.primary
                                : AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Main Content (Donut Chart View OR Table View)
          _isTableView ? _buildTableView(data) : _buildDonutChartView(data, totalBalance),

          if (widget.showApplyLeave) ...[
            const Divider(height: 24, color: AppColors.cardBorder),

            // 3. Action Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                InkWell(
                  onTap: () => context.push('/leave'),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: const [
                        Text(
                          'Apply Leave',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 15,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDonutChartView(List<LeaveSummaryItem> data, double totalBalance) {
    if (totalBalance == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: const Text(
          'No leave balances recorded',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut Chart with Centered Total Days
        SizedBox(
          width: 104,
          height: 104,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 2.5,
                  centerSpaceRadius: 33,
                  startDegreeOffset: -90,
                  sections: data.map((item) {
                    final val = item.balanceLeaves > 0 ? item.balanceLeaves : 0.1;
                    return PieChartSectionData(
                      color: item.color,
                      value: val,
                      showTitle: false,
                      radius: 12,
                    );
                  }).toList(),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatNum(totalBalance),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Days',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Legend Breakdown List (Fully Responsive)
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: data.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.leaveName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatNum(item.balanceLeaves)} d',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTableView(List<LeaveSummaryItem> data) {
    if (data.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: const Text(
          'No leave balances recorded',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2.0),
          1: FlexColumnWidth(1.0),
          2: FlexColumnWidth(1.0),
          3: FlexColumnWidth(1.0),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFF2F3FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Text(
                  'Type',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  'Total',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  'Taken',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text(
                  'Bal',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          ...data.map((item) {
            return TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.leaveName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    _formatNum(item.totalLeaves),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    _formatNum(item.employeesTaken),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  child: Text(
                    _formatNum(item.balanceLeaves),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
