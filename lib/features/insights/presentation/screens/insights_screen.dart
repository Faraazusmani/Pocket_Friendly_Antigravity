import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/platform/haptic_service.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../budgets/domain/repositories/budget_repository.dart';
import '../../../recurring/domain/repositories/recurring_repository.dart';
import '../../../transactions/domain/transaction.dart';
import '../bloc/insights_bloc.dart';
import '../bloc/insights_event.dart';
import '../bloc/insights_state.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<InsightsBloc>(
      create: (context) => InsightsBloc(
        profileRepository: sl<ProfileRepository>(),
        accountRepository: sl<AccountRepository>(),
        categoryRepository: sl<CategoryRepository>(),
        transactionRepository: sl<TransactionRepository>(),
        goalRepository: sl<GoalRepository>(),
        budgetRepository: sl<BudgetRepository>(),
        recurringRepository: sl<RecurringRepository>(),
      )..add(LoadInsights(DateTime.now())),
      child: const InsightsView(),
    );
  }
}

class InsightsView extends StatelessWidget {
  const InsightsView({Key? key}) : super(key: key);

  String _formatAmount(int amountMinor, String currency, bool privacyMode) {
    if (privacyMode) return '•••';
    final double major = amountMinor / 100.0;
    final String symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';
    return '$symbol${major.toStringAsFixed(0)}';
  }

  void _showDrillDownSheet({
    required BuildContext context,
    required String title,
    required List<Transaction> transactions,
    required String currency,
    required bool privacyMode,
  }) {
    sl<HapticService>().selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? AppColors.darkSurfacePrimary
        : AppColors.lightSurfacePrimary;
    final borderCol = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bContext) => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppRadius.sheet),
            topRight: Radius.circular(AppRadius.sheet),
          ),
          border: Border.all(color: borderCol),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: borderCol,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title.toUpperCase(),
              style: AppTypography.sectionHeading.copyWith(
                color: textPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (transactions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: Text(
                    'No transactions to show.',
                    style: TextStyle(color: textSecondary),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        tx.note?.isNotEmpty == true
                            ? tx.note!
                            : tx.type.name.toUpperCase(),
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${tx.date.day}/${tx.date.month}/${tx.date.year}',
                        style: TextStyle(color: textSecondary),
                      ),
                      trailing: Text(
                        _formatAmount(tx.totalAmount, currency, privacyMode),
                        style: TextStyle(
                          color: tx.type == TransactionType.expense
                              ? AppColors.statusError
                              : AppColors.statusSuccess,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, InsightsLoaded state) {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              context.read<InsightsBloc>().add(LoadInsights(monthDate));
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? AppColors.darkBackgroundPrimary
        : AppColors.lightBackgroundPrimary;
    final cardBg = isDark
        ? AppColors.darkSurfacePrimary
        : AppColors.lightSurfacePrimary;
    final borderCol = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return BlocBuilder<InsightsBloc, InsightsState>(
      builder: (context, state) {
        if (state is InsightsInitial || state is InsightsLoading) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is InsightsError) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            body: Center(
              child: Text(
                state.message,
                style: AppTypography.body.copyWith(
                  color: AppColors.statusError,
                ),
              ),
            ),
          );
        }

        if (state is InsightsLoaded) {
          final data = state.data;
          final isPrivacy = state.privacyModeEnabled;
          final currency = state.defaultCurrency;

          return Scaffold(
            backgroundColor: scaffoldBg,
            appBar: AppBar(
              backgroundColor: scaffoldBg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: textPrimary),
                onPressed: () {
                  sl<HapticService>().selectionClick();
                  context.pop();
                },
              ),
              title: Text(
                'INSIGHTS',
                style: AppTypography.sectionHeading.copyWith(
                  color: textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.sm),
                  _buildMonthSelector(context, state),
                  const SizedBox(height: AppSpacing.md),

                  // Hero Savings Rate Card
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'SAVINGS RATE',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            isPrivacy
                                ? '••%'
                                : '${data.savingsRate.toStringAsFixed(0)}%',
                            style: AppTypography.display.copyWith(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'Goal Savings',
                                    style: AppTypography.caption.copyWith(
                                      color: textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatAmount(
                                      data.goalSavings,
                                      currency,
                                      isPrivacy,
                                    ),
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Account Savings',
                                    style: AppTypography.caption.copyWith(
                                      color: textSecondary,
                                    ),
                                  ),
                                  Text(
                                    _formatAmount(
                                      data.accountSavings,
                                      currency,
                                      isPrivacy,
                                    ),
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // MoM Summary
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'MONTH-OVER-MONTH CHANGES',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: borderCol),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMomPoint(
                            label: 'Income',
                            amount: data.totalIncome,
                            changePercent: data.incomeChangePercent,
                            currency: currency,
                            isPrivacy: isPrivacy,
                          ),
                          _buildMomPoint(
                            label: 'Spending',
                            amount: data.totalSpending,
                            changePercent: data.spendingChangePercent,
                            currency: currency,
                            isPrivacy: isPrivacy,
                          ),
                          _buildMomPoint(
                            label: 'Savings',
                            amount: data.totalSavings,
                            changePercent: data.savingsChangePercent,
                            currency: currency,
                            isPrivacy: isPrivacy,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Natural language explanations supported by user's actual data
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'HIGHLIGHTS',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Custom Insight Cards
                  if (data.biggestExpense != null)
                    _buildTextInsightCard(
                      context: context,
                      icon: LucideIcons.trendingUp,
                      title: 'Biggest Expense',
                      description:
                          'Your biggest expense this month was ${_formatAmount(data.biggestExpense!.totalAmount, currency, isPrivacy)} on ${data.biggestExpense!.note ?? 'Category'}.',
                      onTap: () => _showDrillDownSheet(
                        context: context,
                        title: 'Biggest Expense',
                        transactions: [data.biggestExpense!],
                        currency: currency,
                        privacyMode: isPrivacy,
                      ),
                      isDark: isDark,
                      borderCol: borderCol,
                      cardBg: cardBg,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),

                  if (data.spendingSpikes.isNotEmpty)
                    _buildTextInsightCard(
                      context: context,
                      icon: LucideIcons.zap,
                      title: 'Spending Spikes',
                      description:
                          'We detected ${data.spendingSpikes.length} days with spikes exceeding 2.5x your average daily spending.',
                      onTap: () {
                        // Gather all transactions in spike days
                        final List<Transaction> spikeTxs = [];
                        for (final s in data.spendingSpikes) {
                          spikeTxs.addAll(s.transactions);
                        }
                        _showDrillDownSheet(
                          context: context,
                          title: 'Spike Transactions',
                          transactions: spikeTxs,
                          currency: currency,
                          privacyMode: isPrivacy,
                        );
                      },
                      isDark: isDark,
                      borderCol: borderCol,
                      cardBg: cardBg,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),

                  if (data.unusualTransactions.isNotEmpty)
                    _buildTextInsightCard(
                      context: context,
                      icon: LucideIcons.helpCircle,
                      title: 'Unusual Transactions',
                      description:
                          'You made ${data.unusualTransactions.length} transaction(s) exceeding 3x their usual category averages.',
                      onTap: () => _showDrillDownSheet(
                        context: context,
                        title: 'Unusual Transactions',
                        transactions: data.unusualTransactions,
                        currency: currency,
                        privacyMode: isPrivacy,
                      ),
                      isDark: isDark,
                      borderCol: borderCol,
                      cardBg: cardBg,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                    ),

                  if (data.budgetRisks.isNotEmpty)
                    ...data.budgetRisks.map(
                      (risk) => _buildTextInsightCard(
                        context: context,
                        icon: LucideIcons.alertTriangle,
                        title: 'Budget Risk',
                        description:
                            'You have consumed ${risk.progressPercent.toStringAsFixed(0)}% of your ${risk.category.name} budget.',
                        isDark: isDark,
                        borderCol: borderCol,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),

                  if (data.goalRisks.isNotEmpty)
                    ...data.goalRisks.map(
                      (risk) => _buildTextInsightCard(
                        context: context,
                        icon: LucideIcons.target,
                        title: 'Goal Risk',
                        description: risk.isExpired
                            ? 'Your goal "${risk.goal.name}" has expired and remains short by ${_formatAmount(risk.requiredMonthly, currency, isPrivacy)}.'
                            : 'Goal "${risk.goal.name}" is behind schedule. Required: ${_formatAmount(risk.requiredMonthly, currency, isPrivacy)}/mo, Saved: ${_formatAmount(risk.actualThisMonth, currency, isPrivacy)}.',
                        isDark: isDark,
                        borderCol: borderCol,
                        cardBg: cardBg,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                      ),
                    ),

                  const SizedBox(height: AppSpacing.lg),

                  // Top Categories Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'TOP CATEGORIES',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        children: data.topCategories.isEmpty
                            ? [
                                Center(
                                  child: Text(
                                    'No category spending recorded.',
                                    style: TextStyle(color: textSecondary),
                                  ),
                                ),
                              ]
                            : data.topCategories.map((c) {
                                final percent = data.totalSpending > 0
                                    ? (c.spent / data.totalSpending) * 100
                                    : 0;
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        c.category.name,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_formatAmount(c.spent, currency, isPrivacy)} (${percent.toStringAsFixed(0)}%)',
                                        style: TextStyle(color: textSecondary),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Six-Month Trend Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Text(
                      'TREND (LAST 6 MONTHS)',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: borderCol),
                      ),
                      child: Column(
                        children: data.sixMonthTrend.map((point) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.xs,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  point.monthLabel,
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'In: ${_formatAmount(point.income, currency, isPrivacy)}',
                                      style: const TextStyle(
                                        color: AppColors.statusSuccess,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Out: ${_formatAmount(point.spending, currency, isPrivacy)}',
                                      style: const TextStyle(
                                        color: AppColors.statusError,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildMomPoint({
    required String label,
    required int amount,
    required double changePercent,
    required String currency,
    required bool isPrivacy,
  }) {
    final isIncrease = changePercent > 0;
    final color = changePercent == 0
        ? AppColors.darkTextSecondary
        : (isIncrease ? AppColors.statusSuccess : AppColors.statusError);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 2),
        Text(
          _formatAmount(amount, currency, isPrivacy),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              isIncrease ? LucideIcons.trendingUp : LucideIcons.trendingDown,
              color: color,
              size: 12,
            ),
            const SizedBox(width: 2),
            Text(
              '${changePercent.abs().toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextInsightCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    VoidCallback? onTap,
    required bool isDark,
    required Color borderCol,
    required Color cardBg,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppSpacing.md),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isDark
                    ? AppColors.darkAccentPrimary
                    : AppColors.lightAccentPrimary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Tap to inspect relevant transactions',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkAccentPrimary
                              : AppColors.lightAccentPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
