import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/platform/notification_service.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../recurring_rule.dart';

abstract class RecurringRepository {
  Future<Result<List<RecurringTransactionRule>, Failure>> getActiveRules(String profileId);

  Future<Result<void, Failure>> saveRule(RecurringTransactionRule rule);

  Future<Result<void, Failure>> deactivateRule(String ruleId);

  Future<Result<List<RecurringOccurrence>, Failure>> getOccurrences(String ruleId);

  Future<Result<void, Failure>> saveOccurrence(RecurringOccurrence occurrence);

  /// Executes all pending recurring transaction occurrences up to the target date.
  Future<Result<void, Failure>> runRecurringExecution({
    required String profileId,
    required DateTime today,
    required TransactionRepository transactionRepository,
    required AccountRepository accountRepository,
    required CategoryRepository categoryRepository,
    required NotificationService notificationService,
  });
}
