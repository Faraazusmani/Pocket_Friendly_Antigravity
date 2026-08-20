import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/platform/haptic_service.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../domain/category.dart';
import '../../domain/repositories/category_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../bloc/categories_bloc.dart';
import '../bloc/categories_event.dart';
import '../bloc/categories_state.dart';

class CreateEditCategoryScreen extends StatefulWidget {
  final String? categoryId;

  const CreateEditCategoryScreen({Key? key, this.categoryId}) : super(key: key);

  @override
  State<CreateEditCategoryScreen> createState() =>
      _CreateEditCategoryScreenState();
}

class _CreateEditCategoryScreenState extends State<CreateEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _selectedParentId;
  String _selectedIcon = 'folder';

  bool _isEdit = false;
  Category? _existingCategory;
  List<Category> _parentCandidates = [];

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'shopping-cart', 'icon': LucideIcons.shoppingCart},
    {'name': 'home', 'icon': LucideIcons.home},
    {'name': 'car', 'icon': LucideIcons.car},
    {'name': 'film', 'icon': LucideIcons.film},
    {'name': 'heart', 'icon': LucideIcons.heart},
    {'name': 'coffee', 'icon': LucideIcons.coffee},
    {'name': 'trending-up', 'icon': LucideIcons.trendingUp},
    {'name': 'award', 'icon': LucideIcons.award},
    {'name': 'briefcase', 'icon': LucideIcons.briefcase},
    {'name': 'gift', 'icon': LucideIcons.gift},
    {'name': 'alert-circle', 'icon': LucideIcons.alertCircle},
  ];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.categoryId != null;
    _loadData();
  }

  Future<void> _loadData() async {
    final profilesRes = await sl<ProfileRepository>().getProfiles();
    if (profilesRes.isSuccess && profilesRes.successOrNull!.isNotEmpty) {
      final profileId = profilesRes.successOrNull!.first.id;

      // Load all active categories to populate parents dropdown
      final catsRes = await sl<CategoryRepository>().getCategories(
        profileId,
        includeArchived: false,
      );
      if (catsRes.isSuccess) {
        final allCats = catsRes.successOrNull!;
        setState(() {
          // Filter to candidate parents (must not have a parent itself, and cannot be a system category like Goals)
          _parentCandidates = allCats
              .where(
                (c) =>
                    c.parentCategoryId == null &&
                    !c.isSystem &&
                    (!_isEdit || c.id != widget.categoryId),
              )
              .toList();
        });
      }

      if (_isEdit) {
        final catRes = await sl<CategoryRepository>().getCategory(
          widget.categoryId!,
          profileId,
        );
        if (catRes.isSuccess) {
          final cat = catRes.successOrNull!;
          setState(() {
            _existingCategory = cat;
            _nameController.text = cat.name;
            _selectedParentId = cat.parentCategoryId;
            _selectedIcon = cat.icon;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submitForm(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      sl<HapticService>().vibrate();
      return;
    }

    sl<HapticService>().selectionClick();

    if (_isEdit) {
      context.read<CategoriesBloc>().add(
        UpdateCategory(
          categoryId: widget.categoryId!,
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          parentCategoryId: _selectedParentId,
        ),
      );
    } else {
      context.read<CategoriesBloc>().add(
        CreateCategory(
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          parentCategoryId: _selectedParentId,
        ),
      );
    }
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

    return BlocProvider<CategoriesBloc>(
      create: (context) => CategoriesBloc(
        profileRepository: sl<ProfileRepository>(),
        categoryRepository: sl<CategoryRepository>(),
        transactionRepository: sl<TransactionRepository>(),
      ),
      child: BlocConsumer<CategoriesBloc, CategoriesState>(
        listener: (context, state) {
          if (state is CategoryActionSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
            context.pop(true); // Return true to refresh parent screen
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
          final isLoading = state is CategoriesLoading;

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
                _isEdit ? 'EDIT CATEGORY' : 'NEW CATEGORY',
                style: AppTypography.sectionHeading.copyWith(
                  color: textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              actions: [
                if (_isEdit && _existingCategory?.isSystem == false)
                  IconButton(
                    icon: const Icon(
                      LucideIcons.trash2,
                      color: AppColors.statusError,
                    ),
                    onPressed: () {
                      sl<HapticService>().vibrate();
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          backgroundColor: cardBg,
                          title: Text(
                            'Delete Category',
                            style: TextStyle(color: textPrimary),
                          ),
                          content: Text(
                            'Are you sure you want to delete this category? Historical transactions will preserve their category allocations, but this category will be archived and hidden.',
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
                                  ArchiveCategory(widget.categoryId!),
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
            body: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Form Card Container
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(
                                AppRadius.medium,
                              ),
                              border: Border.all(color: borderCol),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category Name
                                TextFormField(
                                  controller: _nameController,
                                  style: TextStyle(color: textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Category Name',
                                    labelStyle: TextStyle(color: textSecondary),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: borderCol),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: AppColors.darkAccentPrimary,
                                      ),
                                    ),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter category name';
                                    }
                                    if (val.trim().length < 2) {
                                      return 'Name must be at least 2 characters long';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Parent Category Dropdown
                                DropdownButtonFormField<String>(
                                  value: _selectedParentId,
                                  dropdownColor: cardBg,
                                  style: TextStyle(color: textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Parent Category (Optional)',
                                    labelStyle: TextStyle(color: textSecondary),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: borderCol),
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<String>(
                                      value: null,
                                      child: Text('None (Is Parent Category)'),
                                    ),
                                    ..._parentCandidates.map(
                                      (parent) => DropdownMenuItem(
                                        value: parent.id,
                                        child: Text(parent.name),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    setState(() {
                                      _selectedParentId = val;
                                    });
                                  },
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Icon Selector
                                Text(
                                  'Select Icon',
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Wrap(
                                  spacing: AppSpacing.sm,
                                  runSpacing: AppSpacing.sm,
                                  children: _availableIcons.map((i) {
                                    final isSelected =
                                        _selectedIcon == i['name'];
                                    return GestureDetector(
                                      onTap: () {
                                        sl<HapticService>().selectionClick();
                                        setState(() {
                                          _selectedIcon = i['name'];
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(
                                          AppSpacing.md,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isDark
                                                    ? AppColors
                                                          .darkAccentPrimary
                                                          .withOpacity(0.2)
                                                    : AppColors
                                                          .lightAccentPrimary
                                                          .withOpacity(0.2))
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            AppRadius.small,
                                          ),
                                          border: Border.all(
                                            color: isSelected
                                                ? (isDark
                                                      ? AppColors
                                                            .darkAccentPrimary
                                                      : AppColors
                                                            .lightAccentPrimary)
                                                : borderCol,
                                          ),
                                        ),
                                        child: Icon(
                                          i['icon'],
                                          color: isSelected
                                              ? (isDark
                                                    ? AppColors
                                                          .darkAccentPrimary
                                                    : AppColors
                                                          .lightAccentPrimary)
                                              : textSecondary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xl),

                          // Save Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? AppColors.darkAccentPrimary
                                    : AppColors.lightAccentPrimary,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppRadius.medium,
                                  ),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isEdit ? 'SAVE CHANGES' : 'CREATE CATEGORY',
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              onPressed: () => _submitForm(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
