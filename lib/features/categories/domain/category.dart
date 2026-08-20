import '../../../core/errors/failures.dart';
import '../../../core/result/result.dart';

enum CategoryStatus { active, archived }

class Category {
  final String id;
  final String profileId;
  final String? parentCategoryId;
  final String name;
  final String icon;
  final CategoryStatus status;
  final bool isSystem;
  final String? linkedGoalId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;

  const Category({
    required this.id,
    required this.profileId,
    this.parentCategoryId,
    required this.name,
    required this.icon,
    required this.status,
    required this.isSystem,
    this.linkedGoalId,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
  });

  /// Factory method to enforce baseline "Always Valid" Category values.
  static Result<Category, ValidationFailure> create({
    required String id,
    required String profileId,
    String? parentCategoryId,
    required String name,
    required String icon,
    required CategoryStatus status,
    required bool isSystem,
    String? linkedGoalId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? archivedAt,
  }) {
    if (id.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Category ID cannot be empty'),
      );
    }
    if (profileId.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Profile ID cannot be empty'),
      );
    }
    if (name.trim().length < 2) {
      return const FailureResult(
        ValidationFailure('Category name must be at least 2 characters long'),
      );
    }
    if (icon.trim().isEmpty) {
      return const FailureResult(
        ValidationFailure('Category icon cannot be empty'),
      );
    }
    if (id == parentCategoryId) {
      return const FailureResult(
        ValidationFailure('Category cannot be its own parent'),
      );
    }

    return Success(
      Category(
        id: id,
        profileId: profileId,
        parentCategoryId: parentCategoryId,
        name: name.trim(),
        icon: icon.trim(),
        status: status,
        isSystem: isSystem,
        linkedGoalId: linkedGoalId,
        createdAt: createdAt,
        updatedAt: updatedAt,
        archivedAt: archivedAt,
      ),
    );
  }

  /// Checks the hierarchy invariant (maximum 2 levels: Parent -> Subcategory).
  Result<void, ValidationFailure> validateHierarchy(Category? parentCategory) {
    if (parentCategoryId != null) {
      if (parentCategory == null) {
        return FailureResult(
          ValidationFailure('Parent category not found for: $parentCategoryId'),
        );
      }
      if (parentCategory.parentCategoryId != null) {
        return const FailureResult(
          ValidationFailure(
            'Category hierarchy cannot exceed two levels (Parent -> Subcategory)',
          ),
        );
      }
    }
    return const Success(null);
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'profileId': profileId,
    'parentCategoryId': parentCategoryId,
    'name': name,
    'icon': icon,
    'status': status.name,
    'isSystem': isSystem,
    'linkedGoalId': linkedGoalId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'archivedAt': archivedAt?.toIso8601String(),
  };

  factory Category.fromJson(Map<String, dynamic> json) => Category(
    id: json['id'] as String,
    profileId: json['profileId'] as String,
    parentCategoryId: json['parentCategoryId'] as String?,
    name: json['name'] as String,
    icon: json['icon'] as String,
    status: CategoryStatus.values.byName(json['status'] as String),
    isSystem: json['isSystem'] as bool,
    linkedGoalId: json['linkedGoalId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    archivedAt: json['archivedAt'] != null
        ? DateTime.parse(json['archivedAt'] as String)
        : null,
  );
}
