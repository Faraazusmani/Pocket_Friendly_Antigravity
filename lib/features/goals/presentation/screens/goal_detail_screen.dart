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
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../bloc/goals_bloc.dart';
import '../bloc/goals_event.dart';
import '../bloc/goals_state.dart';
import '../widgets/goal_transfer_dialogs.dart';

class GoalDetailScreen extends StatelessWidget {
  final String goalId;

  const GoalDetailScreen({Key? key, required this.goalId}) : super(key: key);

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
      child: GoalDetailView(goalId: goalId),
    );
  }
}

class GoalDetailView extends StatelessWidget {
  final String goalId;

  const GoalDetailView({Key? key, required this.goalId}) : super(key: key);

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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
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

    return BlocConsumer<GoalsBloc, GoalsState>(
      listener: (context, state) {
        if (state is GoalActionSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          context.read<GoalsBloc>().add(const LoadGoals());
        } else if (state is GoalsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.statusError,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is GoalsInitial || state is GoalsLoading) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is GoalsLoaded) {
          final goal = state.goals.where((g) => g.id == goalId).firstOrNull;
          if (goal == null) {
            return Scaffold(
              backgroundColor: scaffoldBg,
              appBar: AppBar(backgroundColor: scaffoldBg, elevation: 0),
              body: const Center(child: Text('Goal not found.')),
            );
          }

          final balance = state.goalBalances[goal.id] ?? 0;
          final percent = state.goalProgressPercents[goal.id] ?? 0.0;
          final isExpired = goal.isExpired(DateTime.now());

          // Get calculated contribution rate
          final requiredMonthly = goal.calculateRequiredMonthlyContribution(
            balance,
            DateTime.now(),
          );

          // Filter transfers relating to this Goal
          final goalTransfers = state.transactions.where((tx) {
            final belongs = tx.transferAllocations.any(
              (ta) =>
                  ta.endpointType == EndpointType.goal && ta.goalId == goal.id,
            );
            return belongs && tx.status == TransactionStatus.active;
          }).toList();

          return Scaffold(
            backgroundColor: scaffoldBg,
            appBar: AppBar(
              backgroundColor: scaffoldBg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(LucideIcons.arrowLeft, color: textPrimary),
                onPressed: () {
                  sl<HapticService>().selectionClick();
                  context.pop(true); // Pop with true to notify listing updates
                },
              ),
              title: Text(
                goal.name.toUpperCase(),
                style: AppTypography.sectionHeading.copyWith(
                  color: textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(LucideIcons.edit2, color: textPrimary),
                  onPressed: () async {
                    sl<HapticService>().selectionClick();
                    final refresh = await context.push<bool>(
                      '/goals/edit/${goal.id}',
                    );
                    if (refresh == true) {
                      context.read<GoalsBloc>().add(const LoadGoals());
                    }
                  },
                ),
              ],
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      border: Border.all(color: borderCol),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _getIconData(goal.icon),
                          size: 40,
                          color: textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'TOTAL SAVINGS',
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _formatAmount(balance, goal.currency),
                          style: AppTypography.display.copyWith(
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        // Progress Bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.small),
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
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Target: ${_formatAmount(goal.targetAmount, goal.currency)} (${percent.toStringAsFixed(0)}%)',
                              style: AppTypography.caption.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              isExpired
                                  ? 'EXPIRED'
                                  : 'Target Date: ${_formatDate(goal.effectiveTargetDate)}',
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

                        if (!isExpired && balance < goal.targetAmount) ...[
                          const SizedBox(height: AppSpacing.md),
                          Divider(color: borderCol),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Required savings: ${_formatAmount(requiredMonthly, goal.currency)} / month to hit target',
                            style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColors.darkAccentPrimary
                                  : AppColors.lightAccentPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Actions row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderCol),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            LucideIcons.arrowUpRight,
                            color: AppColors.statusSuccess,
                          ),
                          label: Text(
                            'CONTRIBUTE',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            sl<HapticService>().mediumImpact();
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => ContributeGoalDialog(
                                goal: goal,
                                accounts: state.accounts,
                                onSave: (sourceAccountId, amount, date) {
                                  context.read<GoalsBloc>().add(
                                    ContributeToGoal(
                                      goalId: goal.id,
                                      sourceAccountId: sourceAccountId,
                                      amount: amount,
                                      date: date,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: borderCol),
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                            ),
                          ),
                          icon: const Icon(
                            LucideIcons.arrowDownLeft,
                            color: AppColors.statusWarning,
                          ),
                          label: Text(
                            'WITHDRAW',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            sl<HapticService>().mediumImpact();
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => WithdrawGoalDialog(
                                goal: goal,
                                currentBalance: balance,
                                accounts: state.accounts,
                                onSave: (destinationAccountId, amount, date) {
                                  context.read<GoalsBloc>().add(
                                    WithdrawFromGoal(
                                      goalId: goal.id,
                                      destinationAccountId:
                                          destinationAccountId,
                                      amount: amount,
                                      date: date,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // History logs
                  Text(
                    'TRANSFER HISTORY',
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (goalTransfers.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No contributions or withdrawals recorded yet.',
                          style: AppTypography.body.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: goalTransfers.length,
                      itemBuilder: (context, index) {
                        final tx = goalTransfers[index];

                        // Detect role of goal in transfers to check if contribution or withdrawal
                        final isContribution = tx.transferAllocations.any(
                          (ta) =>
                              ta.endpointType == EndpointType.goal &&
                              ta.goalId == goal.id &&
                              ta.role == AllocationRole.destination,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(
                              AppRadius.medium,
                            ),
                            border: Border.all(color: borderCol),
                          ),
                          child: ListTile(
                            title: Text(
                              tx.note?.isNotEmpty == true
                                  ? tx.note!
                                  : (isContribution
                                        ? 'Contribution'
                                        : 'Withdrawal'),
                              style: AppTypography.body.copyWith(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _formatDate(tx.date),
                              style: AppTypography.caption.copyWith(
                                color: textSecondary,
                              ),
                            ),
                            trailing: Text(
                              '${isContribution ? "+" : "-"}${_formatAmount(tx.totalAmount, tx.currency)}',
                              style: AppTypography.body.copyWith(
                                color: isContribution
                                    ? AppColors.statusSuccess
                                    : AppColors.statusWarning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
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
}
