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
  @override
  void initState() {
    super.initState();
    _checkAuthSession();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
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
            ),
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
