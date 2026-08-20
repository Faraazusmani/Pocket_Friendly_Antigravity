import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Database table for Profiles
@DataClassName('ProfileData')
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get defaultCurrency => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for Accounts
@DataClassName('AccountData')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get type => text()(); // Bank, Cash, Credit Card
  TextColumn get name => text()();
  TextColumn get currency => text()();
  TextColumn get icon => text()();
  IntColumn get openingBalance => integer()(); // minor units
  TextColumn get status => text()(); // active, archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  // Credit card config fields
  IntColumn get creditLimit => integer().nullable()();
  IntColumn get openingOutstanding => integer().nullable()();
  IntColumn get billGenerationDay => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for Categories
@DataClassName('CategoryData')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get parentCategoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get name => text()();
  TextColumn get icon => text()();
  TextColumn get status => text()(); // active, archived
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get linkedGoalId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for Tags
@DataClassName('TagData')
class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text()();
  TextColumn get status => text()(); // active, archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for PaymentModes
@DataClassName('PaymentModeData')
class PaymentModes extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get name => text()();
  TextColumn get applicableAccountTypes =>
      text()(); // comma-separated list of compatible account types
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  TextColumn get status => text()(); // active, archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for Goals
@DataClassName('GoalData')
class Goals extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get goalType => text()(); // standard, EMI, SIP
  TextColumn get name => text()();
  TextColumn get icon => text()();
  IntColumn get targetAmount => integer()(); // minor units
  TextColumn get currency => text()();
  DateTimeColumn get targetDate => dateTime().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get status => text()(); // active, archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for Transactions
@DataClassName('TransactionData')
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get type => text()(); // Expense, Income, Transfer
  TextColumn get subtype =>
      text().nullable()(); // balanceAdjustment, creditCardSettlement
  DateTimeColumn get date => dateTime()();
  TextColumn get currency => text()();
  TextColumn get note => text().nullable()();
  TextColumn get tagId => text().nullable().references(Tags, #id)();
  TextColumn get paymentModeId => text().references(PaymentModes, #id)();
  TextColumn get recurringRuleId => text().nullable()();
  TextColumn get recurringOccurrenceId => text().nullable()();
  TextColumn get status => text()(); // active, archived
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for CategoryAllocations
@DataClassName('CategoryAllocationData')
class CategoryAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amount => integer()(); // positive minor units
  TextColumn get currency => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for TransferAllocations (Endpoint allocations)
@DataClassName('TransferAllocationData')
class TransferAllocations extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(Transactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get role => text()(); // SOURCE, DESTINATION
  TextColumn get endpointType => text()(); // ACCOUNT, GOAL
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get goalId => text().nullable().references(Goals, #id)();
  IntColumn get amount => integer()(); // positive minor units
  TextColumn get currency => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for Budgets
@DataClassName('BudgetData')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get month => integer()(); // 1-12
  IntColumn get year => integer()();
  IntColumn get baseAmount => integer()(); // minor units
  IntColumn get carryForwardAmount => integer()(); // minor units
  TextColumn get currency => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for RecurringTransactionRules
@DataClassName('RecurringTransactionRuleData')
class RecurringTransactionRules extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get transactionTemplate => text()(); // JSON string template
  TextColumn get frequency => text()(); // daily, weekly, monthly, yearly
  IntColumn get dayOfPeriod => integer()();
  TextColumn get mode => text()(); // Reminder, Automatic Recording
  DateTimeColumn get nextOccurrence => dateTime()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  TextColumn get splitFromRuleId => text().nullable()();
  DateTimeColumn get lastExecutedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for RecurringOccurrences
@DataClassName('RecurringOccurrenceData')
class RecurringOccurrences extends Table {
  TextColumn get id => text()();
  TextColumn get recurringRuleId =>
      text().references(RecurringTransactionRules, #id)();
  DateTimeColumn get scheduledOccurrenceDate => dateTime()();
  TextColumn get status => text()(); // PENDING, RECORDED, SKIPPED, FAILED
  TextColumn get createdTransactionId =>
      text().nullable().references(Transactions, #id)();
  DateTimeColumn get executedAt => dateTime().nullable()();
  DateTimeColumn get skippedAt => dateTime().nullable()();
  DateTimeColumn get failedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
    {recurringRuleId, scheduledOccurrenceDate},
  ];
}

/// Database table for Notifications
@DataClassName('NotificationData')
class Notifications extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get type => text()();
  DateTimeColumn get scheduledAt => dateTime()();
  TextColumn get payload => text().nullable()();
  TextColumn get status => text()(); // pending, delivered, clicked
  TextColumn get relatedEntityId => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Database table for MergeConflictAudits
@DataClassName('MergeConflictAuditData')
class MergeConflictAudits extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get localPayload => text()();
  TextColumn get importedPayload => text()();
  TextColumn get userDecision => text()();
  DateTimeColumn get decidedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('UnallocatedBudgetPoolData')
class UnallocatedBudgetPools extends Table {
  TextColumn get id => text()();
  TextColumn get profileId => text().references(Profiles, #id)();
  IntColumn get month => integer()(); // 1-12
  IntColumn get year => integer()();
  IntColumn get amount => integer()(); // minor units
  TextColumn get currency => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Profiles,
    Accounts,
    Categories,
    Tags,
    PaymentModes,
    Goals,
    Transactions,
    CategoryAllocations,
    TransferAllocations,
    Budgets,
    RecurringTransactionRules,
    RecurringOccurrences,
    Notifications,
    MergeConflictAudits,
    UnallocatedBudgetPools,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      // Future migration pathways will go here.
    },
  );
}

/// Helper method to create an encrypted connection using SQLCipher.
QueryExecutor openEncryptedConnection(
  List<int> keyBytes, {
  bool inMemory = false,
}) {
  if (inMemory) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        final keyHex = keyBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        rawDb.execute("PRAGMA key = \"x'$keyHex'\";");
      },
    );
  }

  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pocket_friendly.db'));
    return NativeDatabase(
      file,
      setup: (rawDb) {
        final keyHex = keyBytes
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
        rawDb.execute("PRAGMA key = \"x'$keyHex'\";");
      },
    );
  });
}
