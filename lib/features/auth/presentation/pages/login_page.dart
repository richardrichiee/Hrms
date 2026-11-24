import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../data/models/user_model.dart';
import '../../data/services/access_point_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/biometric_service.dart';

class LoginPage extends StatefulWidget {
  final String? reason;

  const LoginPage({super.key, this.reason});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _authService = AuthService();
  final _biometricService = BiometricService();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _isBiometricAuthenticating = false;
  bool _rememberMe = true;
  bool _hasBiometricCredentials = false;
  bool _showPasswordForm = true;
  String? _biometricLoginId;
  String? _errorMessage;
  String? _companyImageUrl;

  bool get _isDailyReauth => widget.reason == 'daily_reauth';

  @override
  void initState() {
    super.initState();
    _usernameFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
    _loadInitialData();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _usernameFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('saved_login_username') ?? '';
      final savedRemember = prefs.getBool('saved_remember_me') ?? true;

      if (savedUser.isNotEmpty && mounted) {
        _usernameController.text = savedUser;
      }
      if (mounted) {
        setState(() {
          _rememberMe = savedRemember;
        });
      }
    } catch (_) {}

    await _loadAccessPoint();
    await _checkBiometricMode();
  }

  Future<void> _checkBiometricMode() async {
    try {
      final isOnlyMode = await LocalStorageService.isBiometricOnlyMode();
      final isEnabled = await LocalStorageService.isBiometricEnabled();
      final creds = await LocalStorageService.getBiometricCredentials();
      final isAvailable = await _biometricService.isBiometricAvailable();

      if (!mounted) return;

      if ((isOnlyMode || isEnabled) && creds != null && isAvailable) {
        setState(() {
          _hasBiometricCredentials = true;
          _biometricLoginId = creds.loginId;
          _showPasswordForm = false;
          if (_usernameController.text.trim().isEmpty) {
            _usernameController.text = creds.loginId;
          }
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_showPasswordForm) {
            _handleBiometricLogin();
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAccessPoint() async {
    final cachedImg = await LocalStorageService.getCompanyImageUrl();
    if (mounted) {
      setState(() {
        _companyImageUrl = cachedImg;
      });
    }

    if (cachedImg == null || cachedImg.isEmpty) {
      final fetchedImg = await AccessPointService().ensureCompanyImageUrl();
      if (mounted && fetchedImg != null && fetchedImg.isNotEmpty) {
        setState(() {
          _companyImageUrl = fetchedImg;
        });
      }
    }
  }

  void _showWelcomeSnackBar(String userName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        backgroundColor: const Color(0xFF081735),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1342A0), Color(0xFF1C64F2)],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Welcome back, $userName!',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleBiometricLogin() async {
    if (_isLoading || _isBiometricAuthenticating) return;

    setState(() {
      _isBiometricAuthenticating = true;
      _errorMessage = null;
    });

    final authResult = await _biometricService.authenticate(
      localizedReason: _isDailyReauth
          ? 'Verify your identity to start today\'s session'
          : 'Sign in to Dream Team using biometrics',
    );

    if (!mounted) return;

    if (!authResult.isSuccess) {
      setState(() {
        _isBiometricAuthenticating = false;
        if (!authResult.isCancelled) {
          _errorMessage = authResult.errorMessage ??
              'Biometric verification failed. Please try again.';
        }
      });
      return;
    }

    final creds = await LocalStorageService.getBiometricCredentials();
    if (!mounted) return;

    if (creds == null) {
      setState(() {
        _isBiometricAuthenticating = false;
        _hasBiometricCredentials = false;
        _showPasswordForm = true;
        _errorMessage = 'Saved credentials not found. Please sign in with your password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _authService.login(
      loginId: creds.loginId,
      password: creds.password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _isBiometricAuthenticating = false;
    });

    if (result.isSuccess && result.user != null) {
      final user = result.user!;
      if (user.employeeId <= 0 ||
          user.empCode == '0' ||
          user.empCode == '0.0') {
        await LocalStorageService.clearUserSession();
        setState(() {
          _errorMessage = 'User not Active';
        });
        return;
      }

      await LocalStorageService.setBiometricVerified(true);
      await LocalStorageService.saveLoginTimestamp();
      await LocalStorageService.activateBiometricLockAfterVerification();

      if (!mounted) return;
      await _completeLoginSuccess(user);
    } else {
      setState(() {
        _errorMessage = result.errorMessage ??
            'Saved credentials could not be verified. Please sign in with your password.';
        _usernameController.text = creds.loginId;
        _showPasswordForm = true;
      });
    }
  }

  Future<void> _completeLoginSuccess(UserModel user) async {
    final alreadyVerified = await LocalStorageService.isBiometricVerified();
    if (!mounted) return;

    if (user.isPunchNeeded && !alreadyVerified) {
      context.go('/biometric-verify');
      return;
    }

    await LocalStorageService.saveLoginTimestamp();
    if (!mounted) return;

    _showWelcomeSnackBar(user.userName);
    context.go('/dashboard');
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage =
            'Please enter both your work email/username and password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Save or clear remember-me preference
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('saved_remember_me', _rememberMe);
      if (_rememberMe) {
        await prefs.setString('saved_login_username', username);
      } else {
        await prefs.remove('saved_login_username');
      }
    } catch (_) {}

    final result = await _authService.login(
      loginId: username,
      password: password,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    if (result.isSuccess && result.user != null) {
      final user = result.user!;
      if (user.employeeId <= 0 ||
          user.empCode == '0' ||
          user.empCode == '0.0') {
        await LocalStorageService.clearUserSession();
        setState(() {
          _errorMessage = 'User not Active';
        });
        return;
      }

      // Sync biometric credentials & mandatory punch policy
      final biometricEnabled = await LocalStorageService.isBiometricEnabled();
      final existingCreds = await LocalStorageService.getBiometricCredentials();

      if (user.isPunchNeeded) {
        await LocalStorageService.saveBiometricCredentials(
          loginId: username,
          password: password,
        );
      } else if (biometricEnabled) {
        await LocalStorageService.saveBiometricCredentials(
          loginId: username,
          password: password,
        );
        await LocalStorageService.setBiometricOnlyMode(true);
      } else if (existingCreds != null &&
          existingCreds.loginId.toLowerCase() != username.toLowerCase()) {
        await LocalStorageService.clearBiometricCredentials();
      }

      if (!mounted) return;
      await _completeLoginSuccess(user);
    } else {
      setState(() {
        _errorMessage = result.errorMessage ?? 'Invalid login credentials.';
      });
    }
  }

  Widget _buildCompanyLogo() {
    if (_companyImageUrl != null && _companyImageUrl!.isNotEmpty) {
      return Image.network(
        _companyImageUrl!,
        height: 58,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildAssetLogo(),
      );
    }
    return _buildAssetLogo();
  }

  Widget _buildAssetLogo() {
    return Image.asset(
      'assets/images/ally_one_dream_team.png',
      height: 58,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Text(
        AppConstants.appName,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF0F172A),
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildDailyReauthBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.wb_sunny_outlined,
              size: 18,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Verification Required',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'A new day has started. Please complete a quick verification to continue securely.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: const Color(0xFF1E40AF),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricFirstSection() {
    final busy = _isLoading || _isBiometricAuthenticating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Fingerprint Emblem
        Center(
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF93C5FD), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1C64F2).withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: busy
                ? const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        color: Color(0xFF1C64F2),
                      ),
                    ),
                  )
                : const Icon(
                    Icons.fingerprint_rounded,
                    size: 48,
                    color: Color(0xFF1342A0),
                  ),
          ),
        ),
        const SizedBox(height: 18),

        // User ID Badge Chip
        if (_biometricLoginId != null && _biometricLoginId!.isNotEmpty) ...[
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: Color(0xFF1C64F2),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _biometricLoginId!,
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
          const SizedBox(height: 22),
        ],

        _buildErrorBanner(),

        // Primary Biometric CTA Button
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
                color: const Color(0xFF1C64F2).withValues(alpha: 0.32),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: busy ? null : _handleBiometricLogin,
              borderRadius: BorderRadius.circular(14),
              child: Center(
                child: busy
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isLoading ? 'Signing in...' : 'Verifying...',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.fingerprint_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Sign in with Biometrics',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Use Password Instead toggle link
        TextButton(
          onPressed: busy
              ? null
              : () {
                  setState(() {
                    _showPasswordForm = true;
                    _errorMessage = null;
                    if (_biometricLoginId != null &&
                        _biometricLoginId!.isNotEmpty) {
                      _usernameController.text = _biometricLoginId!;
                    }
                  });
                },
          child: Text(
            'Use Password Instead',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1342A0),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final showBiometricFirst = _hasBiometricCredentials && !_showPasswordForm;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFBFA), // Nordic Off-white Alabaster
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: 28.0,
              vertical: 20.0,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  // 1. Authentic Brand Logo (Clean, borderless, spacious)
                  Center(child: _buildCompanyLogo()),
                  const SizedBox(height: 24),

                  // 2. Editorial Apple-style Typography
                  Text(
                    'Welcome!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.65,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    showBiometricFirst
                        ? 'Verify with biometrics to access your portal'
                        : 'Sign in to your workforce portal',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.normal,
                      letterSpacing: -0.15,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (_isDailyReauth) _buildDailyReauthBanner(),

                  if (showBiometricFirst)
                    _buildBiometricFirstSection()
                  else ...[
                    // 3. Minimalist, Elevated Login Form
                    // Work Email / Username Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
                          child: Text(
                            'Login ID',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: _usernameFocusNode.hasFocus
                                ? Colors.white
                                : const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _usernameFocusNode.hasFocus
                                  ? const Color(0xFF1C64F2).withValues(alpha: 0.7)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                            boxShadow: _usernameFocusNode.hasFocus
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1C64F2,
                                      ).withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: TextField(
                            controller: _usernameController,
                            focusNode: _usernameFocusNode,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.normal,
                              color: const Color(0xFF0F172A),
                            ),
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Password Field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0, bottom: 6.0),
                          child: Text(
                            'Password',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: _passwordFocusNode.hasFocus
                                ? Colors.white
                                : const Color(0xFFF2F4F7),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _passwordFocusNode.hasFocus
                                  ? const Color(0xFF1C64F2).withValues(alpha: 0.7)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                            boxShadow: _passwordFocusNode.hasFocus
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF1C64F2,
                                      ).withValues(alpha: 0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocusNode,
                            obscureText: !_isPasswordVisible,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _handleLogin(),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 15,
                              letterSpacing: _isPasswordVisible ? 0 : 2.0,
                              fontWeight: FontWeight.normal,
                              color: const Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              hintText: '••••••••••••',
                              hintStyle: GoogleFonts.plusJakartaSans(
                                fontSize: 15,
                                letterSpacing: 2.0,
                                color: const Color(0xFF94A3B8),
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                  color: const Color(0xFF94A3B8),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isPasswordVisible = !_isPasswordVisible;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Error Message Banner (if any)
                    _buildErrorBanner(),

                    // 4. Utility Row: Remember Me
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _rememberMe = !_rememberMe;
                          });
                        },
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: Checkbox(
                                value: _rememberMe,
                                activeColor: const Color(0xFF1C64F2),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                  width: 1.2,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    _rememberMe = val ?? false;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Remember me',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.normal,
                                color: const Color(0xFF475569),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 5. Primary CTA Button (Matching Gradient from Design)
                    Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF081735), // Deep Midnight Navy (Left)
                            Color(0xFF1342A0), // Rich Royal Blue (Center)
                            Color(0xFF1C64F2), // Vibrant Electric Blue (Right)
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF1C64F2,
                            ).withValues(alpha: 0.32),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: _isLoading ? null : _handleLogin,
                          borderRadius: BorderRadius.circular(14),
                          child: Center(
                            child: _isLoading
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Signing in...',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Sign In',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),

                    if (_hasBiometricCredentials) ...[
                      const SizedBox(height: 14),
                      TextButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () {
                                setState(() {
                                  _showPasswordForm = false;
                                  _errorMessage = null;
                                });
                                _handleBiometricLogin();
                              },
                        icon: const Icon(
                          Icons.fingerprint_rounded,
                          size: 18,
                          color: Color(0xFF1342A0),
                        ),
                        label: Text(
                          'Sign in with Biometrics',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1342A0),
                          ),
                        ),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
