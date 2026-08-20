import 'package:equatable/equatable.dart';
import '../../../accounts/domain/account.dart';
import '../../../accounts/domain/payment_mode.dart';
import '../../../categories/domain/category.dart';
import '../../../categories/domain/tag.dart';
import '../../../goals/domain/goal.dart';

abstract class TransactionsState extends Equatable {
  const TransactionsState();

  @override
  List<Object?> get props => [];
}

class TransactionFormInitial extends TransactionsState {
  const TransactionFormInitial();
}

class TransactionFormLoading extends TransactionsState {
  const TransactionFormLoading();
}

class TransactionFormMetadataLoaded extends TransactionsState {
  final List<Account> accounts;
  final List<Category> categories;
  final List<Goal> goals;
  final List<Tag> tags;
  final List<PaymentMode> paymentModes;
  final String profileId;
  final String defaultCurrency;

  const TransactionFormMetadataLoaded({
    required this.accounts,
    required this.categories,
    required this.goals,
    required this.tags,
    required this.paymentModes,
    required this.profileId,
    required this.defaultCurrency,
  });

  @override
  List<Object?> get props => [
    accounts,
    categories,
    goals,
    tags,
    paymentModes,
    profileId,
    defaultCurrency,
  ];
}

class TransactionSaveSuccess extends TransactionsState {
  final String message;

  const TransactionSaveSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class TransactionFormError extends TransactionsState {
  final String message;

  const TransactionFormError(this.message);

  @override
  List<Object?> get props => [message];
}
