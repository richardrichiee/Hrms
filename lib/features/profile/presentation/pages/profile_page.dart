import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../data/models/employee_details_model.dart';
import '../../data/services/employee_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _employeeService = EmployeeService();
  UserModel? _user;
  EmployeeDetailsModel? _employeeDetails;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final details = await _employeeService.fetchEmployeeDashboard();
    final user = await LocalStorageService.getUser();
    if (mounted) {
      setState(() {
        _employeeDetails = details;
        _user = user;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out of your session?'),
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
              child: const Text('Logout'),
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
            content: Text('Logged out successfully.'),
            backgroundColor: AppColors.textPrimary,
          ),
        );
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _employeeDetails?.name.isNotEmpty == true
        ? _employeeDetails!.name
        : (_user?.userName.isNotEmpty == true ? _user!.userName : 'Employee');
    final designation = _employeeDetails?.designation.isNotEmpty == true
        ? _employeeDetails!.designation
        : 'Team Member';
    final phone = _employeeDetails?.phoneNumber ?? '';
    final email = _employeeDetails?.email ?? '';
    final address = _employeeDetails?.contactAddress ?? '';
    final employmentType = _employeeDetails?.employmentType ?? '';
    final doj = _employeeDetails?.doj ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProfileData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(
                  left: 20.0,
                  right: 20.0,
                  top: 20.0,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Column(
                  children: [
                    // Profile Header Card (Avatar + Centered Name matching Web)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Web-style avatar with outer blue circle & dark silhouette
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF6B8AFD),
                                width: 2.5,
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF384967),
                              ),
                              child: const Icon(
                                Icons.person,
                                size: 58,
                                color: Color(0xFFE2E8F0),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Web Profile Details List
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          if (designation.isNotEmpty) ...[
                            _WebProfileRow(
                              icon: Icons.account_tree_outlined,
                              text: designation,
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ],
                          if (phone.isNotEmpty) ...[
                            _WebProfileRow(
                              icon: Icons.phone_outlined,
                              text: phone,
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ],
                          if (email.isNotEmpty) ...[
                            _WebProfileRow(
                              icon: Icons.mail_outline_rounded,
                              text: email,
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ],
                          if (address.isNotEmpty) ...[
                            _WebProfileRow(
                              icon: Icons.location_on_outlined,
                              text: address,
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ],
                          if (employmentType.isNotEmpty) ...[
                            _WebProfileRow(
                              icon: Icons.business_center_outlined,
                              text: employmentType,
                            ),
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          ],
                          if (doj.isNotEmpty) ...[
                            _WebProfileRow(
                              icon: Icons.calendar_today_outlined,
                              text: doj,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _handleLogout(context),
                        icon: const Icon(
                          Icons.logout_rounded,
                          color: AppColors.error,
                        ),
                        label: const Text(
                          'Logout',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(
                            color: AppColors.error,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}

class _WebProfileRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WebProfileRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 18.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
