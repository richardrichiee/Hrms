import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../data/services/leave_service.dart';

class ApplyLeaveDialog extends StatefulWidget {
  final String? initialLeaveId;

  const ApplyLeaveDialog({super.key, this.initialLeaveId});

  @override
  State<ApplyLeaveDialog> createState() => _ApplyLeaveDialogState();
}

class _ApplyLeaveDialogState extends State<ApplyLeaveDialog> {
  final _leaveService = LeaveService();
  final _reasonController = TextEditingController();

  late String _selectedLeaveId; // 1 = Casual Leave, 2 = Sick Leave
  String _selectedLeaveType = '1'; // 1 = Full Day, 2 = Half Day

  DateTime _fromDate = DateTime.now();
  DateTime _toDate = DateTime.now();

  double _calculatedDays = 1.0;
  bool _isCalculating = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedLeaveId = widget.initialLeaveId ?? '1';
    _triggerCalculation();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _triggerCalculation() async {
    setState(() {
      _isCalculating = true;
    });

    final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    final days = await _leaveService.calculateLeaveDays(
      leaveId: _selectedLeaveId,
      leaveType: _selectedLeaveType,
      fromDate: fromStr,
      toDate: toStr,
    );

    if (mounted) {
      setState(() {
        _calculatedDays = days;
        _isCalculating = false;
      });
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
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a reason for your leave.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final fromStr = DateFormat('yyyy-MM-dd').format(_fromDate);
    final toStr = DateFormat('yyyy-MM-dd').format(_toDate);

    final success = await _leaveService.saveLeaveApplication(
      leaveId: _selectedLeaveId,
      leaveType: _selectedLeaveType,
      fromDate: fromStr,
      toDate: toStr,
      noOfLeaves: _calculatedDays.toString(),
      reason: reason,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave Application submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to submit leave application. Please try again.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
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

              // Leave Category (Fixed / Locked based on user selection)
              const Text(
                'Leave Category',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _selectedLeaveId == '1'
                      ? const Color(0xFF1E88E5).withValues(alpha: 0.08)
                      : const Color(0xFF0D9488).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _selectedLeaveId == '1'
                        ? const Color(0xFF1E88E5).withValues(alpha: 0.25)
                        : const Color(0xFF0D9488).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _selectedLeaveId == '1'
                          ? Icons.flight_takeoff_rounded
                          : Icons.local_hospital_outlined,
                      size: 18,
                      color: _selectedLeaveId == '1'
                          ? const Color(0xFF1E88E5)
                          : const Color(0xFF0D9488),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _selectedLeaveId == '1' ? 'Casual Leave' : 'Sick Leave',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedLeaveId == '1'
                            ? const Color(0xFF1E88E5)
                            : const Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Leave Type Dropdown (Full / Half Day)
              const Text(
                'Leave Duration Type',
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
                  DropdownMenuItem(
                    value: '2',
                    child: Text('Half Day (First Half)'),
                  ),
                  DropdownMenuItem(
                    value: '3',
                    child: Text('Half Day (Second Half)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedLeaveType = val);
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
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
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
                        '$_calculatedDays Days',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
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
              const SizedBox(height: 24),

              // Submit Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
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
                      : const Text('Submit Application'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
