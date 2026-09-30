import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
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

  const LeaveBalanceChart({
    super.key,
    this.items,
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
    if (widget.items != null && widget.items!.isNotEmpty) {
      return widget.items!;
    }
    return [
      LeaveSummaryItem(
        leaveName: 'Casual Leave',
        totalLeaves: 0,
        employeesTaken: 0,
        balanceLeaves: 0,
        color: const Color(0xFF1E88E5),
      ),
      LeaveSummaryItem(
        leaveName: 'Sick Leave',
        totalLeaves: 0,
        employeesTaken: 0,
        balanceLeaves: 0,
        color: const Color(0xFFE53935),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final totalTaken = data.fold(0.0, (sum, item) => sum + item.employeesTaken);

    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar with light purple/blue background
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFE8E5F8), // Soft purple matching web portal
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Leave Balances',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2C2459),
                  ),
                ),
                // Toggle Button between Pie Chart and Table View
                InkWell(
                  onTap: () {
                    setState(() {
                      _isTableView = !_isTableView;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF2C2459).withValues(alpha: 0.2),
                      ),
                    ),
                    child: Icon(
                      _isTableView
                          ? Icons.pie_chart_rounded
                          : Icons.table_chart_outlined,
                      size: 18,
                      color: const Color(0xFF2C2459),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Area (Pie Chart OR Table View)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _isTableView ? _buildTableView(data) : _buildChartView(data, totalTaken),
          ),
        ],
      ),
    );
  }

  Widget _buildChartView(List<LeaveSummaryItem> data, double totalTaken) {
    final pieTotal = data.fold(
        0.0,
        (sum, item) =>
            sum +
            (item.balanceLeaves > 0
                ? item.balanceLeaves
                : (item.totalLeaves > 0 ? item.totalLeaves : item.employeesTaken)));

    if (pieTotal == 0) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 38, color: Colors.blue.withValues(alpha: 0.7)),
              const SizedBox(height: 8),
              const Text(
                'No Leave Balances Recorded',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 0,
              startDegreeOffset: -90,
              sections: data.map((item) {
                final itemVal = item.balanceLeaves > 0
                    ? item.balanceLeaves
                    : (item.totalLeaves > 0 ? item.totalLeaves : 1.0);
                final percentage = pieTotal > 0
                    ? (itemVal / pieTotal) * 100
                    : (100 / data.length);

                return PieChartSectionData(
                  color: item.color,
                  value: itemVal > 0 ? itemVal : 1,
                  title:
                      '${(percentage % 1 == 0) ? percentage.toInt().toString() : percentage.toStringAsFixed(1)}%',
                  radius: 70,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Legend Row
        Wrap(
          spacing: 20,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: data.map((item) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: item.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.leaveName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        // Metrics Summary Cards (Total Leaves, Leaves Taken, Balance Leaves)
        Row(
          children: data.map((item) {
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: item.color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.leaveName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: item.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Leaves',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                        Text(
                          _formatNum(item.totalLeaves),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Leaves Taken',
                          style: TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                        Text(
                          _formatNum(item.employeesTaken),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Balance Leaves',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _formatNum(item.balanceLeaves),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: item.balanceLeaves > 0
                                ? AppColors.primary
                                : AppColors.error,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTableView(List<LeaveSummaryItem> data) {
    return Column(
      children: [
        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: const [
              Expanded(
                flex: 4,
                child: Text(
                  'Leave',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Total Leaves',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Employees Taken',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Balance Leaves',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),

        // Table Rows
        ...data.map((item) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.cardBorder, width: 0.8),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
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
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.leaveName,
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
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatNum(item.totalLeaves),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatNum(item.employeesTaken),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    _formatNum(item.balanceLeaves),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: item.balanceLeaves > 0
                          ? AppColors.primary
                          : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
