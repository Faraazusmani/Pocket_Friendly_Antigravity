import 'package:drift/drift.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../../../../core/storage/database.dart';
import '../../domain/category.dart';
import '../../domain/tag.dart';
import '../../domain/repositories/category_repository.dart';

class CategoryRepositoryImpl implements CategoryRepository {
  final AppDatabase _database;

  CategoryRepositoryImpl(this._database);

  Category _toDomain(CategoryData data) {
    return Category.create(
      id: data.id,
      profileId: data.profileId,
      parentCategoryId: data.parentCategoryId,
      name: data.name,
      icon: data.icon,
      status: CategoryStatus.values.byName(data.status),
      isSystem: data.isSystem,
      linkedGoalId: data.linkedGoalId,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      archivedAt: data.archivedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database Category to Domain: ${failure.message}',
      ),
    );
  }

  Tag _tagToDomain(TagData data) {
    return Tag.create(
      id: data.id,
      profileId: data.profileId,
      name: data.name,
      createdAt: data.createdAt,
      updatedAt: data.updatedAt,
      archivedAt: data.archivedAt,
    ).fold(
      (success) => success,
      (failure) => throw Exception(
        'Failed to map database Tag to Domain: ${failure.message}',
      ),
    );
  }

  @override
  Future<Result<Category, Failure>> getCategory(
    String categoryId,
    String profileId,
  ) async {
    try {
      final query = _database.select(_database.categories)
        ..where((t) => t.id.equals(categoryId) & t.profileId.equals(profileId));
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(
          DatabaseFailure(
            'Category not found with ID: $categoryId for profile: $profileId',
          ),
        );
      }
      return Success(_toDomain(result));
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch category', e));
    }
  }

  @override
  Future<Result<List<Category>, Failure>> getCategories(
    String profileId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _database.select(_database.categories)
        ..where((t) => t.profileId.equals(profileId));

      if (!includeArchived) {
        query.where((t) => t.status.equals(CategoryStatus.active.name));
      }

      final results = await query.get();
      final categories = results.map(_toDomain).toList();
      return Success(categories);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch categories', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveCategory(Category category) async {
    try {
      final companion = CategoriesCompanion(
        id: Value(category.id),
        profileId: Value(category.profileId),
        parentCategoryId: Value(category.parentCategoryId),
        name: Value(category.name),
        icon: Value(category.icon),
        status: Value(category.status.name),
        isSystem: Value(category.isSystem),
        linkedGoalId: Value(category.linkedGoalId),
        createdAt: Value(category.createdAt),
        updatedAt: Value(category.updatedAt),
        archivedAt: Value(category.archivedAt),
      );
      await _database
          .into(_database.categories)
          .insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save category', e));
    }
  }

  @override
  Future<Result<void, Failure>> archiveCategory(
    String categoryId,
    String profileId,
  ) async {
    try {
      final now = DateTime.now();
      await _database.transaction(() async {
        // 1. Archive the parent category
        final query = _database.update(_database.categories)
          ..where(
            (t) => t.id.equals(categoryId) & t.profileId.equals(profileId),
          );
        await query.write(
          CategoriesCompanion(
            status: Value(CategoryStatus.archived.name),
            archivedAt: Value(now),
            updatedAt: Value(now),
          ),
        );

        // 2. Recursively archive any child subcategories
        final childQuery = _database.update(_database.categories)
          ..where(
            (t) =>
                t.parentCategoryId.equals(categoryId) &
                t.profileId.equals(profileId),
          );
        await childQuery.write(
          CategoriesCompanion(
            status: Value(CategoryStatus.archived.name),
            archivedAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      });
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to archive category', e));
    }
  }

  @override
  Future<Result<Tag, Failure>> getTag(String tagId, String profileId) async {
    try {
      final query = _database.select(_database.tags)
        ..where((t) => t.id.equals(tagId) & t.profileId.equals(profileId));
      final result = await query.getSingleOrNull();
      if (result == null) {
        return FailureResult(
          DatabaseFailure(
            'Tag not found with ID: $tagId for profile: $profileId',
          ),
        );
      }
      return Success(_tagToDomain(result));
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch tag', e));
    }
  }

  @override
  Future<Result<List<Tag>, Failure>> getTags(
    String profileId, {
    bool includeArchived = false,
  }) async {
    try {
      final query = _database.select(_database.tags)
        ..where((t) => t.profileId.equals(profileId));

      if (!includeArchived) {
        query.where((t) => t.status.equals('active'));
      }

      final results = await query.get();
      final tags = results.map(_tagToDomain).toList();
      return Success(tags);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to fetch tags', e));
    }
  }

  @override
  Future<Result<void, Failure>> saveTag(Tag tag) async {
    try {
      final companion = TagsCompanion(
        id: Value(tag.id),
        profileId: Value(tag.profileId),
        name: Value(tag.name),
        status: Value(tag.archivedAt == null ? 'active' : 'archived'),
        createdAt: Value(tag.createdAt),
        updatedAt: Value(tag.updatedAt),
        archivedAt: Value(tag.archivedAt),
      );
      await _database.into(_database.tags).insertOnConflictUpdate(companion);
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to save tag', e));
    }
  }

  @override
  Future<Result<void, Failure>> archiveTag(
    String tagId,
    String profileId,
  ) async {
    try {
      final now = DateTime.now();
      final query = _database.update(_database.tags)
        ..where((t) => t.id.equals(tagId) & t.profileId.equals(profileId));

      await query.write(
        TagsCompanion(
          status: const Value('archived'),
          archivedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      return const Success(null);
    } catch (e) {
      return FailureResult(DatabaseFailure('Failed to archive tag', e));
    }
  }
}
