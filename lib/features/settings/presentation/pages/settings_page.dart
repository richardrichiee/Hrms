import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../auth/data/models/user_model.dart';
import '../../../auth/data/services/auth_service.dart';
import '../../../auth/data/services/biometric_service.dart';
import '../../../profile/data/models/employee_details_model.dart';
import '../../../profile/data/services/employee_service.dart';
import '../widgets/branch_location_sheet.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _employeeService = EmployeeService();
  final _biometricService = BiometricService();
  final _authService = AuthService();

  UserModel? _user;
  EmployeeDetailsModel? _employeeDetails;

  bool _biometricLogin = false;
  bool _isUpdatingBiometric = false;
  bool _isLoading = true;

  bool get _isPunchMandatory => _user?.isPunchNeeded == true;

  @override
  void initState() {
    super.initState();
    _loadSettingsData();
  }

  Future<void> _loadSettingsData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        LocalStorageService.getUser(),
        _employeeService.fetchEmployeeDashboard(),
        LocalStorageService.isBiometricEnabled(),
      ]);

      final user = results[0] as UserModel?;
      final details = results[1] as EmployeeDetailsModel?;
      final biometricEnabled = results[2] as bool;

      if (mounted) {
        setState(() {
          _user = user;
          _employeeDetails = details;
          _biometricLogin =
              (user?.isPunchNeeded == true) ? true : biometricEnabled;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleBiometricToggle(bool enable) async {
    if (_isPunchMandatory || _isUpdatingBiometric) return;

    setState(() => _isUpdatingBiometric = true);
    try {
      if (!enable) {
        await LocalStorageService.clearBiometricCredentials();
        if (mounted) {
          setState(() {
            _biometricLogin = false;
            _isUpdatingBiometric = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Biometric login disabled.'),
              backgroundColor: AppColors.textPrimary,
            ),
          );
        }
        return;
      }

      // Check device support & enrollment
      final available = await _biometricService.isBiometricAvailable();
      if (!available) {
        if (mounted) {
          setState(() => _isUpdatingBiometric = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Biometrics are not configured on this device. Please enroll Fingerprint or Face ID in device settings.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Prompt biometric verification first
      final authResult = await _biometricService.authenticate(
        localizedReason: 'Verify your identity to enable biometric login',
      );
      if (!mounted) return;

      if (!authResult.isSuccess) {
        setState(() => _isUpdatingBiometric = false);
        if (!authResult.isCancelled) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                authResult.errorMessage ?? 'Biometric verification failed.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      // Check if credentials are already securely cached
      var creds = await LocalStorageService.getBiometricCredentials();
      if (creds == null) {
        final verifiedCreds = await _promptVerifyCredentialsDialog();
        if (!mounted) return;
        if (verifiedCreds == null) {
          setState(() => _isUpdatingBiometric = false);
          return;
        }
        await LocalStorageService.saveBiometricCredentials(
          loginId: verifiedCreds.loginId,
          password: verifiedCreds.password,
        );
      }

      await LocalStorageService.setBiometricEnabled(true);
      await LocalStorageService.setBiometricOnlyMode(true);
      await LocalStorageService.setBiometricVerified(true);

      if (mounted) {
        setState(() {
          _biometricLogin = true;
          _isUpdatingBiometric = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric login enabled successfully.'),
            backgroundColor: AppColors.secondary,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isUpdatingBiometric = false);
      }
    }
  }

  Future<({String loginId, String password})?>
      _promptVerifyCredentialsDialog() async {
    String initialLoginId = '';
    try {
      final prefs = await SharedPreferences.getInstance();
      initialLoginId = prefs.getString('saved_login_username') ?? '';
    } catch (_) {}

    final loginIdController = TextEditingController(text: initialLoginId);
    final passwordController = TextEditingController();
    bool obscurePassword = true;
    bool isVerifying = false;
    String? dialogError;

    if (!mounted) return null;

    final result = await showDialog<({String loginId, String password})>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.fingerprint_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Confirm Credentials',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enter your Login ID and Password once so we can securely store them for biometric sign-in.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: loginIdController,
                      enabled: !isVerifying,
                      decoration: InputDecoration(
                        labelText: 'Login ID',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      enabled: !isVerifying,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),
                      ),
                    ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () => Navigator.of(dialogContext).pop(null),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final uid = loginIdController.text.trim();
                          final pwd = passwordController.text.trim();
                          if (uid.isEmpty || pwd.isEmpty) {
                            setDialogState(() {
                              dialogError =
                                  'Please enter both Login ID and Password.';
                            });
                            return;
                          }

                          setDialogState(() {
                            isVerifying = true;
                            dialogError = null;
                          });

                          final loginRes = await _authService.login(
                            loginId: uid,
                            password: pwd,
                          );

                          if (!dialogContext.mounted) return;

                          if (loginRes.isSuccess) {
                            Navigator.of(dialogContext).pop(
                              (loginId: uid, password: pwd),
                            );
                          } else {
                            setDialogState(() {
                              isVerifying = false;
                              dialogError = loginRes.errorMessage ??
                                  'Invalid credentials. Please try again.';
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Verify & Enable'),
                ),
              ],
            );
          },
        );
      },
    );

    loginIdController.dispose();
    passwordController.dispose();
    return result;
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Settings',
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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadSettingsData,
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
                    // 1. Profile Banner matching Drawer Profile Header
                    _buildProfileBanner(context),
                    const SizedBox(height: 22),

                    // 2. Office & Location
                    _buildSectionHeader('WORKSPACE & LOCATION'),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        _SettingsActionTile(
                          icon: Icons.add_location_alt_rounded,
                          iconBg: const Color(0xFFF5F3FF),
                          iconColor: const Color(0xFF7C3AED),
                          title: 'Configure Branch Location',
                          subtitle: 'Set office GPS coordinates for attendance',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onTap: () => BranchLocationSheet.show(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 3. Security & App Preferences
                    _buildSectionHeader('SECURITY & PREFERENCES'),
                    const SizedBox(height: 8),
                    _SettingsCard(
                      children: [
                        if (!_isPunchMandatory) ...[
                          _SettingsSwitchTile(
                            icon: Icons.fingerprint_rounded,
                            iconBg: const Color(0xFFECFDF5),
                            iconColor: const Color(0xFF059669),
                            title: 'Biometric Login',
                            subtitle:
                                'Use Fingerprint / Face unlock to sign in',
                            value: _biometricLogin,
                            enabled: !_isUpdatingBiometric,
                            onChanged: _handleBiometricToggle,
                          ),
                          const _SettingsDivider(),
                        ],
                        _SettingsActionTile(
                          icon: Icons.lock_outline_rounded,
                          iconBg: const Color(0xFFFFFBEB),
                          iconColor: const Color(0xFFD97706),
                          title: 'Change Password',
                          subtitle: 'Update your login credentials',
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onTap: () => context.push('/change-password'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),

                    // 4. Sign Out Section matching Drawer
                    _buildSectionHeader('ACCOUNT SESSION'),
                    const SizedBox(height: 8),
                    _buildSignOutTile(context),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Squircle Avatar matching Dashboard & Drawer
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              _userAvatarLetter,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // User details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _userDesignation,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Profile View Chip
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.go('/profile'),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _SettingsSwitchTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.primary,
            activeThumbColor: Colors.white,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

class _SettingsActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsActionTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
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
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

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
