import 'package:equatable/equatable.dart';

abstract class CategoriesEvent extends Equatable {
  const CategoriesEvent();

  @override
  List<Object?> get props => [];
}

class LoadCategoriesAndTags extends CategoriesEvent {
  const LoadCategoriesAndTags();
}

class CreateCategory extends CategoriesEvent {
  final String name;
  final String icon;
  final String? parentCategoryId;

  const CreateCategory({
    required this.name,
    required this.icon,
    this.parentCategoryId,
  });

  @override
  List<Object?> get props => [name, icon, parentCategoryId];
}

class UpdateCategory extends CategoriesEvent {
  final String categoryId;
  final String name;
  final String icon;
  final String? parentCategoryId;

  const UpdateCategory({
    required this.categoryId,
    required this.name,
    required this.icon,
    this.parentCategoryId,
  });

  @override
  List<Object?> get props => [categoryId, name, icon, parentCategoryId];
}

class ArchiveCategory extends CategoriesEvent {
  final String categoryId;

  const ArchiveCategory(this.categoryId);

  @override
  List<Object?> get props => [categoryId];
}

class CreateTag extends CategoriesEvent {
  final String name;

  const CreateTag(this.name);

  @override
  List<Object?> get props => [name];
}

class UpdateTag extends CategoriesEvent {
  final String tagId;
  final String name;

  const UpdateTag({required this.tagId, required this.name});

  @override
  List<Object?> get props => [tagId, name];
}

class ArchiveTag extends CategoriesEvent {
  final String tagId;

  const ArchiveTag(this.tagId);

  @override
  List<Object?> get props => [tagId];
}
