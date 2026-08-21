import 'package:equatable/equatable.dart';
import '../../domain/category.dart';
import '../../domain/tag.dart';
import '../../../transactions/domain/transaction.dart';

abstract class CategoriesState extends Equatable {
  const CategoriesState();

  @override
  List<Object?> get props => [];
}

class CategoriesInitial extends CategoriesState {
  const CategoriesInitial();
}

class CategoriesLoading extends CategoriesState {
  const CategoriesLoading();
}

class CategoriesLoaded extends CategoriesState {
  final List<Category> categories;
  final List<Tag> tags;
  final List<Transaction> transactions;
  final String defaultCurrency;
  final bool privacyModeEnabled;

  // Pre-calculated spent rollups mapping categoryId -> spent amount in minor units
  final Map<String, int> categorySpent;

  const CategoriesLoaded({
    required this.categories,
    required this.tags,
    required this.transactions,
    required this.categorySpent,
    required this.defaultCurrency,
    this.privacyModeEnabled = false,
  });

  @override
  List<Object?> get props => [
    categories,
    tags,
    transactions,
    categorySpent,
    defaultCurrency,
    privacyModeEnabled,
  ];

  CategoriesLoaded copyWith({
    List<Category>? categories,
    List<Tag>? tags,
    List<Transaction>? transactions,
    Map<String, int>? categorySpent,
    String? defaultCurrency,
    bool? privacyModeEnabled,
  }) {
    return CategoriesLoaded(
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      transactions: transactions ?? this.transactions,
      categorySpent: categorySpent ?? this.categorySpent,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      privacyModeEnabled: privacyModeEnabled ?? this.privacyModeEnabled,
    );
  }
}

class CategoriesError extends CategoriesState {
  final String message;

  const CategoriesError(this.message);

  @override
  List<Object?> get props => [message];
}

class CategoryActionSuccess extends CategoriesState {
  final String message;

  const CategoryActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
