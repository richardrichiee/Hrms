import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/storage/local_storage_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  String? _companyImageUrl;

  @override
  void initState() {
    super.initState();
    _loadCompanyLogo();
    _checkAuthSession();
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

  Future<void> _checkAuthSession() async {
    // Brief duration for branding display and async storage check
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    try {
      final isLoggedIn = await LocalStorageService.isLoggedIn();
      final user = await LocalStorageService.getUser();

      if (isLoggedIn || user != null) {
        if (mounted) {
          context.go('/dashboard');
          return;
        }
      }

      final accessPoint = await LocalStorageService.getAccessPoint();
      if (accessPoint != null && accessPoint.isNotEmpty) {
        if (mounted) {
          context.go('/login');
          return;
        }
      }
    } catch (_) {}

    if (mounted) {
      context.go('/company-access');
    }
  }

  Widget _buildPlaceholderLogo() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.business_rounded,
        size: 64,
        color: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _companyImageUrl != null && _companyImageUrl!.isNotEmpty
                ? Container(
                    constraints:
                        const BoxConstraints(maxHeight: 80, maxWidth: 240),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Image.network(
                      _companyImageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          _buildPlaceholderLogo(),
                    ),
                  )
                : _buildPlaceholderLogo(),
            const SizedBox(height: 24),
            const Text(
              'Dream Team HRMS',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Empowering Enterprise Workforce',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
