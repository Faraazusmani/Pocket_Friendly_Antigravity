import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/accounts/presentation/screens/account_detail_screen.dart';
import '../../features/accounts/presentation/screens/create_edit_account_screen.dart';
import '../../features/categories/presentation/screens/categories_screen.dart';
import '../../features/categories/presentation/screens/create_edit_category_screen.dart';

/// App routing paths.
class AppRoutes {
  static const String onboarding = '/onboarding';
  static const String dashboard = '/';
  static const String transactions = '/transactions';
  static const String insights = '/insights';
  static const String goals = '/goals';
  static const String categories = '/categories';
  static const String createCategory = '/categories/create';
  static const String editCategory = '/categories/edit/:id';
  static const String settings = '/settings';
  static const String accounts = '/accounts';
  static const String accountDetail = '/accounts/:id';
  static const String createAccount = '/accounts/create';
  static const String editAccount = '/accounts/edit/:id';
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
      builder: (context, state) => const DashboardScreen(),
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
      builder: (context, state) => const CategoriesScreen(),
    ),
    GoRoute(
      path: AppRoutes.createCategory,
      builder: (context, state) => const CreateEditCategoryScreen(),
    ),
    GoRoute(
      path: AppRoutes.editCategory,
      builder: (context, state) =>
          CreateEditCategoryScreen(categoryId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const _PlaceholderScreen(title: 'Settings'),
    ),
    GoRoute(
      path: AppRoutes.accounts,
      builder: (context, state) => const AccountsScreen(),
    ),
    GoRoute(
      path: AppRoutes.accountDetail,
      builder: (context, state) =>
          AccountDetailScreen(accountId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: AppRoutes.createAccount,
      builder: (context, state) => const CreateEditAccountScreen(),
    ),
    GoRoute(
      path: AppRoutes.editAccount,
      builder: (context, state) =>
          CreateEditAccountScreen(accountId: state.pathParameters['id']!),
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
