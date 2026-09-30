import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class DashboardMetrics extends StatelessWidget {
  final int attendanceCount;
  final String inTime;
  final num leavesTakenCount;
  final bool isCheckedIn;
  final bool isCheckedOut;
  final VoidCallback? onInTimeCardTap;

  const DashboardMetrics({
    super.key,
    this.attendanceCount = 0,
    this.inTime = '09:30 AM',
    this.leavesTakenCount = 0,
    this.isCheckedIn = false,
    this.isCheckedOut = false,
    this.onInTimeCardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Symmetrical 2-Column Row for Monthly Metrics
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: '$attendanceCount',
                unit: 'Days',
                label: 'Attendance',
                sublabel: 'For The Month',
                icon: Icons.calendar_month_outlined,
                iconColor: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                value: (leavesTakenCount % 1 == 0)
                    ? leavesTakenCount.toInt().toString()
                    : leavesTakenCount.toStringAsFixed(1),
                unit: 'Days',
                label: 'Leaves Taken',
                sublabel: 'For The Month',
                icon: Icons.event_busy_outlined,
                iconColor: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Sleek Today's In-Time Status Bar (Interactive to view full punch history)
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onInTimeCardTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.access_time_rounded,
                          color: Color(0xFF10B981),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                "Today's In Time",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (onInTimeCardTap != null) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.history_rounded,
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                              ],
                            ],
                          ),
                          Text(
                            inTime,
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isCheckedIn
                              ? Colors.green.withValues(alpha: 0.1)
                              : isCheckedOut
                              ? Colors.orange.withValues(alpha: 0.12)
                              : Colors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isCheckedIn
                                    ? Colors.green
                                    : isCheckedOut
                                    ? Colors.orange.shade700
                                    : Colors.grey.shade600,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isCheckedIn
                                  ? 'Checked In'
                                  : isCheckedOut
                                  ? 'Checked Out'
                                  : 'Not Checked In',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isCheckedIn
                                    ? Colors.green.shade800
                                    : isCheckedOut
                                    ? Colors.orange.shade800
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onInTimeCardTap != null) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  final String sublabel;
  final IconData icon;
  final Color iconColor;

  const _StatCard({
    required this.value,
    required this.unit,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      unit,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
        ],
      ),
    );
  }
}
