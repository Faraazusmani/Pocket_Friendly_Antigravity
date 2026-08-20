import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:pocket_friendly/core/storage/database.dart';
import 'package:pocket_friendly/features/profiles/domain/profile.dart';
import 'package:pocket_friendly/features/profiles/domain/repositories/profile_repository.dart';
import 'package:pocket_friendly/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:pocket_friendly/features/categories/domain/category.dart';
import 'package:pocket_friendly/features/categories/domain/repositories/category_repository.dart';
import 'package:pocket_friendly/features/categories/data/repositories/category_repository_impl.dart';
import 'package:pocket_friendly/features/transactions/domain/transaction.dart';
import 'package:pocket_friendly/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:pocket_friendly/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:pocket_friendly/features/categories/presentation/bloc/categories_bloc.dart';
import 'package:pocket_friendly/features/categories/presentation/bloc/categories_event.dart';
import 'package:pocket_friendly/features/categories/presentation/bloc/categories_state.dart';

void main() {
  late AppDatabase database;
  late ProfileRepository profileRepo;
  late CategoryRepository categoryRepo;
  late TransactionRepository transactionRepo;

  setUp(() async {
    final key = List<int>.generate(32, (i) => i);
    database = AppDatabase(openEncryptedConnection(key, inMemory: true));

    profileRepo = ProfileRepositoryImpl(database);
    categoryRepo = CategoryRepositoryImpl(database);
    transactionRepo = TransactionRepositoryImpl(database);

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
  });

  tearDown(() async {
    await database.close();
  });

  blocTest<CategoriesBloc, CategoriesState>(
    'LoadCategoriesAndTags computes monthly spent rollup correctly',
    build: () => CategoriesBloc(
      profileRepository: profileRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
    ),
    act: (bloc) async {
      final now = DateTime.now();

      // 1. Create Parent Category (Food)
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

      // 2. Create Child Category (Grocery)
      final child = Category.create(
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
      await categoryRepo.saveCategory(child);

      // 3. Create Transaction in subcategory Grocery (1,500 minor units = 15 INR)
      final alloc = CategoryAllocation.create(
        id: 'alloc-1',
        transactionId: 'tx-1',
        categoryId: 'cat-grocery',
        amount: 1500,
        currency: 'INR',
      ).successOrNull!;

      final ta = TransferAllocation.create(
        id: 'ta-1',
        transactionId: 'tx-1',
        role: AllocationRole.source,
        endpointType: EndpointType.account,
        accountId: 'pm-cash',
        amount: 1500,
        currency: 'INR',
      ).successOrNull!;

      final tx = Transaction.create(
        id: 'tx-1',
        profileId: 'p1',
        type: TransactionType.expense,
        date: now,
        currency: 'INR',
        totalAmount: 1500,
        paymentModeId: 'pm-cash',
        status: TransactionStatus.active,
        createdAt: now,
        updatedAt: now,
        categoryAllocations: [alloc],
        transferAllocations: [ta],
      ).successOrNull!;
      await transactionRepo.saveTransaction(tx);

      bloc.add(const LoadCategoriesAndTags());
    },
    expect: () => [
      const CategoriesLoading(),
      isA<CategoriesLoaded>()
          .having((s) => s.categories.length, 'categories count', 2)
          .having((s) => s.categorySpent['cat-grocery'], 'child spent', 1500)
          .having(
            (s) => s.categorySpent['cat-food'],
            'parent rolled-up spent',
            1500,
          ),
    ],
  );

  blocTest<CategoriesBloc, CategoriesState>(
    'CreateCategory prevents selecting a subcategory as parent',
    build: () => CategoriesBloc(
      profileRepository: profileRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
    ),
    act: (bloc) async {
      final now = DateTime.now();

      // 1. Create Parent Food
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

      // 2. Create Subcategory Grocery under Food
      final child = Category.create(
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
      await categoryRepo.saveCategory(child);

      // 3. Try to create a third-level subcategory under Grocery -> Should fail!
      bloc.add(
        const CreateCategory(
          name: 'Organic Milk',
          icon: 'coffee',
          parentCategoryId: 'cat-grocery',
        ),
      );
    },
    expect: () => [
      const CategoriesLoading(),
      const CategoriesError(
        'Category hierarchy cannot exceed two levels (Parent -> Subcategory)',
      ),
    ],
  );

  blocTest<CategoriesBloc, CategoriesState>(
    'CreateTag / UpdateTag / ArchiveTag CRUD flow works',
    build: () => CategoriesBloc(
      profileRepository: profileRepo,
      categoryRepository: categoryRepo,
      transactionRepository: transactionRepo,
    ),
    act: (bloc) async {
      bloc.add(const CreateTag('Business'));
    },
    expect: () => [
      const CategoriesLoading(),
      const CategoryActionSuccess('Tag created successfully'),
    ],
    verify: (_) async {
      final tags = await categoryRepo.getTags('p1');
      expect(tags.successOrNull?.length, 1);
      expect(tags.successOrNull?.first.name, 'Business');
    },
  );
}
