import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../attendance/data/models/last_attendance_model.dart';

class TodayPunchHistorySheet extends StatelessWidget {
  final List<LastAttendanceModel> history;
  final bool isLoading;

  const TodayPunchHistorySheet({
    super.key,
    required this.history,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('EEEE, dd MMM yyyy').format(DateTime.now());
    final isCurrentlyIn = history.isNotEmpty && history.first.isCheckedIn;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.86,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.history_toggle_off_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Today's Punch Activity",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 11.5,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            todayStr,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Summary KPI Ribbon
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                // Total Punches Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6.5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fingerprint_rounded,
                        size: 14,
                        color: Color(0xFF475569),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${history.length} ${history.length == 1 ? "Punch" : "Punches"}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Current Status Chip
                if (history.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentlyIn
                          ? const Color(0xFFECFDF5)
                          : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrentlyIn
                            ? const Color(0xFFA7F3D0)
                            : const Color(0xFFFECACA),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrentlyIn
                                ? const Color(0xFF059669)
                                : const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isCurrentlyIn ? 'Clocked In' : 'Clocked Out',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: isCurrentlyIn
                                ? const Color(0xFF047857)
                                : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Earliest In Chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFDCFCE7)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.wb_sunny_outlined,
                          size: 13,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'First: ${history.last.formattedTime}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 14),

          // Content Area
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Loading punch activity...',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (history.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 36),
                child: Column(
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Icon(
                        Icons.fingerprint_rounded,
                        size: 34,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'No Punches Logged Today',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Punches recorded via mobile or web portal will be displayed chronologically here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                itemCount: history.length,
                itemBuilder: (context, index) {
                  final item = history[index];
                  final isIn = item.isCheckedIn;
                  final isLast = index == history.length - 1;

                  final color = isIn
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626);
                  final bgColor = isIn
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2);
                  final borderColor = isIn
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFECACA);

                  final hasExplicitReason =
                      item.reason != null && item.reason!.trim().isNotEmpty;
                  final reasonLower = (item.reason ?? '').toLowerCase();
                  final hasCoordinates =
                      item.latitude != null || item.longitude != null;
                  final isMobilePunch =
                      reasonLower.contains('mobile') ||
                      reasonLower.contains('online') ||
                      hasCoordinates;

                  final displayReason = hasExplicitReason
                      ? item.reason!
                      : (isIn ? 'Web Portal Check In' : 'Web Portal Check Out');

                  final sourceLabel = isMobilePunch ? 'Mobile' : 'Web Portal';
                  final sourceIcon = isMobilePunch
                      ? Icons.smartphone_rounded
                      : Icons.language_rounded;
                  final sourceBgColor = isMobilePunch
                      ? const Color(0xFFF5F3FF)
                      : const Color(0xFFEFF6FF);
                  final sourceTextColor = isMobilePunch
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF1D4ED8);
                  final sourceBorderColor = isMobilePunch
                      ? const Color(0xFFDDD6FE)
                      : const Color(0xFFBFDBFE);

                  final punchNumber = history.length - index;

                  return IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Vertical Timeline Column
                        SizedBox(
                          width: 40,
                          child: Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: borderColor,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.12),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isIn
                                      ? Icons.south_west_rounded
                                      : Icons.north_east_rounded,
                                  color: color,
                                  size: 17,
                                ),
                              ),
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 2,
                                    color: const Color(0xFFE2E8F0),
                                    margin: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Punch Detail Card
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFE2E8F0),
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x060F172A),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Top Row: Status & Punch # on Left, Time on Right
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 3.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: bgColor,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: borderColor,
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Text(
                                              isIn ? 'PUNCH IN' : 'PUNCH OUT',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: color,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '#$punchNumber',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        item.formattedTime,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),

                                  // Bottom Row: Source Badge on Left, Verified badge on Right
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      // Source Badge & (Optional) Custom Reason
                                      Expanded(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 3,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: sourceBgColor,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: sourceBorderColor,
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    sourceIcon,
                                                    size: 11,
                                                    color: sourceTextColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    sourceLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: sourceTextColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (hasExplicitReason &&
                                                !displayReason
                                                    .toLowerCase()
                                                    .contains(
                                                      'web portal check',
                                                    ) &&
                                                !displayReason
                                                    .toLowerCase()
                                                    .contains('mobile check') &&
                                                !displayReason
                                                    .toLowerCase()
                                                    .contains(
                                                      'online check',
                                                    )) ...[
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  displayReason,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.verified_rounded,
                                            size: 12,
                                            color: Color(0xFF10B981),
                                          ),
                                          SizedBox(width: 3),
                                          Text(
                                            'Verified',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF10B981),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
