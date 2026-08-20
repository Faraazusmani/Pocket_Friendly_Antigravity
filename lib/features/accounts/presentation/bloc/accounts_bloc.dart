import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../domain/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../goals/domain/goal.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import 'accounts_event.dart';
import 'accounts_state.dart';

class AccountsBloc extends Bloc<AccountsEvent, AccountsState> {
  final ProfileRepository profileRepository;
  final AccountRepository accountRepository;
  final TransactionRepository transactionRepository;
  final GoalRepository goalRepository;

  AccountsBloc({
    required this.profileRepository,
    required this.accountRepository,
    required this.transactionRepository,
    required this.goalRepository,
  }) : super(const AccountsInitial()) {
    on<LoadAccounts>(_onLoadAccounts);
    on<CreateAccount>(_onCreateAccount);
    on<UpdateAccount>(_onUpdateAccount);
    on<ArchiveAccount>(_onArchiveAccount);
    on<AdjustAccountBalance>(_onAdjustAccountBalance);
  }

  Future<void> _onLoadAccounts(
    LoadAccounts event,
    Emitter<AccountsState> emit,
  ) async {
    emit(const AccountsLoading());
    try {
      // 1. Fetch profiles
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure) {
        emit(
          AccountsError(
            'Failed to load profile: ${profilesRes.failureOrNull?.message}',
          ),
        );
        return;
      }
      final profiles = profilesRes.successOrNull!;
      if (profiles.isEmpty) {
        emit(
          const AccountsLoaded(
            accounts: [],
            transactions: [],
            goals: [],
            availableCurrencies: ['INR'],
            selectedCurrency: 'INR',
            currencyStats: {},
          ),
        );
        return;
      }
      final profile = profiles.first;
      final profileId = profile.id;

      // 2. Fetch data
      final accountsRes = await accountRepository.getAccounts(
        profileId,
        includeArchived: false,
      );
      final transactionsRes = await transactionRepository.getTransactions(
        profileId,
      );
      final goalsRes = await goalRepository.getGoals(profileId);

      final accounts = accountsRes.isSuccess
          ? accountsRes.successOrNull!
          : <Account>[];
      final transactions = transactionsRes.isSuccess
          ? transactionsRes.successOrNull!
          : <Transaction>[];
      final goals = goalsRes.isSuccess ? goalsRes.successOrNull! : <Goal>[];

      // 3. Extract currencies
      final currenciesSet = <String>{};
      for (final acc in accounts) {
        currenciesSet.add(acc.currency.toUpperCase());
      }
      for (final tx in transactions) {
        currenciesSet.add(tx.currency.toUpperCase());
      }
      if (currenciesSet.isEmpty) {
        currenciesSet.add(profile.defaultCurrency.toUpperCase());
      }
      final availableCurrencies = currenciesSet.toList()..sort();

      // 4. Calculate stats per currency
      final currencyStats = <String, Map<String, int>>{};
      for (final currency in availableCurrencies) {
        final netAvailable = FinancialEngine.calculateNetAvailableBalance(
          accounts: accounts,
          transactions: transactions,
          currency: currency,
        );
        final netWorth = FinancialEngine.calculateNetWorth(
          accounts: accounts,
          goals: goals,
          transactions: transactions,
          currency: currency,
        );

        // Calculate assets & liabilities totals
        int assets = 0;
        int liabilities = 0;
        for (final acc in accounts) {
          if (acc.currency.toUpperCase() != currency.toUpperCase() ||
              acc.status == AccountStatus.archived) {
            continue;
          }
          if (acc.type == AccountType.creditCard) {
            liabilities += FinancialEngine.calculateCreditCardOutstanding(
              acc,
              transactions,
            );
          } else {
            assets += FinancialEngine.calculateAccountBalance(
              acc,
              transactions,
            );
          }
        }

        currencyStats[currency] = {
          'netAvailableBalance': netAvailable,
          'netWorth': netWorth,
          'assets': assets,
          'liabilities': liabilities,
        };
      }

      // Default selected currency to profile default currency, or fallback to first available
      String selectedCurrency = profile.defaultCurrency.toUpperCase();
      if (!availableCurrencies.contains(selectedCurrency) &&
          availableCurrencies.isNotEmpty) {
        selectedCurrency = availableCurrencies.first;
      }

      emit(
        AccountsLoaded(
          accounts: accounts,
          transactions: transactions,
          goals: goals,
          availableCurrencies: availableCurrencies,
          selectedCurrency: selectedCurrency,
          currencyStats: currencyStats,
        ),
      );
    } catch (e) {
      emit(AccountsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onCreateAccount(
    CreateAccount event,
    Emitter<AccountsState> emit,
  ) async {
    emit(const AccountsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const AccountsError('No profile found.'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final now = DateTime.now();
      final accountRes = Account.create(
        id: const Uuid().v4(),
        profileId: profileId,
        type: event.type,
        name: event.name,
        currency: event.currency,
        icon: event.icon,
        openingBalance: event.openingBalance,
        status: AccountStatus.active,
        createdAt: now,
        updatedAt: now,
        creditLimit: event.creditLimit,
        openingOutstanding: event.openingOutstanding,
        billGenerationDay: event.billGenerationDay,
      );

      if (accountRes.isFailure) {
        emit(
          AccountsError(
            accountRes.failureOrNull?.message ?? 'Validation failed',
          ),
        );
        return;
      }

      final saveRes = await accountRepository.saveAccount(
        accountRes.successOrNull!,
      );
      if (saveRes.isFailure) {
        emit(
          AccountsError(
            saveRes.failureOrNull?.message ?? 'Failed to save account',
          ),
        );
        return;
      }

      emit(const AccountActionSuccess('Account created successfully'));
    } catch (e) {
      emit(AccountsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onUpdateAccount(
    UpdateAccount event,
    Emitter<AccountsState> emit,
  ) async {
    emit(const AccountsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const AccountsError('No profile found.'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final existingRes = await accountRepository.getAccount(
        event.accountId,
        profileId,
      );
      if (existingRes.isFailure) {
        emit(
          AccountsError(
            'Account not found: ${existingRes.failureOrNull?.message}',
          ),
        );
        return;
      }
      final existing = existingRes.successOrNull!;

      final now = DateTime.now();
      final accountRes = Account.create(
        id: existing.id,
        profileId: existing.profileId,
        type: event.type,
        name: event.name,
        currency: event.currency,
        icon: event.icon,
        openingBalance:
            existing.openingBalance, // opening balance cannot change
        status: existing.status,
        createdAt: existing.createdAt,
        updatedAt: now,
        creditLimit: event.creditLimit,
        openingOutstanding: event.openingOutstanding,
        billGenerationDay: event.billGenerationDay,
      );

      if (accountRes.isFailure) {
        emit(
          AccountsError(
            accountRes.failureOrNull?.message ?? 'Validation failed',
          ),
        );
        return;
      }

      final saveRes = await accountRepository.saveAccount(
        accountRes.successOrNull!,
      );
      if (saveRes.isFailure) {
        emit(
          AccountsError(
            saveRes.failureOrNull?.message ?? 'Failed to update account',
          ),
        );
        return;
      }

      emit(const AccountActionSuccess('Account updated successfully'));
    } catch (e) {
      emit(AccountsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onArchiveAccount(
    ArchiveAccount event,
    Emitter<AccountsState> emit,
  ) async {
    emit(const AccountsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const AccountsError('No profile found.'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final archiveRes = await accountRepository.archiveAccount(
        event.accountId,
        profileId,
      );
      if (archiveRes.isFailure) {
        emit(
          AccountsError(
            archiveRes.failureOrNull?.message ?? 'Failed to archive account',
          ),
        );
        return;
      }

      emit(const AccountActionSuccess('Account archived successfully'));
    } catch (e) {
      emit(AccountsError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onAdjustAccountBalance(
    AdjustAccountBalance event,
    Emitter<AccountsState> emit,
  ) async {
    emit(const AccountsLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const AccountsError('No profile found.'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final accountRes = await accountRepository.getAccount(
        event.accountId,
        profileId,
      );
      if (accountRes.isFailure) {
        emit(
          AccountsError(
            'Account not found: ${accountRes.failureOrNull?.message}',
          ),
        );
        return;
      }
      final account = accountRes.successOrNull!;

      final transactionsRes = await transactionRepository.getTransactions(
        profileId,
      );
      final transactions = transactionsRes.isSuccess
          ? transactionsRes.successOrNull!
          : <Transaction>[];

      // Calculate tracked balance vs actual balance
      final isCreditCard = account.type == AccountType.creditCard;
      final int trackedBalance = isCreditCard
          ? FinancialEngine.calculateCreditCardOutstanding(
              account,
              transactions,
            )
          : FinancialEngine.calculateAccountBalance(account, transactions);

      final diff = event.actualBalance - trackedBalance;
      if (diff == 0) {
        emit(const AccountActionSuccess('No balance adjustment needed'));
        return;
      }

      final now = DateTime.now();
      final String txId = const Uuid().v4();

      final TransactionType txType;
      final AllocationRole role;
      final int absAmount;

      if (isCreditCard) {
        // For credit cards, if actual outstanding (debt) is higher than tracked outstanding, we increase outstanding (Expense)
        // If actual outstanding (debt) is lower, we decrease outstanding (Income)
        if (event.actualBalance > trackedBalance) {
          txType = TransactionType.expense;
          role = AllocationRole.source;
          absAmount = event.actualBalance - trackedBalance;
        } else {
          txType = TransactionType.income;
          role = AllocationRole.destination;
          absAmount = trackedBalance - event.actualBalance;
        }
      } else {
        // For asset accounts, if actual balance is higher, we increase balance (Income)
        // If actual balance is lower, we decrease balance (Expense)
        if (event.actualBalance > trackedBalance) {
          txType = TransactionType.income;
          role = AllocationRole.destination;
          absAmount = event.actualBalance - trackedBalance;
        } else {
          txType = TransactionType.expense;
          role = AllocationRole.source;
          absAmount = trackedBalance - event.actualBalance;
        }
      }

      final ta = TransferAllocation.create(
        id: const Uuid().v4(),
        transactionId: txId,
        role: role,
        endpointType: EndpointType.account,
        accountId: account.id,
        amount: absAmount,
        currency: account.currency,
      );

      if (ta.isFailure) {
        emit(
          AccountsError(
            'Failed to create balance adjustment allocation: ${ta.failureOrNull?.message}',
          ),
        );
        return;
      }

      final txRes = Transaction.create(
        id: txId,
        profileId: profileId,
        type: txType,
        subtype: 'balanceAdjustment',
        date: now,
        currency: account.currency,
        totalAmount: absAmount,
        paymentModeId: account.id, // Using account ID directly as reference
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [],
        transferAllocations: [ta.successOrNull!],
        note: 'Balance Adjustment',
      );

      if (txRes.isFailure) {
        emit(
          AccountsError(
            'Failed to create balance adjustment transaction: ${txRes.failureOrNull?.message}',
          ),
        );
        return;
      }

      final saveTxRes = await transactionRepository.saveTransaction(
        txRes.successOrNull!,
      );
      if (saveTxRes.isFailure) {
        emit(
          AccountsError(
            saveTxRes.failureOrNull?.message ??
                'Failed to save balance adjustment transaction',
          ),
        );
        return;
      }

      emit(const AccountActionSuccess('Balance adjusted successfully'));
    } catch (e) {
      emit(AccountsError('An unexpected error occurred: $e'));
    }
  }
}
