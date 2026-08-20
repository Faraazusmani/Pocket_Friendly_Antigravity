import '../../../../core/errors/failures.dart';
import '../../../../core/result/result.dart';
import '../category.dart';
import '../tag.dart';

abstract class CategoryRepository {
  Future<Result<Category, Failure>> getCategory(
    String categoryId,
    String profileId,
  );

  Future<Result<List<Category>, Failure>> getCategories(
    String profileId, {
    bool includeArchived = false,
  });

  Future<Result<void, Failure>> saveCategory(Category category);

  Future<Result<void, Failure>> archiveCategory(
    String categoryId,
    String profileId,
  );

  // Tag operations
  Future<Result<Tag, Failure>> getTag(String tagId, String profileId);

  Future<Result<List<Tag>, Failure>> getTags(
    String profileId, {
    bool includeArchived = false,
  });

  Future<Result<void, Failure>> saveTag(Tag tag);

  Future<Result<void, Failure>> archiveTag(String tagId, String profileId);
}
