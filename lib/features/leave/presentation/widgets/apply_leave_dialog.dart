import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../auth/data/models/user_rights_model.dart';
import '../../../auth/data/services/user_rights_service.dart';
import '../../data/services/leave_service.dart';

class ApplyLeaveDialog extends StatefulWidget {
  final String? initialLeaveId;
  final String? initialLeaveName;

  const ApplyLeaveDialog({
    super.key,
    this.initialLeaveId,
    this.initialLeaveName,
  });

  @override
  State<ApplyLeaveDialog> createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends State<ApplyLeaveDialog> {
  final _leaveService = LeaveService();
  final _userRightsService = UserRightsService();
  final _reasonController = TextEditingController();

  UserRightsModel? _userRights;
  late String _selectedLeaveId; // 1 = Casual Leave, 2 = Sick Leave
  String _selectedLeaveType = '1'; // 1 = Full Day, 2 = Half Day

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  double _calculatedDays = 1.0;
  bool _isCalculating = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _calculationError;

  @override
  void initState() {
    super.initState();
    _selectedLeaveId = widget.initialLeaveId ?? '1';
    _reasonController.addListener(() {
      if (_errorMessage != null && mounted) {
        setState(() => _errorMessage = null);
      }
    });
    _loadUserRights();
    _triggerCalculation();
  }

  Future<void> _loadUserRights() async {
    try {
      final rights = await _userRightsService.fetchUserRights(menuCode: 19);
      if (mounted) {
        setState(() {
          _userRights = rights;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _triggerCalculation() async {
    setState(() {
      _isCalculating = true;
      _calculationError = null;
      _errorMessage = null;
    });

    final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    debugPrint('🔄 [ApplyLeaveDialog] Triggering Calculation: leaveId=$_selectedLeaveId, leaveType=$_selectedLeaveType, from=$fromStr, to=$toStr');

    final result = await _leaveService.calculateLeaveDaysWithValidation(
      leaveId: _selectedLeaveId,
      leaveType: _selectedLeaveType,
      fromDate: fromStr,
      toDate: toStr,
    );

    debugPrint('📊 [ApplyLeaveDialog] Calculation result: days=${result.days}, error=${result.errorMessage}');

    if (mounted) {
      final hasError = result.errorMessage != null && result.errorMessage!.trim().isNotEmpty;
      final errorText = hasError ? result.errorMessage!.trim() : null;

      setState(() {
        _calculatedDays = result.days;
        _calculationError = errorText;
        _isCalculating = false;
      });

      if (errorText != null && errorText.isNotEmpty) {
        _showWarningDialog(
          title: 'warning',
          message: errorText,
        );
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFromDate ? _fromDate : _toDate,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
    );

    if (picked != null) {
      setState(() {
        _errorMessage = null;
        _calculationError = null;
        if (isFromDate) {
          _fromDate = picked;
          if (_toDate.isBefore(_fromDate)) {
            _toDate = _fromDate;
          }
        } else {
          _toDate = picked;
        }
      });
      _triggerCalculation();
    }
  }

  Future<void> _submitLeaveApplication() async {
    if (_isCalculating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Calculating leave days, please wait...'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    // BLOCK SUBMISSION IF THERE IS A CALCULATION ERROR (matching web portal)
    if (_calculationError != null && _calculationError!.isNotEmpty) {
      _showWarningDialog(
        title: 'warning',
        message: _calculationError!,
      );
      return;
    }

    if (_calculatedDays <= 0) {
      _showWarningDialog(
        title: 'warning',
        message: _calculationError ?? 'Invalid leave duration. Please check selected dates.',
      );
      return;
    }

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a reason for your leave.';
      });
      _showNoticeDialog(
        title: 'Reason Required',
        message: 'Please enter a reason for your leave before submitting.',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    final isApproverLevel3 = _userRights?.transactions == 3;

    debugPrint('🚀 [ApplyLeaveDialog] Submitting Leave Application:');
    debugPrint('   Leave ID: $_selectedLeaveId');
    debugPrint('   Leave Type: $_selectedLeaveType');
    debugPrint('   Dates: $fromStr to $toStr ($_calculatedDays days)');
    debugPrint('   Reason: $reason');
    debugPrint('   Approver Level 3: $isApproverLevel3');

    final result = await _leaveService.saveLeaveApplicationWithResult(
      leaveId: _selectedLeaveId,
      leaveType: _selectedLeaveType,
      fromDate: fromStr,
      toDate: toStr,
      noOfLeaves: _calculatedDays.toString(),
      reason: reason,
      approvalStatus: isApproverLevel3 ? 'A' : 'N',
    );

    debugPrint('🏁 [ApplyLeaveDialog] Submission result: success=${result.success}, code=${result.statusCode}');
    debugPrint('🏁 [ApplyLeaveDialog] Error message: ${result.errorMessage}');

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Leave Application submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      final backendMessage = (result.errorMessage != null &&
              result.errorMessage!.trim().isNotEmpty &&
              result.errorMessage!.trim() != '{}' &&
              result.errorMessage!.trim() != '[]')
          ? result.errorMessage!.trim()
          : 'Failed to submit leave application. Please check leave balance or dates.';

      setState(() {
        _errorMessage = backendMessage;
      });

      _showWarningDialog(
        title: 'warning',
        message: backendMessage,
      );
    }
  }

  void _showWarningDialog({
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header bar matching web portal
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => Navigator.pop(dialogCtx),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
            // Body matching web portal: rounded yellow square border with '!' inside
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFFF59E0B),
                        width: 2.5,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '!',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoticeDialog({
    required String title,
    required String message,
    bool isError = true,
  }) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        title: Row(
          children: [
            Icon(
              isError ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
              color: isError ? AppColors.error : AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isError ? AppColors.error : AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom:
              MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Apply For Leave',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Leave (Fixed / Locked based on user selection)
              const Text(
                'Leave',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final String displayName = widget.initialLeaveName ??
                      (_selectedLeaveId == '1'
                          ? 'Casual Leave'
                          : (_selectedLeaveId == '2' ? 'Sick Leave' : 'Leave'));
                  final isSick = _selectedLeaveId == '2' ||
                      displayName.toLowerCase().contains('sick');
                  final isCasual = _selectedLeaveId == '1' ||
                      displayName.toLowerCase().contains('casual');
                  final categoryColor = isSick
                      ? const Color(0xFF0D9488)
                      : (isCasual
                          ? const Color(0xFF1E88E5)
                          : const Color(0xFF7C3AED));
                  final categoryIcon = isSick
                      ? Icons.local_hospital_outlined
                      : (isCasual
                          ? Icons.flight_takeoff_rounded
                          : Icons.calendar_month_outlined);

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: categoryColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          categoryIcon,
                          size: 18,
                          color: categoryColor,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Leave Type Dropdown (matching web portal: Full Day and Half Day)
              const Text(
                'Leave Type',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedLeaveType,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: '1', child: Text('Full Day')),
                  DropdownMenuItem(value: '2', child: Text('Half Day')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _errorMessage = null;
                      _calculationError = null;
                      _selectedLeaveType = val;
                    });
                    _triggerCalculation();
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date Pickers Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'From Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _selectDate(context, true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.cardBorder),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dateFormat.format(_fromDate)),
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'To Date',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () => _selectDate(context, false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.cardBorder),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(dateFormat.format(_toDate)),
                                const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Calculated Days Banner
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _calculationError != null
                      ? const Color(0xFFFEF2F2)
                      : AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: _calculationError != null
                      ? Border.all(color: const Color(0xFFFCA5A5))
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'No of Days:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (_isCalculating)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        '${_calculatedDays % 1 == 0 ? _calculatedDays.toInt() : _calculatedDays} Days',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _calculationError != null
                              ? const Color(0xFFDC2626)
                              : AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reason Text Input
              const Text(
                'Reason for Leave',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _reasonController,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Enter reason'),
              ),
              const SizedBox(height: 18),

              if (_calculationError != null && _calculationError!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFD97706),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _calculationError!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (_errorMessage != null && _errorMessage!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Submit Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_calculationError != null || _calculatedDays <= 0)
                        ? const Color(0xFF9CA3AF)
                        : AppColors.primary,
                  ),
                  onPressed: _isSubmitting ? null : _submitLeaveApplication,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          (_calculationError != null || _calculatedDays <= 0)
                              ? 'Blocked: Leave Exceeded'
                              : 'Submit',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
