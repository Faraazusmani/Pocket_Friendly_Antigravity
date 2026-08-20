import 'package:flutter/material.dart';
import 'core/di/service_locator.dart';
import 'core/platform/notification_service.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize service locator and dependencies (secure storage, SQLCipher database, etc)
  await initServiceLocator();

  // Initialize notifications
  await sl<NotificationService>().initialize();

  runApp(const PocketFriendlyApp());
}

class PocketFriendlyApp extends StatelessWidget {
  const PocketFriendlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pocket Friendly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Dynamically match OS preferences
      routerConfig: appRouter,
    );
  }
}
