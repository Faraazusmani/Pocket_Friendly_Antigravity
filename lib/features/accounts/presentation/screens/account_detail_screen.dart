import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/platform/haptic_service.dart';
import '../../domain/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import '../bloc/accounts_bloc.dart';
import '../bloc/accounts_event.dart';
import '../bloc/accounts_state.dart';
import '../widgets/adjust_balance_dialog.dart';

import '../../../../core/utilities/currency_formatter.dart';
import '../../../../core/security/privacy_mode_service.dart';

class AccountDetailScreen extends StatelessWidget {
  final String accountId;

  const AccountDetailScreen({Key? key, required this.accountId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountsBloc>(
      create: (context) => AccountsBloc(
        profileRepository: sl<ProfileRepository>(),
        accountRepository: sl<AccountRepository>(),
        transactionRepository: sl<TransactionRepository>(),
        goalRepository: sl<GoalRepository>(),
      )..add(const LoadAccounts()),
      child: AccountDetailView(accountId: accountId),
    );
  }
}

class AccountDetailView extends StatelessWidget {
  final String accountId;

  const AccountDetailView({Key? key, required this.accountId})
    : super(key: key);

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'bank':
        return LucideIcons.landmark;
      case 'wallet':
        return LucideIcons.wallet;
      case 'card':
        return LucideIcons.creditCard;
      case 'piggy':
        return LucideIcons.piggyBank;
      case 'cash':
        return LucideIcons.banknote;
      case 'coins':
        return LucideIcons.coins;
      default:
        return LucideIcons.helpCircle;
    }
  }

  String _formatAmount(int amountMinorUnits, String currency) {
    final privacyMode = sl.isRegistered<PrivacyModeService>() && sl<PrivacyModeService>().isEnabled;
    return CurrencyFormatter.format(
      amountMinorUnits,
      currency,
      privacyMode: privacyMode,
    );
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

    return BlocConsumer<AccountsBloc, AccountsState>(
      listener: (context, state) {
        if (state is AccountActionSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          // Reload the data
          context.read<AccountsBloc>().add(const LoadAccounts());
        } else if (state is AccountsError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.statusError,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is AccountsInitial || state is AccountsLoading) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is AccountsLoaded) {
          final account = state.accounts
              .where((a) => a.id == accountId)
              .firstOrNull;
          if (account == null) {
            return Scaffold(
              backgroundColor: scaffoldBg,
              appBar: AppBar(backgroundColor: scaffoldBg, elevation: 0),
              body: const Center(child: Text('Account not found.')),
            );
          }

          final isCreditCard = account.type == AccountType.creditCard;
          final int balance = isCreditCard
              ? FinancialEngine.calculateCreditCardOutstanding(
                  account,
                  state.transactions,
                )
              : FinancialEngine.calculateAccountBalance(
                  account,
                  state.transactions,
                );

          // Filter transactions matching this account
          final accountTransactions = state.transactions.where((tx) {
            final belongs = tx.transferAllocations.any(
              (ta) =>
                  ta.endpointType == EndpointType.account &&
                  ta.accountId == accountId,
            );
            return belongs && tx.status == TransactionStatus.active;
          }).toList();

          return Scaffold(
            backgroundColor: scaffoldBg,
            appBar: AppBar(
              backgroundColor: scaffoldBg,
              elevation: 0,
              leading: IconButton(
                tooltip: 'Back',
                icon: Icon(LucideIcons.arrowLeft, color: textPrimary),
                onPressed: () {
                  sl<HapticService>().selectionClick();
                  context.pop(
                    true,
                  ); // Pop with true to notify parent to refresh
                },
              ),
              title: Text(
                account.name.toUpperCase(),
                style: AppTypography.sectionHeading.copyWith(
                  color: textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Edit Account',
                  icon: Icon(LucideIcons.edit2, color: textPrimary),
                  onPressed: () async {
                    sl<HapticService>().selectionClick();
                    final refresh = await context.push<bool>(
                      '/accounts/edit/${account.id}',
                    );
                    if (refresh == true) {
                      context.read<AccountsBloc>().add(const LoadAccounts());
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
                  // Hero Balance Display
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
                          _getIconData(account.icon),
                          size: 40,
                          color: textSecondary,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          isCreditCard
                              ? 'OUTSTANDING BALANCE'
                              : 'CURRENT BALANCE',
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _formatAmount(balance, account.currency),
                          style: AppTypography.display.copyWith(
                            color: isCreditCard && balance > 0
                                ? AppColors.statusError
                                : textPrimary,
                          ),
                        ),
                        if (isCreditCard) ...[
                          const SizedBox(height: AppSpacing.md),
                          Divider(color: borderCol),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'CREDIT LIMIT',
                                    style: AppTypography.caption.copyWith(
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _formatAmount(
                                      account.creditLimit ?? 0,
                                      account.currency,
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
                                    'AVAILABLE CREDIT',
                                    style: AppTypography.caption.copyWith(
                                      color: textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _formatAmount(
                                      FinancialEngine.calculateCreditCardAvailableCredit(
                                        account,
                                        state.transactions,
                                      ),
                                      account.currency,
                                    ),
                                    style: const TextStyle(
                                      color: AppColors.darkAccentPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Bill Generation: Day ${account.billGenerationDay} of every month',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Quick Action Buttons
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
                          icon: Icon(LucideIcons.sliders, color: textPrimary),
                          label: Text(
                            'ADJUST BALANCE',
                            style: TextStyle(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: () {
                            sl<HapticService>().mediumImpact();
                            showDialog(
                              context: context,
                              builder: (dialogCtx) => AdjustBalanceDialog(
                                account: account,
                                trackedBalance: balance,
                                onAdjust: (actualValue) {
                                  context.read<AccountsBloc>().add(
                                    AdjustAccountBalance(
                                      accountId: account.id,
                                      actualBalance: actualValue,
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

                  // Transaction History list
                  Text(
                    'TRANSACTION HISTORY',
                    style: AppTypography.caption.copyWith(
                      color: textSecondary,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (accountTransactions.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'No transactions recorded for this account.',
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
                      itemCount: accountTransactions.length,
                      itemBuilder: (context, index) {
                        final tx = accountTransactions[index];
                        final isExpense = tx.type == TransactionType.expense;

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
                                  : tx.type.name.toUpperCase(),
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
                              '${isExpense ? "-" : "+"}${_formatAmount(tx.totalAmount, tx.currency)}',
                              style: AppTypography.body.copyWith(
                                color: isExpense
                                    ? AppColors.statusError
                                    : AppColors.darkAccentPrimary,
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
