import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/errors/failures.dart';
import 'package:pocket_friendly/core/result/result.dart';
import 'package:pocket_friendly/core/di/service_locator.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/core/platform/haptic_service.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/domain/repositories/profile_repository.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/domain/repositories/category_repository.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/categories/presentation/screens/categories_screen.dart';
import 'package:pocket_friendly/features/categories/presentation/screens/create_edit_category_screen.dart';

class MockHapticService implements HapticService {
  @override
  Future<Result<void, PlatformFailure>> lightImpact() async =>
      const Success(null);
  @override
  Future<Result<void, PlatformFailure>> mediumImpact() async =>
      const Success(null);
  @override
  Future<Result<void, PlatformFailure>> heavyImpact() async =>
      const Success(null);
  @override
  Future<Result<void, PlatformFailure>> selectionClick() async =>
      const Success(null);
  @override
  Future<Result<void, PlatformFailure>> vibrate() async => const Success(null);
}

void main() {
  late AppDatabase database;
  late ProfileRepository profileRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;

  setUp(() async {
    final key = List<int>.generate(32, (i) => i);
    database = AppDatabase(openEncryptedConnection(key, inMemory: true));

    await sl.reset();
    sl.registerSingleton<AppDatabase>(database);
    sl.registerLazySingleton<HapticService>(() => MockHapticService());

    profileRepo = ProfileRepositoryImpl(database);
    categoryRepo = CategoryRepositoryImpl(database);
    transactionRepo = TransactionRepositoryImpl(database);

    sl.registerLazySingleton<ProfileRepository>(() => profileRepo);
    sl.registerLazySingleton<CategoryRepository>(() => categoryRepo);
    sl.registerLazySingleton<TransactionRepository>(() => transactionRepo);

    // Insert active mock profile
    final now = DateTime.now();
    final profile = Profile.create(
      id: 'p1',
      name: 'John Doe',
      defaultCurrency: 'INR',
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await profileRepo.saveProfile(profile);

    // Insert Parent Category
    final parent = Category.create(
      id: 'cat-food',
      profileId: 'p1',
      name: 'Food',
      icon: 'coffee',
      status: CategoryStatus.active,
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await categoryRepo.saveCategory(parent);

    // Insert Subcategory
    final sub = Category.create(
      id: 'cat-grocery',
      profileId: 'p1',
      parentCategoryId: 'cat-food',
      name: 'Grocery',
      icon: 'shopping-cart',
      status: CategoryStatus.active,
      isSystem: false,
      createdAt: now,
      updatedAt: now,
    ).successOrNull!;
    await categoryRepo.saveCategory(sub);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('CategoriesScreen renders listing and expandable categories list', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CategoriesScreen()));
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('CATEGORIES & TAGS'), findsOneWidget);
    expect(find.text('CATEGORIES'), findsWidgets);
    expect(find.text('TAGS'), findsWidgets);

    // Food category is visible
    expect(find.text('Food'), findsOneWidget);

    // Subcategory Grocery is initially collapsed (not in normal tree or hidden inside expansion tile)
    // Click on Food tile to expand
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();

    // Verify subcategory is now visible
    expect(find.text('Grocery'), findsOneWidget);
  });

  testWidgets('CreateEditCategoryScreen validates category form fields', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: CreateEditCategoryScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('NEW CATEGORY'), findsOneWidget);

    // Tap Create button without inputting name -> validation failure
    await tester.ensureVisible(find.text('CREATE CATEGORY'));
    await tester.tap(find.text('CREATE CATEGORY'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter category name'), findsOneWidget);

    // Enter short name -> validation fails
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Category Name'),
      'A',
    );
    await tester.tap(find.text('CREATE CATEGORY'));
    await tester.pumpAndSettle();

    expect(
      find.text('Name must be at least 2 characters long'),
      findsOneWidget,
    );
  });
}
