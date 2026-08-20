import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../transaction.dart';

abstract class TransactionRepository {
  Future<Result<Transaction, Failure>> getTransaction(
    String transactionId,
    String profileId,
  );

  Future<Result<List<Transaction>, Failure>> getTransactions(
    String profileId, {
    bool includeArchived = false,
  });

  Future<Result<void, Failure>> saveTransaction(Transaction transaction);

  Future<Result<void, Failure>> deleteTransaction(
    String transactionId,
    String profileId,
  );
}
