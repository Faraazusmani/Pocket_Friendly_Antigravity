import 'dart:ui';
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

class PocketFriendlyApp extends StatefulWidget {
  const PocketFriendlyApp({super.key});

  @override
  State<PocketFriendlyApp> createState() => _PocketFriendlyAppState();
}

class _PocketFriendlyAppState extends State<PocketFriendlyApp>
    with WidgetsBindingObserver {
  bool _isBackgrounded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    setState(() {
      _isBackgrounded =
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Pocket Friendly',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Dynamically match OS preferences
      routerConfig: appRouter,
      builder: (context, child) {
        return AppPrivacyShield(
          isBackgrounded: _isBackgrounded,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class AppPrivacyShield extends StatelessWidget {
  final bool isBackgrounded;
  final Widget child;

  const AppPrivacyShield({
    Key? key,
    required this.isBackgrounded,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!isBackgrounded) return child;
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.black.withOpacity(0.85),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 64, color: Colors.white),
                  const SizedBox(height: 16),
                  const Text(
                    'POCKET FRIENDLY SECURED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
