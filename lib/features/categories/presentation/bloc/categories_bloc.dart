import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/security/privacy_mode_service.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../domain/category.dart';
import '../../domain/tag.dart';
import '../../domain/repositories/category_repository.dart';
import '../../../transactions/domain/transaction.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import 'categories_event.dart';
import 'categories_state.dart';

class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  final ProfileRepository profileRepository;
  final CategoryRepository categoryRepository;
  final TransactionRepository transactionRepository;

  CategoriesBloc({
    required this.profileRepository,
    required this.categoryRepository,
    required this.transactionRepository,
  }) : super(const CategoriesInitial()) {
    on<LoadCategoriesAndTags>(_onLoadCategoriesAndTags);
    on<CreateCategory>(_onCreateCategory);
    on<UpdateCategory>(_onUpdateCategory);
    on<ArchiveCategory>(_onArchiveCategory);
    on<CreateTag>(_onCreateTag);
    on<UpdateTag>(_onUpdateTag);
    on<ArchiveTag>(_onArchiveTag);
  }

  Future<void> _onLoadCategoriesAndTags(
    LoadCategoriesAndTags event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const CategoriesError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final categoriesRes = await categoryRepository.getCategories(
        profileId,
        includeArchived: false,
      );
      final tagsRes = await categoryRepository.getTags(
        profileId,
        includeArchived: false,
      );
      final transactionsRes = await transactionRepository.getTransactions(
        profileId,
      );

      final categories = categoriesRes.isSuccess
          ? categoriesRes.successOrNull!
          : <Category>[];
      final tags = tagsRes.isSuccess ? tagsRes.successOrNull! : <Tag>[];
      final transactions = transactionsRes.isSuccess
          ? transactionsRes.successOrNull!
          : <Transaction>[];

      // Calculate current month's category spending
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(
        now.year,
        now.month + 1,
        1,
      ).subtract(const Duration(microseconds: 1));

      final currentMonthTransactions = transactions.where(
        (tx) =>
            tx.date.isAfter(
              startOfMonth.subtract(const Duration(microseconds: 1)),
            ) &&
            tx.date.isBefore(endOfMonth.add(const Duration(microseconds: 1))) &&
            tx.status == TransactionStatus.active,
      );

      // 1. Direct spending per category
      final directSpent = <String, int>{};
      for (final tx in currentMonthTransactions) {
        for (final alloc in tx.categoryAllocations) {
          directSpent[alloc.categoryId] =
              (directSpent[alloc.categoryId] ?? 0) + alloc.amount;
        }
      }

      // 2. Rollup child spending to parent categories without double-counting
      final categorySpent = <String, int>{};
      for (final cat in categories) {
        if (cat.parentCategoryId != null) {
          // Subcategory spent is just its direct spent
          categorySpent[cat.id] = directSpent[cat.id] ?? 0;
        } else {
          // Parent category spent is its direct spent + sum of all its children's direct spent
          int total = directSpent[cat.id] ?? 0;
          final children = categories.where(
            (c) => c.parentCategoryId == cat.id,
          );
          for (final child in children) {
            total += directSpent[child.id] ?? 0;
          }
          categorySpent[cat.id] = total;
        }
      }

      final activeProfile = profilesRes.successOrNull!.first;

      emit(
        CategoriesLoaded(
          categories: categories,
          tags: tags,
          transactions: transactions,
          categorySpent: categorySpent,
          defaultCurrency: activeProfile.defaultCurrency,
          privacyModeEnabled: sl.isRegistered<PrivacyModeService>() && sl<PrivacyModeService>().isEnabled,
        ),
      );
    } catch (e) {
      emit(CategoriesError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onCreateCategory(
    CreateCategory event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const CategoriesError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final now = DateTime.now();
      final categoryRes = Category.create(
        id: const Uuid().v4(),
        profileId: profileId,
        parentCategoryId: event.parentCategoryId,
        name: event.name,
        icon: event.icon,
        status: CategoryStatus.active,
        isSystem: false,
        createdAt: now,
        updatedAt: now,
      );

      if (categoryRes.isFailure) {
        emit(
          CategoriesError(
            categoryRes.failureOrNull?.message ?? 'Validation failed',
          ),
        );
        return;
      }
      final category = categoryRes.successOrNull!;

      // Validate Hierarchy maximum 2 levels
      if (event.parentCategoryId != null) {
        final parentRes = await categoryRepository.getCategory(
          event.parentCategoryId!,
          profileId,
        );
        if (parentRes.isFailure) {
          emit(const CategoriesError('Parent category not found'));
          return;
        }
        final validation = category.validateHierarchy(parentRes.successOrNull!);
        if (validation.isFailure) {
          emit(
            CategoriesError(
              validation.failureOrNull?.message ??
                  'Hierarchy validation failed',
            ),
          );
          return;
        }
      }

      final saveRes = await categoryRepository.saveCategory(category);
      if (saveRes.isFailure) {
        emit(
          CategoriesError(
            saveRes.failureOrNull?.message ?? 'Failed to save category',
          ),
        );
        return;
      }

      emit(const CategoryActionSuccess('Category created successfully'));
    } catch (e) {
      emit(CategoriesError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onUpdateCategory(
    UpdateCategory event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const CategoriesError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final existingRes = await categoryRepository.getCategory(
        event.categoryId,
        profileId,
      );
      if (existingRes.isFailure) {
        emit(const CategoriesError('Category not found'));
        return;
      }
      final existing = existingRes.successOrNull!;

      final now = DateTime.now();
      final categoryRes = Category.create(
        id: existing.id,
        profileId: existing.profileId,
        parentCategoryId: event.parentCategoryId,
        name: event.name,
        icon: event.icon,
        status: existing.status,
        isSystem: existing.isSystem,
        createdAt: existing.createdAt,
        updatedAt: now,
      );

      if (categoryRes.isFailure) {
        emit(
          CategoriesError(
            categoryRes.failureOrNull?.message ?? 'Validation failed',
          ),
        );
        return;
      }
      final category = categoryRes.successOrNull!;

      // Validate hierarchy
      if (event.parentCategoryId != null) {
        final parentRes = await categoryRepository.getCategory(
          event.parentCategoryId!,
          profileId,
        );
        if (parentRes.isFailure) {
          emit(const CategoriesError('Parent category not found'));
          return;
        }
        final validation = category.validateHierarchy(parentRes.successOrNull!);
        if (validation.isFailure) {
          emit(
            CategoriesError(
              validation.failureOrNull?.message ??
                  'Hierarchy validation failed',
            ),
          );
          return;
        }
      }

      final saveRes = await categoryRepository.saveCategory(category);
      if (saveRes.isFailure) {
        emit(
          CategoriesError(
            saveRes.failureOrNull?.message ?? 'Failed to update category',
          ),
        );
        return;
      }

      emit(const CategoryActionSuccess('Category updated successfully'));
    } catch (e) {
      emit(CategoriesError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onArchiveCategory(
    ArchiveCategory event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const CategoriesError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final archiveRes = await categoryRepository.archiveCategory(
        event.categoryId,
        profileId,
      );
      if (archiveRes.isFailure) {
        emit(
          CategoriesError(
            archiveRes.failureOrNull?.message ?? 'Failed to archive category',
          ),
        );
        return;
      }

      emit(const CategoryActionSuccess('Category deleted successfully'));
    } catch (e) {
      emit(CategoriesError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onCreateTag(
    CreateTag event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const CategoriesError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final now = DateTime.now();
      final tagRes = Tag.create(
        id: const Uuid().v4(),
        profileId: profileId,
        name: event.name,
        createdAt: now,
        updatedAt: now,
      );

      if (tagRes.isFailure) {
        emit(
          CategoriesError(tagRes.failureOrNull?.message ?? 'Validation failed'),
        );
        return;
      }

      final saveRes = await categoryRepository.saveTag(tagRes.successOrNull!);
      if (saveRes.isFailure) {
        emit(
          CategoriesError(
            saveRes.failureOrNull?.message ?? 'Failed to save tag',
          ),
        );
        return;
      }

      emit(const CategoryActionSuccess('Tag created successfully'));
    } catch (e) {
      emit(CategoriesError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onUpdateTag(
    UpdateTag event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const CategoriesError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final existingRes = await categoryRepository.getTag(
        event.tagId,
        profileId,
      );
      if (existingRes.isFailure) {
        emit(const CategoriesError('Tag not found'));
        return;
      }
      final existing = existingRes.successOrNull!;

      final now = DateTime.now();
      final tagRes = Tag.create(
        id: existing.id,
        profileId: existing.profileId,
        name: event.name,
        createdAt: existing.createdAt,
        updatedAt: now,
        archivedAt: existing.archivedAt,
      );

      if (tagRes.isFailure) {
        emit(
          CategoriesError(tagRes.failureOrNull?.message ?? 'Validation failed'),
        );
        return;
      }

      final saveRes = await categoryRepository.saveTag(tagRes.successOrNull!);
      if (saveRes.isFailure) {
        emit(
          CategoriesError(
            saveRes.failureOrNull?.message ?? 'Failed to update tag',
          ),
        );
        return;
      }

      emit(const CategoryActionSuccess('Tag updated successfully'));
    } catch (e) {
      emit(CategoriesError('An unexpected error occurred: $e'));
    }
  }

  Future<void> _onArchiveTag(
    ArchiveTag event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(const CategoriesLoading());
    try {
      final profilesRes = await profileRepository.getProfiles();
      if (profilesRes.isFailure || profilesRes.successOrNull!.isEmpty) {
        emit(const CategoriesError('No active profile found'));
        return;
      }
      final profileId = profilesRes.successOrNull!.first.id;

      final archiveRes = await categoryRepository.archiveTag(
        event.tagId,
        profileId,
      );
      if (archiveRes.isFailure) {
        emit(
          CategoriesError(
            archiveRes.failureOrNull?.message ?? 'Failed to delete tag',
          ),
        );
        return;
      }

      emit(const CategoryActionSuccess('Tag deleted successfully'));
    } catch (e) {
      emit(CategoriesError('An unexpected error occurred: $e'));
    }
  }
}
