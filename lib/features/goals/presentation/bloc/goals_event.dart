import 'package:equatable/equatable.dart';
import '../../domain/goal.dart';

abstract class GoalsEvent extends Equatable {
  const GoalsEvent();

  @override
  List<Object?> get props => [];
}

class LoadGoals extends GoalsEvent {
  const LoadGoals();
}

class CreateGoal extends GoalsEvent {
  final String name;
  final String icon;
  final GoalType goalType;
  final int targetAmount; // minor units
  final DateTime? targetDate;
  final String? description;

  const CreateGoal({
    required this.name,
    required this.icon,
    required this.goalType,
    required this.targetAmount,
    this.targetDate,
    this.description,
  });

  @override
  List<Object?> get props => [
    name,
    icon,
    goalType,
    targetAmount,
    targetDate,
    description,
  ];
}

class UpdateGoal extends GoalsEvent {
  final String goalId;
  final String name;
  final String icon;
  final GoalType goalType;
  final int targetAmount; // minor units
  final DateTime? targetDate;
  final String? description;

  const UpdateGoal({
    required this.goalId,
    required this.name,
    required this.icon,
    required this.goalType,
    required this.targetAmount,
    this.targetDate,
    this.description,
  });

  @override
  List<Object?> get props => [
    goalId,
    name,
    icon,
    goalType,
    targetAmount,
    targetDate,
    description,
  ];
}

class ArchiveGoal extends GoalsEvent {
  final String goalId;

  const ArchiveGoal(this.goalId);

  @override
  List<Object?> get props => [goalId];
}

class ContributeToGoal extends GoalsEvent {
  final String goalId;
  final String sourceAccountId;
  final int amount; // minor units
  final DateTime date;

  const ContributeToGoal({
    required this.goalId,
    required this.sourceAccountId,
    required this.amount,
    required this.date,
  });

  @override
  List<Object?> get props => [goalId, sourceAccountId, amount, date];
}

class WithdrawFromGoal extends GoalsEvent {
  final String goalId;
  final String destinationAccountId;
  final int amount; // minor units
  final DateTime date;

  const WithdrawFromGoal({
    required this.goalId,
    required this.destinationAccountId,
    required this.amount,
    required this.date,
  });

  @override
  List<Object?> get props => [goalId, destinationAccountId, amount, date];
}
