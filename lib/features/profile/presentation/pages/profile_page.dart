import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../dashboard/data/models/branch_model.dart';
import '../../../dashboard/data/services/branch_service.dart';
import '../../data/models/employee_details_model.dart';
import '../../data/services/employee_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _employeeService = EmployeeService();
  final _branchService = BranchService();

  UserModel? _user;
  EmployeeDetailsModel? _employeeDetails;
  String? _branchName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _employeeService.fetchEmployeeDashboard(),
        LocalStorageService.getUser(),
        _branchService.fetchBranches(),
        LocalStorageService.getSelectedBranchId(),
      ]);

      final details = results[0] as EmployeeDetailsModel?;
      final user = results[1] as UserModel?;
      final branches = results[2] as List<BranchModel>;
      final savedBranchId = results[3] as int?;

      String? branchName = user?.branchName;
      if (branchName == null || branchName.isEmpty) {
        final defId = (user != null && user.branchId > 0)
            ? user.branchId
            : savedBranchId;
        if (branches.isNotEmpty) {
          if (defId != null) {
            final match = branches.firstWhere(
              (b) => b.id == defId,
              orElse: () => branches.first,
            );
            branchName = match.name;
          } else {
            branchName = branches.first.name;
          }
        }
      }

      if (mounted) {
        setState(() {
          _employeeDetails = details;
          _user = user;
          _branchName = branchName;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String get _userName {
    if (_employeeDetails != null && _employeeDetails!.name.isNotEmpty) {
      return _employeeDetails!.name;
    }
    if (_user != null && _user!.userName.isNotEmpty) {
      return _user!.userName;
    }
    return 'Employee';
  }

  String get _userDesignation {
    if (_employeeDetails != null && _employeeDetails!.designation.isNotEmpty) {
      return _employeeDetails!.designation;
    }
    return 'Team Member';
  }

  String get _userAvatarLetter {
    final name = _userName.trim();
    if (name.isNotEmpty) {
      return name[0].toUpperCase();
    }
    return 'U';
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Sign Out'),
          content: const Text(
            'Are you sure you want to sign out from your account?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await LocalStorageService.clearUserSession();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully.'),
            backgroundColor: AppColors.textPrimary,
          ),
        );
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone = _employeeDetails?.phoneNumber ?? '';
    final email = _employeeDetails?.email ?? '';
    final address = _employeeDetails?.contactAddress ?? '';
    final employmentType = _employeeDetails?.employmentType ?? '';
    final doj = _employeeDetails?.doj ?? '';
    final empCode = _employeeDetails?.empCode.isNotEmpty == true
        ? _employeeDetails!.empCode
        : (_employeeDetails?.empId != null && _employeeDetails!.empId > 0
            ? 'EMP-${_employeeDetails!.empId.toString().padLeft(4, '0')}'
            : 'EMP-0026');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Color(0xFF0F172A),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go('/dashboard');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            onPressed: () => context.go('/settings'),
            tooltip: 'Settings',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 16.0,
                  right: 16.0,
                  top: 16.0,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Top Profile Hero Card matching Dashboard/Drawer
                    _buildProfileHeroCard(empCode),
                    const SizedBox(height: 20),

                    // 2. Company Profile
                    _buildSectionHeader('COMPANY PROFILE'),
                    const SizedBox(height: 8),
                    _ProfileGroupCard(
                      children: [
                        _ProfileInfoRow(
                          icon: Icons.badge_outlined,
                          iconBg: const Color(0xFFEFF6FF),
                          iconColor: AppColors.primary,
                          label: 'Employee Code',
                          value: empCode,
                        ),
                        const _ProfileDivider(),
                        _ProfileInfoRow(
                          icon: Icons.work_outline_rounded,
                          iconBg: const Color(0xFFEEF2FF),
                          iconColor: Colors.indigo,
                          label: 'Designation / Role',
                          value: _userDesignation,
                        ),
                        if (employmentType.isNotEmpty) ...[
                          const _ProfileDivider(),
                          _ProfileInfoRow(
                            icon: Icons.business_center_outlined,
                            iconBg: const Color(0xFFFEF3C7),
                            iconColor: const Color(0xFFD97706),
                            label: 'Employment Type',
                            value: employmentType,
                          ),
                        ],
                        if (_branchName != null && _branchName!.isNotEmpty) ...[
                          const _ProfileDivider(),
                          _ProfileInfoRow(
                            icon: Icons.storefront_rounded,
                            iconBg: const Color(0xFFECFEFF),
                            iconColor: const Color(0xFF0891B2),
                            label: 'Branch / Location',
                            value: _branchName!,
                          ),
                        ],
                        if (doj.isNotEmpty) ...[
                          const _ProfileDivider(),
                          _ProfileInfoRow(
                            icon: Icons.calendar_month_outlined,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            label: 'Date of Joining',
                            value: doj,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 4. Contact & Address
                    _buildSectionHeader('CONTACT & COMMUNICATION'),
                    const SizedBox(height: 8),
                    _ProfileGroupCard(
                      children: [
                        if (email.isNotEmpty) ...[
                          _ProfileInfoRow(
                            icon: Icons.mail_outline_rounded,
                            iconBg: const Color(0xFFEFF6FF),
                            iconColor: AppColors.primary,
                            label: 'Email Address',
                            value: email,
                          ),
                        ],
                        if (phone.isNotEmpty) ...[
                          if (email.isNotEmpty) const _ProfileDivider(),
                          _ProfileInfoRow(
                            icon: Icons.phone_outlined,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            label: 'Phone Number',
                            value: phone,
                          ),
                        ],
                        if (address.isNotEmpty) ...[
                          if (email.isNotEmpty || phone.isNotEmpty)
                            const _ProfileDivider(),
                          _ProfileInfoRow(
                            icon: Icons.location_on_outlined,
                            iconBg: const Color(0xFFFFF1F2),
                            iconColor: const Color(0xFFE11D48),
                            label: 'Office Address',
                            value: address,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 5. Sign Out Card matching Drawer
                    _buildSignOutTile(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeroCard(String empCode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar Squircle matching Dashboard & Drawer
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.22),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _userAvatarLetter,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name & Designation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _userDesignation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badge (Employee Code)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        empCode,
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }



  Widget _buildSignOutTile(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleLogout(context),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFEE2E2)),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFDC2626),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF991B1B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'End current session securely',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFB91C1C),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
          color: Color(0xFF94A3B8),
        ),
      ),
    );
  }
}

class _ProfileGroupCard extends StatelessWidget {
  final List<Widget> children;
  const _ProfileGroupCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileDivider extends StatelessWidget {
  const _ProfileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 14,
      color: Color(0xFFF1F5F9),
    );
  }
}
