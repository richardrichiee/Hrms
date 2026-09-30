import 'package:flutter/material.dart';
import 'app/routes/app_router.dart';
import 'app/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/storage/local_storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorageService.init();
  runApp(const DreamTeamApp());
}

class DreamTeamApp extends StatelessWidget {
  const DreamTeamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: appRouter,
    );
  }
}
