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
  String? _companyImageUrl;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOutCubic,
      ),
    );
    _fadeController.forward();

    _loadCompanyLogo();
    _checkAuthSession();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyLogo() async {
    try {
      final img = await LocalStorageService.getCompanyImageUrl();
      if (mounted && img != null && img.isNotEmpty) {
        setState(() {
          _companyImageUrl = img;
        });
      }
    } catch (_) {}
  }

  Future<String> _determineInitialRoute() async {
    try {
      final isLoggedIn = await LocalStorageService.isLoggedIn();
      final user = await LocalStorageService.getUser();

      if (isLoggedIn || user != null) {
        return '/dashboard';
      }

      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint != null && accessPoint.isNotEmpty) {
        return '/login';
      }
    } catch (_) {}

    return '/company-access';
  }

  Future<void> _checkAuthSession() async {
    // Guarantees the splash screen is displayed for at least 3 seconds
    final minSplashDelay = Future.delayed(const Duration(seconds: 3));
    final targetRoute = await _determineInitialRoute();
    await minSplashDelay;

    if (mounted) {
      context.go(targetRoute);
    }
  }

  Widget _buildBrandLogo() {
    if (_companyImageUrl != null && _companyImageUrl!.isNotEmpty) {
      return Image.network(
        _companyImageUrl!,
        height: 50,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildAssetLogo(),
      );
    }
    return _buildAssetLogo();
  }

  Widget _buildAssetLogo() {
    return Image.asset(
      'assets/images/cryptone_logo.png',
      height: 50,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF004AC6),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hub_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'cryptone',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // Nordic Alabaster
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Architectural Canvas Grid Background
          const CustomPaint(
            painter: _GridPainter(),
          ),

          // 2. Ambient Halo Lighting
          Center(
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0053DB).withValues(alpha: 0.06),
                    const Color(0xFFF0F4FF).withValues(alpha: 0.4),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 0.72],
                ),
              ),
            ),
          ),

          // 3. Floating Halo Ring
          Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF004AC6).withValues(alpha: 0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF004AC6).withValues(alpha: 0.05),
                    blurRadius: 40,
                    spreadRadius: -10,
                  ),
                ],
              ),
            ),
          ),

          // 4. Main Foreground Composition (SafeArea)
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(height: 24),

                  // Center Composition with Smooth Fade & Scale Entrance
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Brand Logo with ethereal drop shadow
                          Container(
                            constraints: const BoxConstraints(
                              maxHeight: 56,
                              maxWidth: 240,
                            ),
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF004AC6)
                                      .withValues(alpha: 0.12),
                                  blurRadius: 28,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: _buildBrandLogo(),
                          ),

                          const SizedBox(height: 32),

                          // Refined Editorial Typography
                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.9,
                                color: const Color(0xFF0F172A),
                              ),
                              children: [
                                const TextSpan(text: 'Cryptone '),
                                TextSpan(
                                  text: 'HRMS',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF004AC6),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'THE WORKFORCE OPERATING SYSTEM',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.2,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom Status and Interaction Footer
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Refined Thin-Stroke Progress Spinner
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF004AC6),
                          ),
                          backgroundColor:
                              const Color(0xFF94A3B8).withValues(alpha: 0.2),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // iOS Native Home Indicator Bar
                      Container(
                        width: 128,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
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

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F172A).withValues(alpha: 0.025)
      ..strokeWidth = 1.0;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
