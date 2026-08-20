import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../transactions/domain/services/financial_engine.dart';
import '../account.dart';
import '../credit_card_statement.dart';
import '../repositories/account_repository.dart';

class CreditCardService {
  /// Evaluates whether same-currency liquid bank funds are sufficient to cover
  /// the credit card outstanding balance plus the new purchase.
  /// Excludes Cash, Cards, Goals. Warns (returns String) but never blocks.
  static String? evaluateRepaymentFunds({
    required Account card,
    required int purchaseAmount,
    required List<Account> accounts,
    required List<Transaction> transactions,
  }) {
    if (card.type != AccountType.creditCard) return null;

    final outstanding = FinancialEngine.calculateCreditCardOutstanding(
      card,
      transactions,
    );
    final targetCurrency = card.currency.toUpperCase();

    int totalBankBalance = 0;
    for (final acc in accounts) {
      if (acc.type == AccountType.bank &&
          acc.currency.toUpperCase() == targetCurrency &&
          acc.status == AccountStatus.active) {
        totalBankBalance += FinancialEngine.calculateAccountBalance(
          acc,
          transactions,
        );
      }
    }

    final needed = outstanding + purchaseAmount;
    if (totalBankBalance < needed) {
      return 'Warning: Same-currency bank balance ($totalBankBalance) is insufficient to cover the credit card outstanding plus purchase ($needed).';
    }

    return null;
  }

  /// Executes an atomic Credit Card statement settlement.
  /// Generates a Transfer transaction from Bank to Card, and marks the statement as settled.
  static Future<Result<void, Failure>> settleCreditCardStatement({
    required CreditCardStatement statement,
    required String bankAccountId,
    required String paymentModeId,
    required TransactionRepository transactionRepository,
    required AccountRepository accountRepository,
    required DateTime settlementDate,
  }) async {
    try {
      if (statement.isSettled) {
        return const Success(null); // Already settled
      }

      // 1. Fetch bank account and credit card account to validate
      final bankRes = await accountRepository.getAccount(
        bankAccountId,
        statement.profileId,
      );
      if (bankRes.isFailure) return FailureResult(bankRes.failureOrNull!);
      final bank = bankRes.successOrNull!;

      final cardRes = await accountRepository.getAccount(
        statement.accountId,
        statement.profileId,
      );
      if (cardRes.isFailure) return FailureResult(cardRes.failureOrNull!);
      final card = cardRes.successOrNull!;

      if (bank.type != AccountType.bank) {
        return const FailureResult(
          ValidationFailure('Settlement source must be a bank account'),
        );
      }
      if (bank.currency.toUpperCase() != card.currency.toUpperCase()) {
        return const FailureResult(
          ValidationFailure('Bank and Credit Card currency must match'),
        );
      }

      // 2. Build the settlement Transfer transaction
      final txId = 'tx_settle_${statement.id}';

      final srcAllocation = TransferAllocation.create(
        id: 'ta_settle_src_${statement.id}',
        transactionId: txId,
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: bankAccountId,
        amount: statement.outstandingAmount,
        currency: card.currency,
      ).successOrNull!;

      final dstAllocation = TransferAllocation.create(
        id: 'ta_settle_dst_${statement.id}',
        transactionId: txId,
        role: AllocationRole.destination,
        endpointType: EndpointType.account,
        accountId: statement.accountId,
        amount: statement.outstandingAmount,
        currency: card.currency,
      ).successOrNull!;

      final settlementTx = Transaction.create(
        id: txId,
        profileId: statement.profileId,
        type: TransactionType.transfer,
        subtype: 'creditCardSettlement',
        date: settlementDate,
        currency: card.currency,
        totalAmount: statement.outstandingAmount,
        paymentModeId: paymentModeId,
        status: TransactionStatus.active,
        createdAt: settlementDate,
        updatedAt: settlementDate,
        note: 'Settled Credit Card Bill',
        categoryAllocations: const [],
        transferAllocations: [srcAllocation, dstAllocation],
      ).successOrNull!;

      // 3. Save the transaction and mark statement settled atomically
      final saveTxResult = await transactionRepository.saveTransaction(
        settlementTx,
      );
      if (saveTxResult.isFailure) {
        return FailureResult(saveTxResult.failureOrNull!);
      }

      final updatedStatement = CreditCardStatement.create(
        id: statement.id,
        profileId: statement.profileId,
        accountId: statement.accountId,
        statementCycle: statement.statementCycle,
        statementPeriodStart: statement.statementPeriodStart,
        statementPeriodEnd: statement.statementPeriodEnd,
        outstandingAmount: statement.outstandingAmount,
        isSettled: true,
        createdAt: statement.createdAt,
        updatedAt: DateTime.now(),
      ).successOrNull!;

      final saveStatementResult = await accountRepository
          .saveCreditCardStatement(updatedStatement);
      if (saveStatementResult.isFailure) {
        // Rollback transaction (we would delete the transaction we just created)
        await transactionRepository.deleteTransaction(
          txId,
          statement.profileId,
        );
        return FailureResult(saveStatementResult.failureOrNull!);
      }

      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Statement settlement failed', e));
    }
  }
}
