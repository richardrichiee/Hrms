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
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131B2E),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
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
                        'In: ${details['inTime'] ?? '--:--'}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Out: ${details['outTime'] ?? '--:--'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Status: ${details['present'] ?? 'Ab'}',
                        style: const TextStyle(
                          color: Color(0xFF6CF8BB),
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
    final now = DateTime.now();
    final focusedMonth = widget.selectedDate ?? now;
    final monthName = DateFormat('MMMM yyyy').format(focusedMonth);
    final daysInMonth = DateUtils.getDaysInMonth(
      focusedMonth.year,
      focusedMonth.month,
    );
    final firstDayOfWeek =
        DateTime(focusedMonth.year, focusedMonth.month, 1).weekday % 7;

    // Previous month trailing days
    final prevMonthDate = DateTime(focusedMonth.year, focusedMonth.month - 1);
    final prevMonthTotalDays = DateUtils.getDaysInMonth(
      prevMonthDate.year,
      prevMonthDate.month,
    );

    final activeStatusMap = widget.liveDayStatus ?? {};
    final activeDetailsMap = widget.liveDayDetails ?? {};

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
          // 1. Calendar Header with Month Name and Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Row(
                children: [
                  _legendItem(color: AppColors.secondary, label: 'Present'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 2. Weekday Headers (Sun - Sat)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),

          // 3. Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstDayOfWeek + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.05,
              crossAxisSpacing: 2,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              if (index < firstDayOfWeek) {
                final prevDayNumber =
                    prevMonthTotalDays - firstDayOfWeek + index + 1;
                return Center(
                  child: Text(
                    '$prevDayNumber',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted.withValues(alpha: 0.35),
                    ),
                  ),
                );
              }

              final dayNumber = index - firstDayOfWeek + 1;
              final statusColor = activeStatusMap[dayNumber];
              final details = activeDetailsMap[dayNumber];

              final isToday =
                  now.year == focusedMonth.year &&
                  now.month == focusedMonth.month &&
                  now.day == dayNumber;

              final isSelected =
                  widget.selectedDate != null &&
                  widget.selectedDate!.year == focusedMonth.year &&
                  widget.selectedDate!.month == focusedMonth.month &&
                  widget.selectedDate!.day == dayNumber;

              return Builder(
                builder: (cellContext) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isToday
                                ? AppColors.primary
                                : (isSelected
                                      ? AppColors.primary.withValues(
                                          alpha: 0.12,
                                        )
                                      : Colors.transparent),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: (isToday || isSelected)
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isToday
                                  ? Colors.white
                                  : (isSelected
                                        ? AppColors.primary
                                        : AppColors.textPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Status Indicator Dot
                        if (statusColor != null)
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: (statusColor == Colors.green ||
                                      statusColor == AppColors.secondary)
                                  ? AppColors.secondary
                                  : (statusColor == Colors.red ||
                                          statusColor == AppColors.error)
                                      ? AppColors.error
                                      : statusColor,
                              shape: BoxShape.circle,
                            ),
                          )
                        else
                          const SizedBox(height: 6),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _legendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
