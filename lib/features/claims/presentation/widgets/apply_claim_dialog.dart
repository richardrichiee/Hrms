import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../auth/data/models/user_rights_model.dart';
import '../../../auth/data/services/user_rights_service.dart';
import '../../data/models/claim_models.dart';
import '../../data/services/claim_service.dart';

class ApplyClaimDialog extends StatefulWidget {
  const ApplyClaimDialog({super.key});

  @override
  State<ApplyClaimDialog> createState() => _ApplyClaimDialogState();
}

class _ApplyClaimDialogState extends State<ApplyClaimDialog> {
  final _claimService = ClaimService();
  final _userRightsService = UserRightsService();
  final _remarksController = TextEditingController();
  final _rateController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _reasonController = TextEditingController();

  DateTime _claimDate = DateTime.now();
  DateTime _itemDate = DateTime.now();

  List<ClaimMasterItem> _categories = [];
  ClaimMasterItem? _selectedCategory;
  UserRightsModel? _userRights;

  final List<ClaimTailItem> _tailItems = [];
  bool _isLoadingCategories = true;
  bool _isSubmitting = false;
  bool _isRateStatic = false;
  String _currentRateFlag = '0';

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadUserRights();
  }

  Future<void> _loadUserRights() async {
    try {
      final rights = await _userRightsService.fetchUserRights(menuCode: 15);
      if (mounted) {
        setState(() {
          _userRights = rights;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _rateController.dispose();
    _qtyController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final list = await _claimService.fetchClaimCategories();
    if (mounted) {
      setState(() {
        _categories = list;
        if (_categories.isNotEmpty) {
          _selectedCategory = _categories.first;
          _fetchRateForCategory(_selectedCategory!.value.toString());
        }
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _fetchRateForCategory(String claimId) async {
    final res = await _claimService.getClaimRate(claimId);
    if (mounted) {
      setState(() {
        _isRateStatic = (res.rateFlag == 1);
        _currentRateFlag = res.rateFlag.toString();
        if (_isRateStatic) {
          _rateController.text = res.rate.toStringAsFixed(0);
        } else {
          if (res.rate > 0) {
            _rateController.text = res.rate.toStringAsFixed(0);
          } else {
            _rateController.text = '';
          }
        }
      });
    }
  }

  double get _currentItemAmount {
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final qty = double.tryParse(_qtyController.text) ?? 0.0;
    return rate * qty;
  }

  double get _totalClaimAmount {
    return _tailItems.fold(0.0, (sum, item) => sum + item.amount);
  }

  void _addLineItem() {
    final reason = _reasonController.text.trim();
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an expense category')),
      );
      return;
    }
    if (_currentItemAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid rate and quantity')),
      );
      return;
    }

    final dateStr = DateFormat('dd/MM/yyyy').format(_itemDate);
    final rate = double.tryParse(_rateController.text) ?? 0.0;
    final qty = _qtyController.text.trim();

    setState(() {
      _tailItems.add(
        ClaimTailItem(
          claimId: _selectedCategory!.value.toString(),
          claimName: _selectedCategory!.name,
          amount: _currentItemAmount,
          rate: rate,
          rateFlag: _currentRateFlag,
          qty: qty.isNotEmpty ? qty : '1',
          reason: reason.isNotEmpty ? reason : _selectedCategory!.name,
          date: dateStr,
        ),
      );

      // Reset item inputs
      _reasonController.clear();
      _qtyController.text = '1';
      if (!_isRateStatic) {
        _rateController.clear();
      }
    });
  }

  Future<void> _submitClaim() async {
    if (_tailItems.isEmpty) {
      if (_selectedCategory != null && _currentItemAmount > 0) {
        final dateStr = DateFormat('dd/MM/yyyy').format(_itemDate);
        final rate = double.tryParse(_rateController.text) ?? 0.0;
        final qty = _qtyController.text.trim();
        final reason = _reasonController.text.trim();

        _tailItems.add(
          ClaimTailItem(
            claimId: _selectedCategory!.value.toString(),
            claimName: _selectedCategory!.name,
            amount: _currentItemAmount,
            rate: rate,
            rateFlag: _currentRateFlag,
            qty: qty.isNotEmpty ? qty : '1',
            reason: reason.isNotEmpty ? reason : _selectedCategory!.name,
            date: dateStr,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an expense category and amount before submitting.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    final claimDateStr = DateFormat('dd/MM/yyyy').format(_claimDate);
    final remarks = _remarksController.text.trim().isNotEmpty
        ? _remarksController.text.trim()
        : 'Expense claim application';

    final isApproverLevel3 = _userRights?.transactions == 3;

    debugPrint('====================================================');
    debugPrint('📝 [ApplyClaimDialog] User tapped Submit Claim:');
    debugPrint('   Date: $claimDateStr, Total: ₹$_totalClaimAmount, Remarks: $remarks');
    debugPrint('   Approver Level 3 (Manager): $isApproverLevel3');
    debugPrint('   Tail Items Count: ${_tailItems.length}');

    final result = await _claimService.saveClaimFormWithResult(
      claimDate: claimDateStr,
      remarks: remarks,
      totalAmount: _totalClaimAmount,
      tailItems: _tailItems,
      approvalStatus: isApproverLevel3 ? 'A' : 'N',
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (result.success) {
        Navigator.pop(context, true);
        final isApprover = result.approvalStatus == 'A' || _userRights?.transactions == 3;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isApprover
                  ? 'Claim Application approved successfully!'
                  : 'Claim Application submitted successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        final errorMsg = result.errorMessage ?? 'Failed to submit claim. Please try again.';
        debugPrint('❌ [ApplyClaimDialog] Showing Error SnackBar: $errorMsg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
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
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom +
              MediaQuery.of(context).padding.bottom +
              20,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _isLoadingCategories
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Apply Claim Form',
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

                    // Header Info: Claim Date & Remarks
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Claim Date',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _claimDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (picked != null) {
                                    setState(() => _claimDate = picked);
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppColors.cardBorder),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        dateFormat.format(_claimDate),
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                      const Icon(Icons.calendar_today_rounded,
                                          size: 16, color: AppColors.primary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'General Remarks',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _remarksController,
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Line Item Box
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Add Expense Item',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Item Date & Category Dropdown
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _itemDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                    );
                                    if (picked != null) {
                                      setState(() => _itemDate = picked);
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 12),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppColors.cardBorder),
                                      borderRadius: BorderRadius.circular(10),
                                      color: Colors.white,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          dateFormat.format(_itemDate),
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const Icon(Icons.calendar_today_rounded,
                                            size: 14, color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<ClaimMasterItem>(
                                  initialValue: _selectedCategory,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: _categories.map((cat) {
                                    return DropdownMenuItem(
                                      value: cat,
                                      child: Text(cat.name, style: const TextStyle(fontSize: 12)),
                                    );
                                  }).toList(),
                                  onChanged: (cat) {
                                    if (cat != null) {
                                      setState(() => _selectedCategory = cat);
                                      _fetchRateForCategory(cat.value.toString());
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // Rate & Qty & Calculated Amount
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _rateController,
                                  readOnly: _isRateStatic,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: _isRateStatic
                                        ? 'Rate (Fixed)'
                                        : 'Rate (₹)',
                                    prefixIcon: _isRateStatic
                                        ? const Icon(
                                            Icons.lock_rounded,
                                            size: 16,
                                            color: AppColors.textMuted,
                                          )
                                        : null,
                                    filled: _isRateStatic,
                                    fillColor: _isRateStatic
                                        ? const Color(0xFFF1F5F9)
                                        : null,
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _qtyController,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Qty',
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Amount',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.primary)),
                                    Text(
                                      '₹ ${_currentItemAmount.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          TextField(
                            controller: _reasonController,
                            decoration: const InputDecoration(
                              labelText: 'Item Description / Reason',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                          const SizedBox(height: 12),

                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _addLineItem,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('+ Add Expense Item'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Added Line Items Table / List
                    if (_tailItems.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Added Items (${_tailItems.length})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Total: ₹ ${_totalClaimAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._tailItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.claimName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    '${item.reason} (Qty: ${item.qty} × ₹${item.rate.toStringAsFixed(0)})',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '₹ ${item.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline,
                                        size: 18, color: AppColors.error),
                                    onPressed: () {
                                      setState(() {
                                        _tailItems.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitClaim,
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
                                _tailItems.isEmpty
                                    ? 'Submit Claim'
                                    : 'Submit Claim (₹ ${_totalClaimAmount.toStringAsFixed(2)})',
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
