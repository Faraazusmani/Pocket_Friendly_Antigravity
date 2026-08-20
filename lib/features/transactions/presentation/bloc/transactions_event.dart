import 'package:equatable/equatable.dart';
import '../../domain/transaction.dart';

abstract class TransactionsEvent extends Equatable {
  const TransactionsEvent();

  @override
  List<Object?> get props => [];
}

class LoadTransactionFormMetadata extends TransactionsEvent {
  const LoadTransactionFormMetadata();
}

class SaveTransaction extends TransactionsEvent {
  final TransactionType type;
  final int totalAmount; // minor units
  final DateTime date;
  final String paymentModeId;
  final String? note;
  final String? tagId;
  final List<CategoryAllocationInput> categoryAllocations;
  final List<TransferAllocationInput> transferAllocations;

  // Optional recurring parameters
  final bool isRecurring;
  final String? recurringFrequency; // daily, weekly, monthly, yearly
  final bool isAutoRecord; // default true/false

  const SaveTransaction({
    required this.type,
    required this.totalAmount,
    required this.date,
    required this.paymentModeId,
    this.note,
    this.tagId,
    required this.categoryAllocations,
    required this.transferAllocations,
    this.isRecurring = false,
    this.recurringFrequency,
    this.isAutoRecord = true,
  });

  @override
  List<Object?> get props => [
    type,
    totalAmount,
    date,
    paymentModeId,
    note,
    tagId,
    categoryAllocations,
    transferAllocations,
    isRecurring,
    recurringFrequency,
    isAutoRecord,
  ];
}

class CategoryAllocationInput {
  final String categoryId;
  final int amount; // minor units

  const CategoryAllocationInput({
    required this.categoryId,
    required this.amount,
  });
}

class TransferAllocationInput {
  final String role; // source, destination
  final String endpointType; // account, goal
  final String? accountId;
  final String? goalId;
  final int amount; // minor units

  const TransferAllocationInput({
    required this.role,
    required this.endpointType,
    this.accountId,
    this.goalId,
    required this.amount,
  });
}
