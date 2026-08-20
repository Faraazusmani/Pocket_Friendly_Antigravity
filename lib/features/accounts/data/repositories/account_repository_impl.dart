import 'package:drift/drift.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/database.dart';
import '../../domain/account.dart';
import '../../domain/payment_mode.dart';
import '../../domain/repositories/account_repository.dart';

class AccountRepositoryImpl implements AccountRepository {
  final AppDatabase _database;

  AccountRepositoryImpl(this._database);

  Account _toDomain(AccountData data) {
    return Account.create(
      id: data.id,
      profileId: data.profileId,
      type: AccountType.values.byName(data.type),
      name: data.name,
      currency: data.currency,
      icon: data.icon,
      openingBalance: data.openingBalance,
      status: AccountStatus.values.byName(data.status),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      archivedAt: data.archivedAt,
      creditLimit: data.creditLimit,
      openingOutstanding: data.openingOutstanding,
      billGenerationDay: data.billGenerationDay,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database Account to Domain: ${failure.message}',
      ),
    );
  }

  PaymentMode _pmToDomain(PaymentModeData data) {
    final typesList = data.applicableAccountTypes
        .split(',')
        .where((s) => s.isNotEmpty)
        .map((s) => AccountType.values.byName(s))
        .toList();

    return PaymentMode.create(
      id: data.id,
      profileId: data.profileId,
      name: data.name,
      applicableAccountTypes: typesList,
      isDefault: data.isDefault,
      isSystem: data.isSystem,
      status: PaymentModeStatus.values.byName(data.status),
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      archivedAt: data.archivedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database PaymentMode to Domain: ${failure.message}',
      ),
    );
  }

  @override
  Future<Result<Account, Failure>> getAccount(
    String accountId,
    String profileId,
  ) async {
    try {
      final query = _database.select(_database.accounts)
        ..where((t) => t.id.equals(accountId) & t.profileId.equals(profileId));
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(
          DatabaseFailure(
            'Account not found with ID: $accountId for profile: $profileId',
          ),
        );
      }
      return Success(_toDomain(result));
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch account', e));
    }
  }

  @override
  Future<Result<List<Account>, Failure>> getAccounts(
    String profileId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _database.select(_database.accounts)
        ..where((t) => t.profileId.equals(profileId));

      if (!includeArchived) {
        query.where((t) => t.status.equals(AccountStatus.active.name));
      }

      final results = await query.get();
      final accounts = results.map(_toDomain).toList();
      return Success(accounts);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch accounts', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveAccount(Account account) async {
    try {
      final companion = AccountsCompanion(
        id: Value(account.id),
        profileId: Value(account.profileId),
        type: Value(account.type.name),
        name: Value(account.name),
        currency: Value(account.currency),
        icon: Value(account.icon),
        openingBalance: Value(account.openingBalance),
        status: Value(account.status.name),
        createdAt: Value(account.createdAt),
        updatedAt: Value(account.updatedAt),
        archivedAt: Value(account.archivedAt),
        creditLimit: Value(account.creditLimit),
        openingOutstanding: Value(account.openingOutstanding),
        billGenerationDay: Value(account.billGenerationDay),
      );
      await _database
          .into(_database.accounts)
          .insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save account', e));
    }
  }

  @override
  Future<Result<void, Failure>> archiveAccount(
    String accountId,
    String profileId,
  ) async {
    try {
      final now = DateTime.now();
      final query = _database.update(_database.accounts)
        ..where((t) => t.id.equals(accountId) & t.profileId.equals(profileId));

      await query.write(
        AccountsCompanion(
          status: Value(AccountStatus.archived.name),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to archive account', e));
    }
  }

  @override
  Future<Result<PaymentMode, Failure>> getPaymentMode(
    String modeId,
    String profileId,
  ) async {
    try {
      final query = _database.select(_database.paymentModes)
        ..where((t) => t.id.equals(modeId) & t.profileId.equals(profileId));
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(
          DatabaseFailure(
            'PaymentMode not found with ID: $modeId for profile: $profileId',
          ),
        );
      }
      return Success(_pmToDomain(result));
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch payment mode', e));
    }
  }

  @override
  Future<Result<List<PaymentMode>, Failure>> getPaymentModes(
    String profileId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _database.select(_database.paymentModes)
        ..where((t) => t.profileId.equals(profileId));

      if (!includeArchived) {
        query.where((t) => t.status.equals(PaymentModeStatus.active.name));
      }

      final results = await query.get();
      final modes = results.map(_pmToDomain).toList();
      return Success(modes);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch payment modes', e));
    }
  }

  @override
  Future<Result<void, Failure>> savePaymentMode(PaymentMode mode) async {
    try {
      final typesString = mode.applicableAccountTypes
          .map((e) => e.name)
          .join(',');
      final companion = PaymentModesCompanion(
        id: Value(mode.id),
        profileId: Value(mode.profileId),
        name: Value(mode.name),
        applicableAccountTypes: Value(typesString),
        isDefault: Value(mode.isDefault),
        isSystem: Value(mode.isSystem),
        status: Value(mode.status.name),
        createdAt: Value(mode.createdAt),
        updatedAt: Value(mode.updatedAt),
        archivedAt: Value(mode.archivedAt),
      );
      await _database
          .into(_database.paymentModes)
          .insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save payment mode', e));
    }
  }

  @override
  Future<Result<void, Failure>> archivePaymentMode(
    String modeId,
    String profileId,
  ) async {
    try {
      final now = DateTime.now();
      final query = _database.update(_database.paymentModes)
        ..where((t) => t.id.equals(modeId) & t.profileId.equals(profileId));

      await query.write(
        PaymentModesCompanion(
          status: Value(PaymentModeStatus.archived.name),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(
        DatabaseFailure('Failed to archive payment mode', e),
      );
    }
  }
}
