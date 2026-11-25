import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/services/biometric_service.dart';

class BiometricVerificationPage extends StatefulWidget {
  const BiometricVerificationPage({super.key});

  @override
  State<BiometricVerificationPage> createState() =>
      _BiometricVerificationPageState();
}

class _BiometricVerificationPageState extends State<BiometricVerificationPage> {
  final _biometricService = BiometricService();

  UserModel? _user;
  String? _companyImageUrl;
  bool _isAuthenticating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadContextAndPrompt();
  }

  Future<void> _loadContextAndPrompt() async {
    final user = await LocalStorageService.getUser();
    final companyImg = await LocalStorageService.getCompanyImageUrl();
    if (!mounted) return;

    if (user == null || user.userId <= 0 || user.employeeId <= 0) {
      context.go('/login');
      return;
    }

    final alreadyVerified = await LocalStorageService.isBiometricVerified();
    if (!mounted) return;

    if (!user.isPunchNeeded || alreadyVerified) {
      context.go('/dashboard');
      return;
    }

    setState(() {
      _user = user;
      _companyImageUrl = companyImg;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerBiometricVerification();
      }
    });
  }

  Future<void> _triggerBiometricVerification() async {
    if (_isAuthenticating) return;
    final user = _user ?? await LocalStorageService.getUser();
    if (!mounted) return;

    if (user == null || user.userId <= 0 || user.employeeId <= 0) {
      context.go('/login');
      return;
    }

    if (await LocalStorageService.isBiometricVerified() || !user.isPunchNeeded) {
      if (mounted) context.go('/dashboard');
      return;
    }

    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });

    final result = await _biometricService.authenticate(
      localizedReason: 'Verify your identity to access Ally One HR',
    );

    if (!mounted) return;

    if (result.isSuccess) {
      await LocalStorageService.setBiometricVerified(true);
      await LocalStorageService.saveLoginTimestamp();
      await LocalStorageService.activateBiometricLockAfterVerification();
      if (mounted) {
        context.go('/dashboard');
      }
      return;
    }

    setState(() {
      _isAuthenticating = false;
      _errorMessage = result.isCancelled
          ? 'Verification was cancelled. Tap below to try again.'
          : (result.errorMessage ??
                'Biometric verification failed. Please try again.');
    });
  }

  Future<void> _handleSignOut() async {
    await LocalStorageService.clearUserSession();
    if (mounted) {
      context.go('/login');
    }
  }

  Widget _buildCompanyLogo() {
    if (_companyImageUrl != null && _companyImageUrl!.isNotEmpty) {
      return Image.network(
        _companyImageUrl!,
        height: 52,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildAssetLogo(),
      );
    }
    return _buildAssetLogo();
  }

  Widget _buildAssetLogo() {
    return Image.asset(
      'assets/images/ally_one_dream_team.png',
      height: 52,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Text(
        AppConstants.appName,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (_user?.userName.trim().isNotEmpty == true)
        ? _user!.userName.trim()
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: _buildCompanyLogo()),
                  const SizedBox(height: 36),

                  // Biometric Emblem
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF93C5FD),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1C64F2,
                            ).withValues(alpha: 0.14),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: _isAuthenticating
                          ? const Center(
                              child: SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.8,
                                  color: Color(0xFF1C64F2),
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.fingerprint_rounded,
                              size: 52,
                              color: Color(0xFF1342A0),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    'Biometric Verification',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your account requires biometric verification before opening the app.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      color: const Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),

                  if (displayName != null) ...[
                    const SizedBox(height: 18),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 16,
                              color: Color(0xFF059669),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              displayName,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: Color(0xFFDC2626),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFB91C1C),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Verify with Biometrics CTA
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF081735),
                          Color(0xFF1342A0),
                          Color(0xFF1C64F2),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1C64F2).withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        onTap: _isAuthenticating
                            ? null
                            : _triggerBiometricVerification,
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.fingerprint_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _isAuthenticating
                                    ? 'Verifying...'
                                    : 'Verify with Biometrics',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Sign Out Option
                  TextButton.icon(
                    onPressed: _isAuthenticating ? null : _handleSignOut,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: Text(
                      'Sign Out',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
