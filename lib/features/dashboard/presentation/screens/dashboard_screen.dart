import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pocket_friendly/core/di/service_locator.dart';
import 'package:pocket_friendly/core/design_system/tokens.dart';
import 'package:pocket_friendly/core/platform/haptic_service.dart';
import 'package:pocket_friendly/features/profiles/domain/repositories/profile_repository.dart';
import 'package:pocket_friendly/features/accounts/domain/repositories/account_repository.dart';
import 'package:pocket_friendly/features/categories/domain/repositories/category_repository.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import 'package:pocket_friendly/features/budgets/domain/repositories/budget_repository.dart';
import 'package:pocket_friendly/features/recurring/domain/repositories/recurring_repository.dart';
import '../bloc/dashboard_bloc.dart';
import '../bloc/dashboard_event.dart';
import '../bloc/dashboard_state.dart';
import '../widgets/snapshot_card.dart';
import '../widgets/safe_to_spend_card.dart';
import '../widgets/goals_preview.dart';
import '../widgets/recent_transactions.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardBloc>(
      create: (context) => DashboardBloc(
        profileRepository: sl<ProfileRepository>(),
        accountRepository: sl<AccountRepository>(),
        categoryRepository: sl<CategoryRepository>(),
        transactionRepository: sl<TransactionRepository>(),
        goalRepository: sl<GoalRepository>(),
        budgetRepository: sl<BudgetRepository>(),
        recurringRepository: sl<RecurringRepository>(),
      )..add(const LoadDashboard()),
      child: const DashboardView(),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({Key? key}) : super(key: key);

  Widget _buildMonthSelector(BuildContext context, DashboardLoaded state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final months = <DateTime>[];

    // Generate last 6 calendar months
    for (int i = 5; i >= 0; i--) {
      int m = now.month - i;
      int y = now.year;
      if (m <= 0) {
        m += 12;
        y -= 1;
      }
      months.add(DateTime(y, m, 1));
    }

    final monthsAbbr = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        itemCount: months.length,
        itemBuilder: (context, index) {
          final monthDate = months[index];
          final isSelected =
              monthDate.year == state.selectedMonth.year &&
              monthDate.month == state.selectedMonth.month;

          final label = '${monthsAbbr[monthDate.month - 1]}';

          return GestureDetector(
            onTap: () {
              sl<HapticService>().selectionClick();
              BlocProvider.of<DashboardBloc>(
                context,
              ).add(ChangeMonth(monthDate));
            },
            child: Container(
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: AppSpacing.sm),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                          ? AppColors.darkAccentPrimary
                          : AppColors.lightAccentPrimary)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : (isDark
                            ? AppColors.darkBorderSubtle
                            : AppColors.lightBorderSubtle),
                ),
              ),
              child: Text(
                label,
                style: AppTypography.button.copyWith(
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBudgetWarning(BuildContext context, DashboardLoaded state) {
    if (state.overspentBudgets.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.statusError.withOpacity(0.15),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: AppColors.statusError.withOpacity(0.3),
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.alertTriangle,
              color: AppColors.statusError,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Warning',
                    style: AppTypography.body.copyWith(
                      color: AppColors.statusError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'You have exceeded your monthly budget in ${state.overspentBudgets.length} categories.',
                    style: AppTypography.caption.copyWith(color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySelector(BuildContext context, DashboardLoaded state) {
    if (state.availableCurrencies.length <= 1) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      onSelected: (currency) {
        sl<HapticService>().selectionClick();
        BlocProvider.of<DashboardBloc>(context).add(ChangeCurrency(currency));
      },
      itemBuilder: (context) {
        return state.availableCurrencies.map((currency) {
          final isSelected =
              currency.toUpperCase() == state.selectedCurrency.toUpperCase();
          return PopupMenuItem<String>(
            value: currency,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(currency, style: AppTypography.body),
                if (isSelected)
                  Icon(
                    LucideIcons.check,
                    color: isDark
                        ? AppColors.darkAccentPrimary
                        : AppColors.lightAccentPrimary,
                    size: 16,
                  ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(
            color: isDark
                ? AppColors.darkBorderSubtle
                : AppColors.lightBorderSubtle,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              state.selectedCurrency,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
              ),
            ),
            const Icon(LucideIcons.chevronDown, size: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? AppColors.darkBackgroundPrimary
        : AppColors.lightBackgroundPrimary;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: BlocBuilder<DashboardBloc, DashboardState>(
        builder: (context, state) {
          if (state is DashboardInitial || state is DashboardLoading) {
            return Container(
              color: scaffoldBg,
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (state is DashboardError) {
            return Container(
              color: scaffoldBg,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.alertOctagon,
                      size: 48,
                      color: AppColors.statusError,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Failed to load Dashboard',
                      style: AppTypography.sectionHeading.copyWith(
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      state.message,
                      textAlign: TextAlign.center,
                      style: AppTypography.body.copyWith(color: textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () {
                        BlocProvider.of<DashboardBloc>(
                          context,
                        ).add(const LoadDashboard());
                      },
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            );
          }

          final loaded = state as DashboardLoaded;

          return SafeArea(
            child: RefreshIndicator(
              onRefresh: () async {
                BlocProvider.of<DashboardBloc>(
                  context,
                ).add(const LoadDashboard());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    // HEADER
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'POCKET FRIENDLY',
                                  style: AppTypography.caption.copyWith(
                                    letterSpacing: 2.0,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? AppColors.darkAccentPrimary
                                        : AppColors.lightAccentPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2.0),
                                Text(
                                  loaded.profile.name,
                                  style: AppTypography.sectionHeading.copyWith(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildCurrencySelector(context, loaded),
                          const SizedBox(width: AppSpacing.sm),
                          // Privacy Toggle
                          IconButton(
                            tooltip: loaded.privacyModeEnabled
                                ? 'Disable Privacy Mode'
                                : 'Enable Privacy Mode',
                            onPressed: () {
                              sl<HapticService>().selectionClick();
                              BlocProvider.of<DashboardBloc>(
                                context,
                              ).add(const TogglePrivacyMode());
                            },
                            icon: Icon(
                              loaded.privacyModeEnabled
                                  ? LucideIcons.eyeOff
                                  : LucideIcons.eye,
                              color: textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // MONTH SELECTOR
                    _buildMonthSelector(context, loaded),
                    const SizedBox(height: AppSpacing.md),
                    // SNAPSHOT CARD
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: SnapshotCard(state: loaded),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // SAFE TO SPEND CARD
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: SafeToSpendCard(state: loaded),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // BUDGET WARNINGS
                    _buildBudgetWarning(context, loaded),
                    if (loaded.overspentBudgets.isNotEmpty)
                      const SizedBox(height: AppSpacing.md),
                    // GOALS PROGRESS PREVIEW
                    GoalsPreview(state: loaded),
                    const SizedBox(height: AppSpacing.md),
                    // RECENT TRANSACTIONS
                    RecentTransactions(state: loaded),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
