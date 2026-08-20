import 'package:equatable/equatable.dart';
import '../../domain/account.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../goals/domain/goal.dart';

abstract class AccountsState extends Equatable {
  const AccountsState();

  @override
  List<Object?> get props => [];
}

class AccountsInitial extends AccountsState {
  const AccountsInitial();
}

class AccountsLoading extends AccountsState {
  const AccountsLoading();
}

class AccountsLoaded extends AccountsState {
  final List<Account> accounts;
  final List<Transaction> transactions;
  final List<Goal> goals;
  final List<String> availableCurrencies;
  final String selectedCurrency;

  // Calculated stats mapping currency -> { 'netAvailableBalance': int, 'netWorth': int, 'assets': int, 'liabilities': int }
  final Map<String, Map<String, int>> currencyStats;

  const AccountsLoaded({
    required this.accounts,
    required this.transactions,
    required this.goals,
    required this.availableCurrencies,
    required this.selectedCurrency,
    required this.currencyStats,
  });

  @override
  List<Object?> get props => [
    accounts,
    transactions,
    goals,
    availableCurrencies,
    selectedCurrency,
    currencyStats,
  ];

  AccountsLoaded copyWith({
    List<Account>? accounts,
    List<Transaction>? transactions,
    List<Goal>? goals,
    List<String>? availableCurrencies,
    String? selectedCurrency,
    Map<String, Map<String, int>>? currencyStats,
  }) {
    return AccountsLoaded(
      accounts: accounts ?? this.accounts,
      transactions: transactions ?? this.transactions,
      goals: goals ?? this.goals,
      availableCurrencies: availableCurrencies ?? this.availableCurrencies,
      selectedCurrency: selectedCurrency ?? this.selectedCurrency,
      currencyStats: currencyStats ?? this.currencyStats,
    );
  }
}

class AccountsError extends AccountsState {
  final String message;

  const AccountsError(this.message);

  @override
  List<Object?> get props => [message];
}

class AccountActionSuccess extends AccountsState {
  final String message;

  const AccountActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
