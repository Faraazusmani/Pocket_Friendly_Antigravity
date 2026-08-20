import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/platform/haptic_service.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../domain/repositories/category_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../bloc/categories_bloc.dart';
import '../bloc/categories_event.dart';
import '../bloc/categories_state.dart';
import '../widgets/tag_dialogs.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CategoriesBloc>(
      create: (context) => CategoriesBloc(
        profileRepository: sl<ProfileRepository>(),
        categoryRepository: sl<CategoryRepository>(),
        transactionRepository: sl<TransactionRepository>(),
      )..add(const LoadCategoriesAndTags()),
      child: const CategoriesView(),
    );
  }
}

class CategoriesView extends StatefulWidget {
  const CategoriesView({Key? key}) : super(key: key);

  @override
  State<CategoriesView> createState() => _CategoriesViewState();
}

class _CategoriesViewState extends State<CategoriesView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB actions
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'shopping-cart':
        return LucideIcons.shoppingCart;
      case 'home':
        return LucideIcons.home;
      case 'car':
        return LucideIcons.car;
      case 'film':
        return LucideIcons.film;
      case 'heart':
        return LucideIcons.heart;
      case 'coffee':
        return LucideIcons.coffee;
      case 'trending-up':
        return LucideIcons.trendingUp;
      case 'award':
        return LucideIcons.award;
      case 'briefcase':
        return LucideIcons.briefcase;
      case 'gift':
        return LucideIcons.gift;
      case 'alert-circle':
        return LucideIcons.alertCircle;
      default:
        return LucideIcons.folder;
    }
  }

  String _formatAmount(int amountMinorUnits) {
    final double major = amountMinorUnits / 100.0;
    return '₹${major.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBg = isDark
        ? AppColors.darkBackgroundPrimary
        : AppColors.lightBackgroundPrimary;
    final cardBg = isDark
        ? AppColors.darkSurfacePrimary
        : AppColors.lightSurfacePrimary;
    final borderCol = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return BlocConsumer<CategoriesBloc, CategoriesState>(
      listener: (context, state) {
        if (state is CategoryActionSuccess) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
          context.read<CategoriesBloc>().add(const LoadCategoriesAndTags());
        } else if (state is CategoriesError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppColors.statusError,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading =
            state is CategoriesLoading || state is CategoriesInitial;

        return Scaffold(
          backgroundColor: scaffoldBg,
          appBar: AppBar(
            backgroundColor: scaffoldBg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(LucideIcons.arrowLeft, color: textPrimary),
              onPressed: () {
                sl<HapticService>().selectionClick();
                context.pop();
              },
            ),
            title: Text(
              'CATEGORIES & TAGS',
              style: AppTypography.sectionHeading.copyWith(
                color: textPrimary,
                letterSpacing: 1.5,
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              labelColor: textPrimary,
              unselectedLabelColor: textSecondary,
              indicatorColor: isDark
                  ? AppColors.darkAccentPrimary
                  : AppColors.lightAccentPrimary,
              indicatorWeight: 3.0,
              tabs: const [
                Tab(text: 'CATEGORIES'),
                Tab(text: 'TAGS'),
              ],
            ),
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : BlocBuilder<CategoriesBloc, CategoriesState>(
                  builder: (context, state) {
                    if (state is CategoriesLoaded) {
                      return TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCategoriesTab(
                            context,
                            state,
                            cardBg,
                            borderCol,
                            textPrimary,
                            textSecondary,
                          ),
                          _buildTagsTab(
                            context,
                            state,
                            cardBg,
                            borderCol,
                            textPrimary,
                            textSecondary,
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: isDark
                ? AppColors.darkAccentPrimary
                : AppColors.lightAccentPrimary,
            foregroundColor: Colors.black,
            shape: const CircleBorder(),
            child: const Icon(LucideIcons.plus),
            onPressed: () async {
              sl<HapticService>().mediumImpact();
              if (_tabController.index == 0) {
                // Add Category
                final refresh = await context.push<bool>('/categories/create');
                if (refresh == true) {
                  context.read<CategoriesBloc>().add(
                    const LoadCategoriesAndTags(),
                  );
                }
              } else {
                // Add Tag Dialog
                showDialog(
                  context: context,
                  builder: (dialogCtx) => CreateTagDialog(
                    onSave: (tagName) {
                      context.read<CategoriesBloc>().add(CreateTag(tagName));
                    },
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab(
    BuildContext context,
    CategoriesLoaded state,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    // Parent categories (no parentCategoryId)
    final parentCategories = state.categories
        .where((c) => c.parentCategoryId == null)
        .toList();

    if (parentCategories.isEmpty) {
      return Center(
        child: Text(
          'No categories found.',
          style: AppTypography.body.copyWith(color: textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CategoriesBloc>().add(const LoadCategoriesAndTags());
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: parentCategories.length,
        itemBuilder: (context, index) {
          final parent = parentCategories[index];
          final children = state.categories
              .where((c) => c.parentCategoryId == parent.id)
              .toList();
          final spent = state.categorySpent[parent.id] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: borderCol),
            ),
            child: ExpansionTile(
              leading: Icon(_getIconData(parent.icon), color: textSecondary),
              title: Text(
                parent.name,
                style: AppTypography.body.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'Spent this month: ${_formatAmount(spent)}',
                style: AppTypography.caption.copyWith(color: textSecondary),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!parent.isSystem)
                    IconButton(
                      icon: Icon(
                        LucideIcons.edit2,
                        size: 16,
                        color: textSecondary,
                      ),
                      onPressed: () async {
                        sl<HapticService>().selectionClick();
                        final refresh = await context.push<bool>(
                          '/categories/edit/${parent.id}',
                        );
                        if (refresh == true) {
                          context.read<CategoriesBloc>().add(
                            const LoadCategoriesAndTags(),
                          );
                        }
                      },
                    ),
                  const Icon(LucideIcons.chevronDown, size: 16),
                ],
              ),
              children: [
                if (children.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'No subcategories.',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  )
                else
                  ...children.map((child) {
                    final childSpent = state.categorySpent[child.id] ?? 0;
                    return Container(
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: borderCol)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                        ),
                        leading: Icon(
                          _getIconData(child.icon),
                          size: 18,
                          color: textSecondary,
                        ),
                        title: Text(
                          child.name,
                          style: AppTypography.body.copyWith(
                            color: textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          'Spent: ${_formatAmount(childSpent)}',
                          style: AppTypography.caption.copyWith(
                            color: textSecondary,
                          ),
                        ),
                        trailing: parent.isSystem
                            ? null // System linked categories (like specific goals) are read-only here
                            : IconButton(
                                icon: Icon(
                                  LucideIcons.edit2,
                                  size: 14,
                                  color: textSecondary,
                                ),
                                onPressed: () async {
                                  sl<HapticService>().selectionClick();
                                  final refresh = await context.push<bool>(
                                    '/categories/edit/${child.id}',
                                  );
                                  if (refresh == true) {
                                    context.read<CategoriesBloc>().add(
                                      const LoadCategoriesAndTags(),
                                    );
                                  }
                                },
                              ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTagsTab(
    BuildContext context,
    CategoriesLoaded state,
    Color cardBg,
    Color borderCol,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (state.tags.isEmpty) {
      return Center(
        child: Text(
          'No tags created yet.',
          style: AppTypography.body.copyWith(color: textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<CategoriesBloc>().add(const LoadCategoriesAndTags());
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: state.tags.length,
        itemBuilder: (context, index) {
          final tag = state.tags[index];

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: borderCol),
            ),
            child: ListTile(
              leading: Icon(LucideIcons.tag, color: textSecondary),
              title: Text(
                tag.name,
                style: AppTypography.body.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      LucideIcons.edit2,
                      size: 16,
                      color: textSecondary,
                    ),
                    onPressed: () {
                      sl<HapticService>().selectionClick();
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => RenameTagDialog(
                          tag: tag,
                          onSave: (newName) {
                            context.read<CategoriesBloc>().add(
                              UpdateTag(tagId: tag.id, name: newName),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      LucideIcons.trash2,
                      size: 16,
                      color: AppColors.statusError,
                    ),
                    onPressed: () {
                      sl<HapticService>().vibrate();
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          backgroundColor: cardBg,
                          title: Text(
                            'Delete Tag',
                            style: TextStyle(color: textPrimary),
                          ),
                          content: Text(
                            'Are you sure you want to delete this tag? Historical transactions will preserve their links, but the tag will be archived and hidden.',
                            style: TextStyle(color: textSecondary),
                          ),
                          actions: [
                            TextButton(
                              child: Text(
                                'Cancel',
                                style: TextStyle(color: textSecondary),
                              ),
                              onPressed: () => Navigator.pop(dialogCtx),
                            ),
                            TextButton(
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: AppColors.statusError),
                              ),
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                context.read<CategoriesBloc>().add(
                                  ArchiveTag(tag.id),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
