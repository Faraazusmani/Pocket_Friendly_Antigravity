import 'package:equatable/equatable.dart';
import '../../domain/account.dart';

abstract class AccountsEvent extends Equatable {
  const AccountsEvent();

  @override
  List<Object?> get props => [];
}

class LoadAccounts extends AccountsEvent {
  const LoadAccounts();
}

class CreateAccount extends AccountsEvent {
  final String name;
  final AccountType type;
  final int openingBalance; // minor units
  final String currency;
  final String icon;
  final int? creditLimit; // minor units
  final int? openingOutstanding; // minor units
  final int? billGenerationDay;

  const CreateAccount({
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.currency,
    required this.icon,
    this.creditLimit,
    this.openingOutstanding,
    this.billGenerationDay,
  });

  @override
  List<Object?> get props => [
    name,
    type,
    openingBalance,
    currency,
    icon,
    creditLimit,
    openingOutstanding,
    billGenerationDay,
  ];
}

class UpdateAccount extends AccountsEvent {
  final String accountId;
  final String name;
  final AccountType type;
  final String currency;
  final String icon;
  final int? creditLimit;
  final int? openingOutstanding;
  final int? billGenerationDay;

  const UpdateAccount({
    required this.accountId,
    required this.name,
    required this.type,
    required this.currency,
    required this.icon,
    this.creditLimit,
    this.openingOutstanding,
    this.billGenerationDay,
  });

  @override
  List<Object?> get props => [
    accountId,
    name,
    type,
    currency,
    icon,
    creditLimit,
    openingOutstanding,
    billGenerationDay,
  ];
}

class ArchiveAccount extends AccountsEvent {
  final String accountId;

  const ArchiveAccount(this.accountId);

  @override
  List<Object?> get props => [accountId];
}

class AdjustAccountBalance extends AccountsEvent {
  final String accountId;
  final int actualBalance; // minor units

  const AdjustAccountBalance({
    required this.accountId,
    required this.actualBalance,
  });

  @override
  List<Object?> get props => [accountId, actualBalance];
}
