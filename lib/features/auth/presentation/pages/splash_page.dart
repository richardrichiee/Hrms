import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/storage/local_storage_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _checkAuthSession();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<String> _determineInitialRoute() async {
    try {
      final isLoggedIn = await LocalStorageService.isLoggedIn();
      final user = await LocalStorageService.getUser();

      if (isLoggedIn && user != null) {
        if (user.employeeId <= 0 ||
            user.empCode == '0' ||
            user.empCode == '0.0') {
          await LocalStorageService.clearUserSession();
          return '/login';
        }

        // Daily Re-Authentication Policy: expire session at the start of a new calendar day
        final isExpiredForNewDay =
            await LocalStorageService.isSessionExpiredForNewDay();
        if (isExpiredForNewDay) {
          await LocalStorageService.invalidateSessionForNewDay();
          return '/login?reason=daily_reauth';
        }

        // Mandatory Biometric Gate for punch-needed users opening the app
        final isBiometricVerified =
            await LocalStorageService.isBiometricVerified();
        if (user.isPunchNeeded && !isBiometricVerified) {
          return '/biometric-verify';
        }

        return '/dashboard';
      } else if (isLoggedIn && user == null) {
        await LocalStorageService.clearUserSession();
      }

      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint != null && accessPoint.isNotEmpty) {
        return '/login';
      }
    } catch (_) {}

    return '/company-access';
  }

  Future<void> _checkAuthSession() async {
    // Displays splash screen for at least 2.5 seconds for a smooth brand impression
    final minSplashDelay = Future.delayed(const Duration(milliseconds: 2500));
    final targetRoute = await _determineInitialRoute();
    await minSplashDelay;

    if (mounted) {
      context.go(targetRoute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Centered Ally One Dream Team Logo
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Image.asset(
                'assets/images/ally_one_dream_team.png',
                width: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Text(
                  'Ally One\nDREAM TEAM',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A),
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ),

          // 2. Bottom "Powered by Cryptone" Footer
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + 28,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Powered by',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Image.asset(
                    'assets/images/cryptone_logo.png',
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Text(
                      'Cryptone',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
