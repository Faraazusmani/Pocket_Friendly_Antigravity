import 'package:equatable/equatable.dart';
import '../../domain/goal.dart';
import '../../../accounts/domain/account.dart';
import '../../../categories/domain/category.dart';
import '../../../transactions/domain/transaction.dart';

abstract class GoalsState extends Equatable {
  const GoalsState();

  @override
  List<Object?> get props => [];
}

class GoalsInitial extends GoalsState {
  const GoalsInitial();
}

class GoalsLoading extends GoalsState {
  const GoalsLoading();
}

class GoalsLoaded extends GoalsState {
  final List<Goal> goals;
  final List<Account> accounts;
  final List<Category> categories;
  final List<Transaction> transactions;

  // Pre-calculated stats for easy rendering
  final Map<String, int> goalBalances; // goalId -> current balance minor units
  final Map<String, double>
  goalProgressPercents; // goalId -> percent (0.0 to 100.0)

  const GoalsLoaded({
    required this.goals,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.goalBalances,
    required this.goalProgressPercents,
  });

  @override
  List<Object?> get props => [
    goals,
    accounts,
    categories,
    transactions,
    goalBalances,
    goalProgressPercents,
  ];

  GoalsLoaded copyWith({
    List<Goal>? goals,
    List<Account>? accounts,
    List<Category>? categories,
    List<Transaction>? transactions,
    Map<String, int>? goalBalances,
    Map<String, double>? goalProgressPercents,
  }) {
    return GoalsLoaded(
      goals: goals ?? this.goals,
      accounts: accounts ?? this.accounts,
      categories: categories ?? this.categories,
      transactions: transactions ?? this.transactions,
      goalBalances: goalBalances ?? this.goalBalances,
      goalProgressPercents: goalProgressPercents ?? this.goalProgressPercents,
    );
  }
}

class GoalsError extends GoalsState {
  final String message;

  const GoalsError(this.message);

  @override
  List<Object?> get props => [message];
}

class GoalActionSuccess extends GoalsState {
  final String message;

  const GoalActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
