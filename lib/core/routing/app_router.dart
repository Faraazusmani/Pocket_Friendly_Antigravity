import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// App routing paths.
class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String dashboard = '/';
  static const String transactions = '/transactions';
  static const String insights = '/insights';
  static const String goals = '/goals';
  static const String categories = '/categories';
  static const String settings = '/settings';
}

/// GoRouter configuration.
final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.dashboard,
  routes: [
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Onboarding'),
    ),
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (context, state) => const _PlaceholderScreen(title: 'Dashboard'),
    ),
    GoRoute(
      path: AppRoutes.transactions,
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Transactions'),
    ),
    GoRoute(
      path: AppRoutes.insights,
      builder: (context, state) => const _PlaceholderScreen(title: 'Insights'),
    ),
    GoRoute(
      path: AppRoutes.goals,
      builder: (context, state) => const _PlaceholderScreen(title: 'Goals'),
    ),
    GoRoute(
      path: AppRoutes.categories,
      builder: (context, state) =>
          const _PlaceholderScreen(title: 'Categories'),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const _PlaceholderScreen(title: 'Settings'),
    ),
  ],
);

/// A minimalist placeholder widget to allow the router foundation to compile.
/// This is not a "fake screen" to simulate features, but a technical scaffold.
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          title,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
