import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pocket_friendly/core/di/service_locator.dart';
import 'package:pocket_friendly/core/design_system/tokens.dart';
import 'package:pocket_friendly/core/platform/haptic_service.dart';
import 'package:pocket_friendly/core/utilities/currency_formatter.dart';
import 'package:pocket_friendly/features/profiles/domain/repositories/profile_repository.dart';
import 'package:pocket_friendly/features/accounts/domain/repositories/account_repository.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/goals/domain/repositories/goal_repository.dart';
import '../../domain/account.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import '../bloc/accounts_bloc.dart';
import '../bloc/accounts_event.dart';
import '../bloc/accounts_state.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AccountsBloc>(
      create: (context) => AccountsBloc(
        profileRepository: sl<ProfileRepository>(),
        accountRepository: sl<AccountRepository>(),
        transactionRepository: sl<TransactionRepository>(),
        goalRepository: sl<GoalRepository>(),
      )..add(const LoadAccounts()),
      child: const AccountsView(),
    );
  }
}

class AccountsView extends StatefulWidget {
  const AccountsView({Key? key}) : super(key: key);

  @override
  State<AccountsView> createState() => _AccountsViewState();
}

class _AccountsViewState extends State<AccountsView> {
  String? _selectedCurrencyOverride;

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

  String _formatAmount(int amountMinorUnits, String currency, bool privacyMode) {
    return CurrencyFormatter.format(
      amountMinorUnits,
      currency,
      privacyMode: privacyMode,
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

    return BlocBuilder<AccountsBloc, AccountsState>(
      builder: (context, state) {
        if (state is AccountsInitial || state is AccountsLoading) {
          return Scaffold(
            backgroundColor: scaffoldBg,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (state is AccountsError) {
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

        if (state is AccountsLoaded) {
          final activeCurrency =
              _selectedCurrencyOverride ?? state.selectedCurrency;

          // Group accounts by type
          final bankAccounts = state.accounts
              .where(
                (a) =>
                    a.type == AccountType.bank &&
                    a.currency.toUpperCase() == activeCurrency.toUpperCase(),
              )
              .toList();
          final cashAccounts = state.accounts
              .where(
                (a) =>
                    a.type == AccountType.cash &&
                    a.currency.toUpperCase() == activeCurrency.toUpperCase(),
              )
              .toList();
          final cardAccounts = state.accounts
              .where(
                (a) =>
                    a.type == AccountType.creditCard &&
                    a.currency.toUpperCase() == activeCurrency.toUpperCase(),
              )
              .toList();

          final stats =
              state.currencyStats[activeCurrency] ??
              {
                'netAvailableBalance': 0,
                'netWorth': 0,
                'assets': 0,
                'liabilities': 0,
              };

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
                  context.pop();
                },
              ),
              title: Text(
                'ACCOUNTS',
                style: AppTypography.sectionHeading.copyWith(
                  color: textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              actions: [
                // Currency dropdown filter
                if (state.availableCurrencies.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: DropdownButton<String>(
                      value: activeCurrency,
                      dropdownColor: cardBg,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                      underline: const SizedBox(),
                      items: state.availableCurrencies
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          sl<HapticService>().selectionClick();
                          setState(() {
                            _selectedCurrencyOverride = val;
                          });
                        }
                      },
                    ),
                  ),
              ],
            ),
            body: RefreshIndicator(
              onRefresh: () async {
                context.read<AccountsBloc>().add(const LoadAccounts());
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Net Worth Hero Card
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        border: Border.all(color: borderCol),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [
                                  AppColors.darkSurfacePrimary,
                                  AppColors.darkSurfacePrimary.withOpacity(0.8),
                                ]
                              : [
                                  AppColors.lightSurfacePrimary,
                                  AppColors.lightSurfacePrimary.withOpacity(
                                    0.9,
                                  ),
                                ],
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'NET WORTH',
                            style: AppTypography.caption.copyWith(
                              color: textSecondary,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            _formatAmount(
                              stats['netWorth'] ?? 0,
                              activeCurrency,
                              state.privacyModeEnabled,
                            ),
                            style: AppTypography.display.copyWith(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Divider(color: borderCol, height: 1),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'TOTAL ASSETS',
                                    style: AppTypography.caption.copyWith(
                                      color: textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _formatAmount(
                                      stats['assets'] ?? 0,
                                      activeCurrency,
                                      state.privacyModeEnabled,
                                    ),
                                    style: AppTypography.body.copyWith(
                                      color: isDark
                                          ? AppColors.darkAccentPrimary
                                          : AppColors.lightAccentPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(height: 30, width: 1, color: borderCol),
                              Column(
                                children: [
                                  Text(
                                    'LIABILITIES',
                                    style: AppTypography.caption.copyWith(
                                      color: textSecondary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    _formatAmount(
                                      stats['liabilities'] ?? 0,
                                      activeCurrency,
                                      state.privacyModeEnabled,
                                    ),
                                    style: AppTypography.body.copyWith(
                                      color: AppColors.statusError,
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
                    const SizedBox(height: AppSpacing.lg),

                    // Account Groups
                    if (bankAccounts.isNotEmpty) ...[
                      _buildSectionHeader('BANK ACCOUNTS', textSecondary),
                      ...bankAccounts.map(
                        (acc) => _buildAccountTile(
                          context,
                          acc,
                          state.transactions,
                          borderCol,
                          cardBg,
                          textPrimary,
                          textSecondary,
                          state.privacyModeEnabled,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    if (cashAccounts.isNotEmpty) ...[
                      _buildSectionHeader('CASH', textSecondary),
                      ...cashAccounts.map(
                        (acc) => _buildAccountTile(
                          context,
                          acc,
                          state.transactions,
                          borderCol,
                          cardBg,
                          textPrimary,
                          textSecondary,
                          state.privacyModeEnabled,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    if (cardAccounts.isNotEmpty) ...[
                      _buildSectionHeader('CREDIT CARDS', textSecondary),
                      ...cardAccounts.map(
                        (acc) => _buildAccountTile(
                          context,
                          acc,
                          state.transactions,
                          borderCol,
                          cardBg,
                          textPrimary,
                          textSecondary,
                          state.privacyModeEnabled,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                    ],

                    if (bankAccounts.isEmpty &&
                        cashAccounts.isEmpty &&
                        cardAccounts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                          border: Border.all(color: borderCol),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.wallet,
                                size: 48,
                                color: textSecondary,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'No Active Accounts',
                                style: AppTypography.sectionHeading.copyWith(
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Add a bank account or cash to start tracking your finances in $activeCurrency.',
                                textAlign: TextAlign.center,
                                style: AppTypography.secondaryBody.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDark
                                      ? AppColors.darkAccentPrimary
                                      : AppColors.lightAccentPrimary,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      AppRadius.medium,
                                    ),
                                  ),
                                ),
                                icon: const Icon(LucideIcons.plus, size: 16),
                                label: const Text('ADD ACCOUNT'),
                                onPressed: () async {
                                  sl<HapticService>().mediumImpact();
                                  final refresh = await context.push<bool>('/accounts/create');
                                  if (refresh == true) {
                                    context.read<AccountsBloc>().add(const LoadAccounts());
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
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
                final refresh = await context.push<bool>('/accounts/create');
                if (refresh == true) {
                  context.read<AccountsBloc>().add(const LoadAccounts());
                }
              },
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.xs,
        bottom: AppSpacing.sm,
      ),
      child: Text(
        title,
        style: AppTypography.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    Account account,
    List<Transaction> transactions,
    Color borderCol,
    Color cardBg,
    Color textPrimary,
    Color textSecondary,
    bool privacyMode,
  ) {
    final isCreditCard = account.type == AccountType.creditCard;
    final int balance = isCreditCard
        ? FinancialEngine.calculateCreditCardOutstanding(account, transactions)
        : FinancialEngine.calculateAccountBalance(account, transactions);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: borderCol),
      ),
      child: ListTile(
        leading: Icon(_getIconData(account.icon), color: textSecondary),
        title: Text(
          account.name,
          style: AppTypography.body.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatAmount(balance, account.currency, privacyMode),
              style: AppTypography.body.copyWith(
                color: isCreditCard
                    ? (balance > 0 ? AppColors.statusError : textPrimary)
                    : textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (isCreditCard)
              Text(
                'Outstanding',
                style: AppTypography.caption.copyWith(color: textSecondary),
              ),
          ],
        ),
        onTap: () async {
          sl<HapticService>().selectionClick();
          final refresh = await context.push<bool>('/accounts/${account.id}');
          if (refresh == true) {
            context.read<AccountsBloc>().add(const LoadAccounts());
          }
        },
      ),
    );
  }
}
