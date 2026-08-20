import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/platform/haptic_service.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../bloc/goals_bloc.dart';
import '../bloc/goals_event.dart';
import '../bloc/goals_state.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GoalsBloc>(
      create: (context) => GoalsBloc(
        profileRepository: sl<ProfileRepository>(),
        goalRepository: sl<GoalRepository>(),
        accountRepository: sl<AccountRepository>(),
        categoryRepository: sl<CategoryRepository>(),
        transactionRepository: sl<TransactionRepository>(),
      )..add(const LoadGoals()),
      child: const GoalsView(),
    );
  }
}

class GoalsView extends StatelessWidget {
  const GoalsView({Key? key}) : super(key: key);

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'piggy':
        return LucideIcons.piggyBank;
      case 'car':
        return LucideIcons.car;
      case 'home':
        return LucideIcons.home;
      case 'plane':
        return LucideIcons.plane;
      case 'heart':
        return LucideIcons.heart;
      case 'graduation':
        return LucideIcons.graduationCap;
      case 'laptop':
        return LucideIcons.laptop;
      case 'gift':
        return LucideIcons.gift;
      default:
        return LucideIcons.target;
    }
  }

  String _formatAmount(int amountMinorUnits, String currency) {
    final double major = amountMinorUnits / 100.0;
    final String symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';
    return '$symbol${major.toStringAsFixed(0)}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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

    return BlocBuilder<GoalsBloc, GoalsState>(
      builder: (context, state) {
        if (state is GoalsInitial || state is GoalsLoading) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is GoalsError) {
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

        if (state is GoalsLoaded) {
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
                'GOALS',
                style: AppTypography.sectionHeading.copyWith(
                  color: textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<GoalsBloc>().add(const LoadGoals());
              },
              child: state.goals.isEmpty
                  ? Center(
                      child: Text(
                        'No active goals. Add one to start saving!',
                        style: AppTypography.body.copyWith(
                          color: textSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: state.goals.length,
                      itemBuilder: (context, index) {
                        final goal = state.goals[index];
                        final balance = state.goalBalances[goal.id] ?? 0;
                        final percent =
                            state.goalProgressPercents[goal.id] ?? 0.0;
                        final isExpired = goal.isExpired(DateTime.now());

                        return GestureDetector(
                          onTap: () async {
                            sl<HapticService>().selectionClick();
                            final refresh = await context.push<bool>(
                              '/goals/${goal.id}',
                            );
                            if (refresh == true) {
                              context.read<GoalsBloc>().add(const LoadGoals());
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                              border: Border.all(color: borderCol),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title and Icon row
                                Row(
                                  children: [
                                    Icon(
                                      _getIconData(goal.icon),
                                      color: textSecondary,
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            goal.name,
                                            style: AppTypography.body.copyWith(
                                              color: textPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            goal.goalType.name.toUpperCase(),
                                            style: AppTypography.caption
                                                .copyWith(color: textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isExpired)
                                      const Icon(
                                        LucideIcons.alertTriangle,
                                        color: AppColors.statusError,
                                        size: 20,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Progress bar
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.small,
                                  ),
                                  child: LinearProgressIndicator(
                                    value: (percent / 100.0).clamp(0.0, 1.0),
                                    backgroundColor: isDark
                                        ? Colors.black38
                                        : Colors.grey.shade300,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark
                                          ? AppColors.darkAccentPrimary
                                          : AppColors.lightAccentPrimary,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),

                                // Saved vs Target text
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${_formatAmount(balance, goal.currency)} / ${_formatAmount(goal.targetAmount, goal.currency)} (${percent.toStringAsFixed(0)}%)',
                                      style: AppTypography.caption.copyWith(
                                        color: textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      isExpired
                                          ? 'EXPIRED'
                                          : 'Target: ${_formatDate(goal.effectiveTargetDate)}',
                                      style: AppTypography.caption.copyWith(
                                        color: isExpired
                                            ? AppColors.statusError
                                            : textSecondary,
                                        fontWeight: isExpired
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            floatingActionButton: FloatingActionButton(
              backgroundColor: isDark
                  ? AppColors.darkAccentPrimary
                  : AppColors.lightAccentPrimary,
              foregroundColor: Colors.black,
              shape: const CircleBorder(),
              child: const Icon(LucideIcons.plus),
              onPressed: () async {
                sl<HapticService>().mediumImpact();
                final refresh = await context.push<bool>('/goals/create');
                if (refresh == true) {
                  context.read<GoalsBloc>().add(const LoadGoals());
                }
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }
}
