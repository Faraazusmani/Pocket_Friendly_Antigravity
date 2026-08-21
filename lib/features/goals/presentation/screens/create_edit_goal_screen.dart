import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/platform/haptic_service.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../domain/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../bloc/goals_bloc.dart';
import '../bloc/goals_event.dart';
import '../bloc/goals_state.dart';

class CreateEditGoalScreen extends StatefulWidget {
  final String? goalId;

  const CreateEditGoalScreen({Key? key, this.goalId}) : super(key: key);

  @override
  State<CreateEditGoalScreen> createState() => _CreateEditGoalScreenState();
}

class _CreateEditGoalScreenState extends State<CreateEditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetAmountController = TextEditingController();
  final _descriptionController = TextEditingController();

  GoalType _selectedType = GoalType.standard;
  DateTime? _selectedTargetDate;
  String _selectedIcon = 'piggy';
  bool _isEdit = false;

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'piggy', 'icon': LucideIcons.piggyBank},
    {'name': 'car', 'icon': LucideIcons.car},
    {'name': 'home', 'icon': LucideIcons.home},
    {'name': 'plane', 'icon': LucideIcons.plane},
    {'name': 'heart', 'icon': LucideIcons.heart},
    {'name': 'graduation', 'icon': LucideIcons.graduationCap},
    {'name': 'laptop', 'icon': LucideIcons.laptop},
    {'name': 'gift', 'icon': LucideIcons.gift},
  ];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.goalId != null;
    if (_isEdit) {
      _loadGoalDetails();
    }
  }

  Future<void> _loadGoalDetails() async {
    final profilesRes = await sl<ProfileRepository>().getProfiles();
    if (profilesRes.isSuccess && profilesRes.successOrNull!.isNotEmpty) {
      final profileId = profilesRes.successOrNull!.first.id;
      final goalRes = await sl<GoalRepository>().getGoal(
        widget.goalId!,
        profileId,
      );
      if (goalRes.isSuccess) {
        final goal = goalRes.successOrNull!;
        setState(() {
          _nameController.text = goal.name;
          _targetAmountController.text = (goal.targetAmount / 100)
              .toStringAsFixed(0);
          _descriptionController.text = goal.description ?? '';
          _selectedType = goal.goalType;
          _selectedTargetDate = goal.targetDate;
          _selectedIcon = goal.icon;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetAmountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isTargetDateExpired {
    if (_selectedTargetDate == null) return false;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final targetMidnight = DateTime(
      _selectedTargetDate!.year,
      _selectedTargetDate!.month,
      _selectedTargetDate!.day,
    );
    return todayMidnight.isAfter(targetMidnight);
  }

  void _submitForm(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      sl<HapticService>().vibrate();
      return;
    }

    sl<HapticService>().selectionClick();

    final double majorVal =
        double.tryParse(_targetAmountController.text) ?? 0.0;
    final int targetAmount = (majorVal * 100).round();

    if (_isEdit) {
      context.read<GoalsBloc>().add(
        UpdateGoal(
          goalId: widget.goalId!,
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          goalType: _selectedType,
          targetAmount: targetAmount,
          targetDate: _selectedTargetDate,
          description: _descriptionController.text.trim(),
        ),
      );
    } else {
      context.read<GoalsBloc>().add(
        CreateGoal(
          name: _nameController.text.trim(),
          icon: _selectedIcon,
          goalType: _selectedType,
          targetAmount: targetAmount,
          targetDate: _selectedTargetDate,
          description: _descriptionController.text.trim(),
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

    return BlocProvider<GoalsBloc>(
      create: (context) => GoalsBloc(
        profileRepository: sl<ProfileRepository>(),
        goalRepository: sl<GoalRepository>(),
        accountRepository: sl<AccountRepository>(),
        categoryRepository: sl<CategoryRepository>(),
        transactionRepository: sl<TransactionRepository>(),
      ),
      child: BlocConsumer<GoalsBloc, GoalsState>(
        listener: (context, state) {
          if (state is GoalActionSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
            context.pop(true); // Pop with true to notify parent refresh
          } else if (state is GoalsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.statusError,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is GoalsLoading;

          return Scaffold(
            backgroundColor: scaffoldBg,
            appBar: AppBar(
              backgroundColor: scaffoldBg,
              elevation: 0,
              leading: IconButton(
                tooltip: 'Back',
                icon: Icon(LucideIcons.arrowLeft, color: textPrimary),
                onPressed: () {
                  sl<HapticService>().selectionClick();
                  context.pop();
                },
              ),
              title: Text(
                _isEdit ? 'EDIT GOAL' : 'NEW GOAL',
                style: AppTypography.sectionHeading.copyWith(
                  color: textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              actions: [
                if (_isEdit)
                  IconButton(
                    tooltip: 'Delete Goal',
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
                            'Delete Goal',
                            style: TextStyle(color: textPrimary),
                          ),
                          content: Text(
                            'Are you sure you want to delete this goal? This will archive it and its linked category. Reconstructed progress balance details will be hidden but transfers remain in log history.',
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
                                context.read<GoalsBloc>().add(
                                  ArchiveGoal(widget.goalId!),
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
                                // Goal Name
                                TextFormField(
                                  controller: _nameController,
                                  style: TextStyle(color: textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Goal Name',
                                    labelStyle: TextStyle(color: textSecondary),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: borderCol),
                                    ),
                                    focusedBorder: AppBorders.focusedUnderline(context),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Please enter goal name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Goal Type & Target Amount
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<GoalType>(
                                        value: _selectedType,
                                        dropdownColor: cardBg,
                                        style: TextStyle(color: textPrimary),
                                        decoration: InputDecoration(
                                          labelText: 'Goal Type',
                                          labelStyle: TextStyle(
                                            color: textSecondary,
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: borderCol,
                                            ),
                                          ),
                                        ),
                                        items: GoalType.values
                                            .map(
                                              (type) => DropdownMenuItem(
                                                value: type,
                                                child: Text(
                                                  type.name.toUpperCase(),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedType = val;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _targetAmountController,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(color: textPrimary),
                                        decoration: InputDecoration(
                                          labelText: 'Target Amount',
                                          labelStyle: TextStyle(
                                            color: textSecondary,
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: borderCol,
                                            ),
                                          ),
                                          focusedBorder: AppBorders.focusedUnderline(context),
                                        ),
                                        validator: (val) {
                                          if (val == null ||
                                              val.trim().isEmpty) {
                                            return 'Please enter target';
                                          }
                                          if (double.tryParse(val) == null ||
                                              double.parse(val) <= 0) {
                                            return 'Must be positive';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Target Date Picker
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    _selectedTargetDate == null
                                        ? 'Target Date: 1-Year Projection (Default)'
                                        : 'Target Date: ${_selectedTargetDate!.day}/${_selectedTargetDate!.month}/${_selectedTargetDate!.year}',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Tap to configure custom target date limit',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                  trailing: Icon(
                                    LucideIcons.calendar,
                                    color: textSecondary,
                                  ),
                                  onTap: () async {
                                    sl<HapticService>().selectionClick();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _selectedTargetDate ??
                                          DateTime.now().add(
                                            const Duration(days: 365),
                                          ),
                                      firstDate: DateTime.now().subtract(
                                        const Duration(days: 365),
                                      ),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 3650),
                                      ),
                                      builder: (context, child) {
                                        return Theme(
                                          data: isDark
                                              ? ThemeData.dark()
                                              : ThemeData.light(),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _selectedTargetDate = picked;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: AppSpacing.xs),

                                // Dynamic Expired Target Date Warning
                                if (_isTargetDateExpired) ...[
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.statusError.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.small,
                                      ),
                                      border: Border.all(
                                        color: AppColors.statusError,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          LucideIcons.alertTriangle,
                                          color: AppColors.statusError,
                                          size: 18,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(
                                            'Selected target date has already expired! Please choose a future target date.',
                                            style: AppTypography.caption
                                                .copyWith(
                                                  color: AppColors.statusError,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],

                                // Description field
                                TextFormField(
                                  controller: _descriptionController,
                                  maxLines: 2,
                                  style: TextStyle(color: textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Description (Optional)',
                                    labelStyle: TextStyle(color: textSecondary),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(color: borderCol),
                                    ),
                                    focusedBorder: AppBorders.focusedUnderline(context),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Icon picker
                                Text(
                                  'Select Goal Icon',
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

                          // Submit Button
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
                                _isEdit ? 'SAVE CHANGES' : 'CREATE GOAL',
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
