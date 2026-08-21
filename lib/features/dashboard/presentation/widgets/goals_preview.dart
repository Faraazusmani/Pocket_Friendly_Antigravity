import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../goals/domain/goal.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import '../bloc/dashboard_state.dart';

import '../../../../core/utilities/currency_formatter.dart';

class GoalsPreview extends StatelessWidget {
  final DashboardLoaded state;

  const GoalsPreview({Key? key, required this.state}) : super(key: key);

  String _formatAmount(int amountInMinorUnits, String currency) {
    return CurrencyFormatter.format(
      amountInMinorUnits,
      currency,
      privacyMode: state.privacyModeEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? AppColors.darkSurfacePrimary
        : AppColors.lightBackgroundSecondary;
    final borderCol = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    final activeGoals = state.goals
        .where((g) => g.status == GoalStatus.active)
        .toList();

    if (activeGoals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'GOALS PROGRESS',
            style: AppTypography.caption.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: activeGoals.length,
            itemBuilder: (context, index) {
              final goal = activeGoals[index];
              final balance = FinancialEngine.calculateGoalBalance(
                goal,
                state.transactions,
              );
              final progressPercent =
                  FinancialEngine.calculateGoalProgressPercent(
                    goal,
                    state.transactions,
                  );
              final isExpired = goal.isExpired(DateTime.now());

              return Container(
                width: 200,
                margin: const EdgeInsets.only(right: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: borderCol, width: 1.0),
                ),
                child: Row(
                  children: [
                    // Circular Progress
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          height: 50,
                          width: 50,
                          child: CircularProgressIndicator(
                            value: (progressPercent / 100.0).clamp(0.0, 1.0),
                            strokeWidth: 4,
                            backgroundColor: isDark
                                ? AppColors.darkBorderSubtle
                                : AppColors.lightSurfacePrimary,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isExpired
                                  ? AppColors.statusError
                                  : (isDark
                                        ? AppColors.darkAccentPrimary
                                        : AppColors.lightAccentPrimary),
                            ),
                          ),
                        ),
                        Text(
                          '${progressPercent.toStringAsFixed(0)}%',
                          style: AppTypography.caption.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Goal Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            goal.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _formatAmount(balance, state.selectedCurrency),
                            style: AppTypography.caption.copyWith(
                              color: isExpired
                                  ? AppColors.statusError
                                  : textSecondary,
                            ),
                          ),
                          Text(
                            'of ${_formatAmount(goal.targetAmount, state.selectedCurrency)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
