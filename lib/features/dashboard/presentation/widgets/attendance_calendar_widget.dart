import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';

class AttendanceCalendarWidget extends StatefulWidget {
  final Map<int, Color>? liveDayStatus;
  final Map<int, Map<String, String>>? liveDayDetails;
  final DateTime? selectedDate;
  final ValueChanged<DateTime>? onDateSelected;

  const AttendanceCalendarWidget({
    super.key,
    this.liveDayStatus,
    this.liveDayDetails,
    this.selectedDate,
    this.onDateSelected,
  });

  @override
  State<AttendanceCalendarWidget> createState() =>
      _AttendanceCalendarWidgetState();
}

class _AttendanceCalendarWidgetState extends State<AttendanceCalendarWidget> {
  void _showDayTooltip(
    BuildContext context,
    int dayNumber,
    Map<String, String> details,
  ) {
    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);

    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => overlayEntry.remove(),
        child: Stack(
          children: [
            Positioned(
              left: (position.dx - 20).clamp(
                16.0,
                MediaQuery.of(context).size.width - 160,
              ),
              top: (position.dy - 75).clamp(
                40.0,
                MediaQuery.of(context).size.height - 100,
              ),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'In: ${details['inTime'] ?? 'Ab'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Out: ${details['outTime'] ?? 'Ab'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: ${details['present'] ?? 'Ab'}',
                        style: const TextStyle(
                          color: Color(0xFFFACC15),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final focusedMonth = widget.selectedDate ?? DateTime.now();
    final monthName = DateFormat('MMMM yyyy').format(focusedMonth);
    final daysInMonth = DateUtils.getDaysInMonth(
      focusedMonth.year,
      focusedMonth.month,
    );
    final firstDayOfWeek =
        DateTime(focusedMonth.year, focusedMonth.month, 1).weekday % 7;

    final activeStatusMap = widget.liveDayStatus ?? {};
    final activeDetailsMap = widget.liveDayDetails ?? {};

    return Container(
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
              Text(
                monthName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _legendItem(color: Colors.green, label: 'Present'),
                  const SizedBox(width: 8),
                  _legendItem(color: Colors.red, label: 'Absent/Leave'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Day Headers (Sun - Sat)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstDayOfWeek + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.1,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOfWeek) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - firstDayOfWeek + 1;
              final statusColor = activeStatusMap[dayNumber];
              final details = activeDetailsMap[dayNumber];

              final isSelected =
                  widget.selectedDate != null &&
                  widget.selectedDate!.year == focusedMonth.year &&
                  widget.selectedDate!.month == focusedMonth.month &&
                  widget.selectedDate!.day == dayNumber;

              final tooltipText = details != null
                  ? "In: ${details['inTime']}\nOut: ${details['outTime']}\nStatus: ${details['present']}"
                  : (statusColor != null
                        ? (statusColor == Colors.green ? 'Present' : 'Absent')
                        : 'Day $dayNumber');

              return Tooltip(
                message: tooltipText,
                child: Builder(
                  builder: (cellContext) {
                    return GestureDetector(
                      onTap: () {
                        if (details != null) {
                          _showDayTooltip(cellContext, dayNumber, details);
                        }
                        widget.onDateSelected?.call(
                          DateTime(
                            focusedMonth.year,
                            focusedMonth.month,
                            dayNumber,
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.12)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? Border.all(color: AppColors.primary, width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            if (statusColor != null)
                              Container(
                                width: 3,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(6),
                                    bottomLeft: Radius.circular(6),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 3),
                            Expanded(
                              child: Center(
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? AppColors.primary
                                        : (statusColor != null
                                              ? AppColors.textPrimary
                                              : AppColors.textSecondary),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
