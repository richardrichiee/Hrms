import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/biometric_verification_page.dart';
import '../../features/auth/presentation/pages/company_access_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/claims/presentation/pages/claims_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';
import '../../features/leave/presentation/pages/leave_page.dart';
import '../../features/notifications/presentation/pages/notifications_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/settings/presentation/pages/change_password_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shell/presentation/pages/main_shell_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: '/company-access',
      builder: (context, state) => const CompanyAccessPage(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => LoginPage(
        reason: state.uri.queryParameters['reason'],
      ),
    ),
    GoRoute(
      path: '/biometric-verify',
      builder: (context, state) => const BiometricVerificationPage(),
    ),
    GoRoute(
      path: '/biometric-verification',
      builder: (context, state) => const BiometricVerificationPage(),
    ),
    GoRoute(
      path: '/leave',
      builder: (context, state) => const LeavePage(),
    ),
    GoRoute(
      path: '/claims',
      builder: (context, state) => const ClaimsPage(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordPage(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainShellPage(navigationShell: navigationShell);
      },
      branches: [
        // Tab 0: Home (Dashboard)
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const DashboardPage(),
            ),
          ],
        ),
        // Tab 1: Profile
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
        // Tab 2: Settings
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsPage(),
            ),
          ],
        ),
      ],
    ),
  ],
);
