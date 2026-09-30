import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../dashboard/data/models/branch_model.dart';
import '../../../dashboard/data/services/branch_service.dart';

class BranchLocationSheet extends StatefulWidget {
  const BranchLocationSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BranchLocationSheet(),
    );
  }

  @override
  State<BranchLocationSheet> createState() => _BranchLocationSheetState();
}

class _BranchLocationSheetState extends State<BranchLocationSheet> {
  final _branchService = BranchService();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  List<BranchModel> _branches = [];
  BranchModel? _selectedBranch;
  bool _isLoading = true;
  bool _isLocating = false;
  bool _isSaving = false;
  bool _isUnlockedForEditing = true;

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    setState(() => _isLoading = true);
    final branches = await _branchService.fetchBranches();
    if (mounted) {
      setState(() {
        _branches = branches;
        if (_branches.isNotEmpty) {
          _selectedBranch = _branches.first;
          _updateControllers();
        }
        _isLoading = false;
      });
    }
  }

  void _updateControllers() {
    if (_selectedBranch != null) {
      _latController.text = _selectedBranch!.latitude?.toString() ?? '';
      _lngController.text = _selectedBranch!.longitude?.toString() ?? '';
    }
  }

  Future<void> _captureCurrentLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enable GPS/Location services on your device.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Location permission is required to detect GPS coordinates.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is permanently denied in settings.',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (mounted) {
        setState(() {
          _latController.text = position.latitude.toStringAsFixed(6);
          _lngController.text = position.longitude.toStringAsFixed(6);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Current GPS captured: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error detecting location: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _saveLocation() async {
    final branch = _selectedBranch;
    if (branch == null) return;

    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or capture valid Latitude and Longitude.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final success = await _branchService.saveBranchLocation(
        branchId: branch.value,
        latitude: lat,
        longitude: lng,
        radius: branch.radius ?? 100.0,
      );

      if (!mounted) return;

      if (success) {
        final updatedBranch = BranchModel(
          value: branch.value,
          name: branch.name,
          latitude: lat,
          longitude: lng,
          radius: branch.radius ?? 100.0,
        );
        if (mounted) {
          setState(() {
            _selectedBranch = updatedBranch;
            final idx = _branches.indexWhere((b) => b.value == branch.value);
            if (idx != -1) {
              _branches[idx] = updatedBranch;
            }
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Location saved and locked for ${branch.name}!'),
                ),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, updatedBranch);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save branch location. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isConfigured =
        _selectedBranch != null &&
        _selectedBranch!.latitude != null &&
        _selectedBranch!.longitude != null &&
        _selectedBranch!.latitude != 0.0 &&
        _selectedBranch!.longitude != 0.0;
    final isLocked = isConfigured && !_isUnlockedForEditing;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: _isLoading
          ? const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle Bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Title Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.add_location_alt_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Configure Branch Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Set GPS coordinates for attendance geofencing',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Branch Selector
                const Text(
                  'Select Branch',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.cardBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<BranchModel>(
                      isExpanded: true,
                      value: _selectedBranch,
                      items: _branches.map((b) {
                        final bConfigured = b.latitude != null &&
                            b.longitude != null &&
                            b.latitude != 0.0 &&
                            b.longitude != 0.0;
                        return DropdownMenuItem<BranchModel>(
                          value: b,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  b.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              if (bConfigured)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.lock_rounded, size: 10, color: Colors.green.shade700),
                                      const SizedBox(width: 2),
                                      Text(
                                        'Set',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedBranch = val;
                          _updateControllers();
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Locked / Unlocked Status Banner when coordinates exist
                if (isLocked) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB), // Amber 50
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)), // Amber 200
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF3C7),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.lock_rounded,
                                color: Color(0xFFD97706),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Branch Location Locked',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Coordinates for this branch are configured and locked. Once set, branch location cannot be modified from the mobile app. To update coordinates, please contact your backend administration team.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.35,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isUnlockedForEditing = true;
                              });
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFB45309),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                            ),
                            icon: const Icon(Icons.lock_open_rounded, size: 15),
                            label: const Text(
                              'Unlock to Edit Coordinates',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else if (isConfigured) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5), // Emerald 50
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_location_alt_rounded,
                          color: Color(0xFF059669),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Editing Unlocked: You can modify coordinates or detect device GPS.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _isUnlockedForEditing = false;
                            });
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF059669),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          child: const Text(
                            'Lock',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Backend Radius & Status Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isConfigured
                            ? Icons.lock_rounded
                            : Icons.info_outline_rounded,
                        color: isConfigured ? AppColors.success : Colors.orange,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConfigured
                                  ? 'Coordinates configured (Locked)'
                                  : 'Not yet configured',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: isConfigured
                                    ? AppColors.success
                                    : Colors.orange.shade800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isConfigured
                                  ? 'Branch GPS coordinates set for attendance'
                                  : 'Branch location not yet configured',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Coordinates Row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Latitude',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (isLocked) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _latController,
                            readOnly: isLocked,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            style: TextStyle(
                              color: isLocked ? Colors.grey.shade700 : AppColors.textPrimary,
                              fontWeight: isLocked ? FontWeight.w600 : FontWeight.normal,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 10.0152',
                              isDense: true,
                              filled: isLocked,
                              fillColor: isLocked ? Colors.grey.shade100 : Colors.white,
                              suffixIcon: isLocked
                                  ? const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey)
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.cardBorder,
                                ),
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
                          Row(
                            children: [
                              const Text(
                                'Longitude',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (isLocked) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.lock_rounded, size: 12, color: Colors.grey),
                              ],
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _lngController,
                            readOnly: isLocked,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                              signed: true,
                            ),
                            style: TextStyle(
                              color: isLocked ? Colors.grey.shade700 : AppColors.textPrimary,
                              fontWeight: isLocked ? FontWeight.w600 : FontWeight.normal,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. 76.3524',
                              isDense: true,
                              filled: isLocked,
                              fillColor: isLocked ? Colors.grey.shade100 : Colors.white,
                              suffixIcon: isLocked
                                  ? const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey)
                                  : null,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: AppColors.cardBorder,
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

                // Capture GPS Button (only if not locked)
                if (!isLocked) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLocating ? null : _captureCurrentLocation,
                      icon: _isLocating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.my_location_rounded, size: 18),
                      label: Text(
                        _isLocating
                            ? 'Detecting Location...'
                            : 'Use Current Device Location',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Action Button: Save (if unlocked) or Locked Badge (if locked)
                if (isLocked)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_rounded, size: 18, color: Colors.grey.shade600),
                        const SizedBox(width: 8),
                        Text(
                          'Location Locked (Backend Admin Only)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Save Branch Location',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
    );
  }
}
