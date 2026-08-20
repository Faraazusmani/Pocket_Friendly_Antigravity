import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../domain/transaction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../../recurring/domain/recurring_rule.dart';
import '../../../recurring/domain/repositories/recurring_repository.dart';
import 'transactions_event.dart';
import 'transactions_state.dart';

class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  final ProfileRepository profileRepository;
  final AccountRepository accountRepository;
  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;
  final GoalRepository goalRepository;
  final RecurringRepository recurringRepository;

  TransactionsBloc({
    required this.profileRepository,
    required this.accountRepository,
    required this.categoryRepository,
    required this.transactionRepository,
    required this.goalRepository,
    required this.recurringRepository,
  }) : super(const TransactionFormInitial()) {
    on<LoadTransactionFormMetadata>(_onLoadMetadata);
    on<SaveTransaction>(_onSaveTransaction);
  }

  Future<void> _onLoadMetadata(
    LoadTransactionFormMetadata event,
    Emitter<TransactionsState> emit,
  ) async {
    emit(const TransactionFormLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const TransactionFormError('No active profile found'));
        return;
      }
      final profile = profilesRes.successOrNull!.first;
      final profileId = profile.id;

      final accountsRes = await accountRepository.getAccounts(
        profileId,
        includeArchived: false,
      );
      final categoriesRes = await categoryRepository.getCategories(
        profileId,
        includeArchived: false,
      );
      final goalsRes = await goalRepository.getGoals(
        profileId,
        includeArchived: false,
      );
      final tagsRes = await categoryRepository.getTags(profileId);
      final paymentModesRes = await accountRepository.getPaymentModes(
        profileId,
        includeArchived: false,
      );

      emit(
        TransactionFormMetadataLoaded(
          accounts: accountsRes.isSuccess ? accountsRes.successOrNull! : [],
          categories: categoriesRes.isSuccess
              ? categoriesRes.successOrNull!
              : [],
          goals: goalsRes.isSuccess ? goalsRes.successOrNull! : [],
          tags: tagsRes.isSuccess ? tagsRes.successOrNull! : [],
          paymentModes: paymentModesRes.isSuccess
              ? paymentModesRes.successOrNull!
              : [],
          profileId: profileId,
          defaultCurrency: profile.defaultCurrency,
        ),
      );
    } catch (e) {
      emit(TransactionFormError('Failed to load transaction metadata: $e'));
    }
  }

  Future<void> _onSaveTransaction(
    SaveTransaction event,
    Emitter<TransactionsState> emit,
  ) async {
    final current = state;
    if (current is! TransactionFormMetadataLoaded) {
      emit(const TransactionFormError('Metadata not loaded'));
      return;
    }

    emit(const TransactionFormLoading());
    try {
      final txId = const Uuid().v4();
      final now = DateTime.now();

      // 1. Map CategoryAllocations
      final categoryAllocations = <CategoryAllocation>[];
      for (final ca in event.categoryAllocations) {
        final res = CategoryAllocation.create(
          id: const Uuid().v4(),
          transactionId: txId,
          categoryId: ca.categoryId,
          amount: ca.amount,
          currency: current.defaultCurrency,
        );
        if (res.isFailure) {
          emit(
            TransactionFormError(
              res.failureOrNull?.message ?? 'Category allocation invalid',
            ),
          );
          return;
        }
        categoryAllocations.add(res.successOrNull!);
      }

      // 2. Map TransferAllocations
      final transferAllocations = <TransferAllocation>[];
      for (final ta in event.transferAllocations) {
        final res = TransferAllocation.create(
          id: const Uuid().v4(),
          transactionId: txId,
          role: ta.role == 'source'
              ? AllocationRole.source
              : AllocationRole.destination,
          endpointType: ta.endpointType == 'account'
              ? EndpointType.account
              : EndpointType.goal,
          accountId: ta.accountId,
          goalId: ta.goalId,
          amount: ta.amount,
          currency: current.defaultCurrency,
        );
        if (res.isFailure) {
          emit(
            TransactionFormError(
              res.failureOrNull?.message ?? 'Transfer allocation invalid',
            ),
          );
          return;
        }
        transferAllocations.add(res.successOrNull!);
      }

      // 3. Create Transaction Domain entity
      final txRes = Transaction.create(
        id: txId,
        profileId: current.profileId,
        type: event.type,
        date: event.date,
        currency: current.defaultCurrency,
        totalAmount: event.totalAmount,
        paymentModeId: event.paymentModeId,
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        note: event.note,
        tagId: event.tagId,
        categoryAllocations: categoryAllocations,
        transferAllocations: transferAllocations,
      );

      if (txRes.isFailure) {
        emit(
          TransactionFormError(
            txRes.failureOrNull?.message ?? 'Transaction validation failed',
          ),
        );
        return;
      }

      final transaction = txRes.successOrNull!;

      // 4. Validate payment mode compatibility with accounts
      final paymentMode = current.paymentModes
          .where((pm) => pm.id == event.paymentModeId)
          .firstOrNull;
      if (paymentMode != null) {
        for (final ta in transferAllocations) {
          if (ta.endpointType == EndpointType.account && ta.accountId != null) {
            final acc = current.accounts
                .where((a) => a.id == ta.accountId)
                .firstOrNull;
            if (acc != null && !paymentMode.isCompatibleWith(acc.type)) {
              emit(
                TransactionFormError(
                  'Payment mode "${paymentMode.name}" is incompatible with account "${acc.name}"',
                ),
              );
              return;
            }
          }
        }
      }

      // 5. Commit Transaction to repository atomically
      await transactionRepository.saveTransaction(transaction);

      // 6. Save Recurring Rule if selected
      if (event.isRecurring && event.recurringFrequency != null) {
        final frequency = RecurringFrequency.values.byName(
          event.recurringFrequency!,
        );
        final template = {
          'type': event.type.name,
          'totalAmount': event.totalAmount,
          'paymentModeId': event.paymentModeId,
          'note': event.note,
          'tagId': event.tagId,
          'categoryAllocations': event.categoryAllocations
              .map((c) => {'categoryId': c.categoryId, 'amount': c.amount})
              .toList(),
          'transferAllocations': event.transferAllocations
              .map(
                (t) => {
                  'role': t.role,
                  'endpointType': t.endpointType,
                  'accountId': t.accountId,
                  'goalId': t.goalId,
                  'amount': t.amount,
                },
              )
              .toList(),
        };

        // Day of period: clamping between 1 and 31
        final dayOfPeriod = event.date.day.clamp(1, 31);

        final ruleRes = RecurringTransactionRule.create(
          id: const Uuid().v4(),
          profileId: current.profileId,
          transactionTemplate: jsonEncode(template),
          frequency: frequency,
          dayOfPeriod: dayOfPeriod,
          mode: event.isAutoRecord
              ? RecurringMode.automaticRecording
              : RecurringMode.reminder,
          nextOccurrence:
              event.date, // first occurrence is on date or computed next
          active: true,
          createdAt: now,
          updatedAt: now,
        );

        if (ruleRes.isSuccess) {
          await recurringRepository.saveRule(ruleRes.successOrNull!);
        }
      }

      emit(const TransactionSaveSuccess('Transaction recorded successfully'));
    } catch (e) {
      emit(TransactionFormError('Failed to save transaction: $e'));
    }
  }
}
