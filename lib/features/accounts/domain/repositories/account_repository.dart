import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../account.dart';
import '../credit_card_statement.dart';
import '../payment_mode.dart';

abstract class AccountRepository {
  Future<Result<Account, Failure>> getAccount(
    String accountId,
    String profileId,
  );

  Future<Result<List<Account>, Failure>> getAccounts(
    String profileId, {
    bool includeArchived = false,
  });

  Future<Result<void, Failure>> saveAccount(Account account);

  Future<Result<void, Failure>> archiveAccount(
    String accountId,
    String profileId,
  );

  // Credit Card Statement operations
  Future<Result<List<CreditCardStatement>, Failure>> getCreditCardStatements(
    String accountId,
    String profileId,
  );

  Future<Result<void, Failure>> saveCreditCardStatement(
    CreditCardStatement statement,
  );

  Future<Result<void, Failure>> generateStatementIfNeeded(
    String accountId,
    String profileId,
    DateTime targetDate,
  );

  // Payment Mode management is hosted under Accounts feature context
  Future<Result<PaymentMode, Failure>> getPaymentMode(
    String modeId,
    String profileId,
  );

  Future<Result<List<PaymentMode>, Failure>> getPaymentModes(
    String profileId, {
    bool includeArchived = false,
  });

  Future<Result<void, Failure>> savePaymentMode(PaymentMode mode);

  Future<Result<void, Failure>> archivePaymentMode(
    String modeId,
    String profileId,
  );
}
