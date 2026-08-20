import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Database table for Profiles, serving as our baseline schema representation.
class Profiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get defaultCurrency => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Profiles])
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
