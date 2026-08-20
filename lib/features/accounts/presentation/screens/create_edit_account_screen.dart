import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/platform/haptic_service.dart';
import '../../domain/account.dart';
import '../../domain/repositories/account_repository.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../../transactions/domain/repositories/transaction_repository.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../bloc/accounts_bloc.dart';
import '../bloc/accounts_event.dart';
import '../bloc/accounts_state.dart';

class CreateEditAccountScreen extends StatefulWidget {
  final String? accountId;

  const CreateEditAccountScreen({Key? key, this.accountId}) : super(key: key);

  @override
  State<CreateEditAccountScreen> createState() =>
      _CreateEditAccountScreenState();
}

class _CreateEditAccountScreenState extends State<CreateEditAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  final _creditLimitController = TextEditingController();
  final _openingOutstandingController = TextEditingController();

  AccountType _selectedType = AccountType.bank;
  String _selectedCurrency = 'INR';
  String _selectedIcon = 'bank';
  int _selectedBillDay = 15;

  bool _isEdit = false;
  Account? _existingAccount;

  final List<String> _currencies = [
    'INR',
    'USD',
    'EUR',
    'GBP',
    'AUD',
    'CAD',
    'JPY',
  ];
  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'bank', 'icon': LucideIcons.landmark},
    {'name': 'wallet', 'icon': LucideIcons.wallet},
    {'name': 'card', 'icon': LucideIcons.creditCard},
    {'name': 'piggy', 'icon': LucideIcons.piggyBank},
    {'name': 'cash', 'icon': LucideIcons.banknote},
    {'name': 'coins', 'icon': LucideIcons.coins},
  ];

  @override
  void initState() {
    super.initState();
    _isEdit = widget.accountId != null;
    if (_isEdit) {
      _loadAccountDetails();
    }
  }

  Future<void> _loadAccountDetails() async {
    final profilesRes = await sl<ProfileRepository>().getProfiles();
    if (profilesRes.isSuccess && profilesRes.successOrNull!.isNotEmpty) {
      final profileId = profilesRes.successOrNull!.first.id;
      final accRes = await sl<AccountRepository>().getAccount(
        widget.accountId!,
        profileId,
      );
      if (accRes.isSuccess) {
        final acc = accRes.successOrNull!;
        setState(() {
          _existingAccount = acc;
          _nameController.text = acc.name;
          _selectedType = acc.type;
          _selectedCurrency = acc.currency;
          _selectedIcon = acc.icon;
          _openingBalanceController.text = (acc.openingBalance / 100)
              .toStringAsFixed(0);
          if (acc.type == AccountType.creditCard) {
            _creditLimitController.text = ((acc.creditLimit ?? 0) / 100)
                .toStringAsFixed(0);
            _openingOutstandingController.text =
                ((acc.openingOutstanding ?? 0) / 100).toStringAsFixed(0);
            _selectedBillDay = acc.billGenerationDay ?? 15;
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingBalanceController.dispose();
    _creditLimitController.dispose();
    _openingOutstandingController.dispose();
    super.dispose();
  }

  void _submitForm(BuildContext context) {
    if (!_formKey.currentState!.validate()) {
      sl<HapticService>().vibrate();
      return;
    }

    sl<HapticService>().selectionClick();

    // Parse values from major unit to minor units (multiplied by 100)
    final double opBalDouble =
        double.tryParse(_openingBalanceController.text) ?? 0.0;
    final int openingBalance = (opBalDouble * 100).round();

    int? creditLimit;
    int? openingOutstanding;
    int? billGenerationDay;

    if (_selectedType == AccountType.creditCard) {
      final double limitDouble =
          double.tryParse(_creditLimitController.text) ?? 0.0;
      creditLimit = (limitDouble * 100).round();

      final double outDouble =
          double.tryParse(_openingOutstandingController.text) ?? 0.0;
      openingOutstanding = (outDouble * 100).round();

      billGenerationDay = _selectedBillDay;
    }

    if (_isEdit) {
      context.read<AccountsBloc>().add(
        UpdateAccount(
          accountId: widget.accountId!,
          name: _nameController.text.trim(),
          type: _selectedType,
          currency: _selectedCurrency,
          icon: _selectedIcon,
          creditLimit: creditLimit,
          openingOutstanding: openingOutstanding,
          billGenerationDay: billGenerationDay,
        ),
      );
    } else {
      context.read<AccountsBloc>().add(
        CreateAccount(
          name: _nameController.text.trim(),
          type: _selectedType,
          openingBalance: openingBalance,
          currency: _selectedCurrency,
          icon: _selectedIcon,
          creditLimit: creditLimit,
          openingOutstanding: openingOutstanding,
          billGenerationDay: billGenerationDay,
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

    return BlocProvider<AccountsBloc>(
      create: (context) => AccountsBloc(
        profileRepository: sl<ProfileRepository>(),
        accountRepository: sl<AccountRepository>(),
        transactionRepository: sl<TransactionRepository>(),
        goalRepository: sl<GoalRepository>(),
      ),
      child: BlocConsumer<AccountsBloc, AccountsState>(
        listener: (context, state) {
          if (state is AccountActionSuccess) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
            context.pop(
              true,
            ); // Return true to trigger data refresh on previous screen
          } else if (state is AccountsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.statusError,
              ),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AccountsLoading;

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
                _isEdit ? 'EDIT ACCOUNT' : 'NEW ACCOUNT',
                style: AppTypography.sectionHeading.copyWith(
                  color: textPrimary,
                  letterSpacing: 1.5,
                ),
              ),
              actions: [
                if (_isEdit &&
                    _existingAccount?.status != AccountStatus.archived)
                  IconButton(
                    icon: const Icon(
                      LucideIcons.archive,
                      color: AppColors.statusError,
                    ),
                    onPressed: () {
                      sl<HapticService>().vibrate();
                      showDialog(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          backgroundColor: cardBg,
                          title: Text(
                            'Archive Account',
                            style: TextStyle(color: textPrimary),
                          ),
                          content: Text(
                            'Are you sure you want to archive this account? This will hide it from listings but preserve all transaction history. Archived accounts cannot receive new transactions.',
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
                                'Archive',
                                style: TextStyle(color: AppColors.statusError),
                              ),
                              onPressed: () {
                                Navigator.pop(dialogCtx);
                                context.read<AccountsBloc>().add(
                                  ArchiveAccount(widget.accountId!),
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
                                // Account Name field
                                TextFormField(
                                  controller: _nameController,
                                  style: TextStyle(color: textPrimary),
                                  decoration: InputDecoration(
                                    labelText: 'Account Name',
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
                                      return 'Please enter account name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: AppSpacing.md),

                                // Account Type Dropdown
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<AccountType>(
                                        value: _selectedType,
                                        dropdownColor: cardBg,
                                        style: TextStyle(color: textPrimary),
                                        decoration: InputDecoration(
                                          labelText: 'Account Type',
                                          labelStyle: TextStyle(
                                            color: textSecondary,
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: borderCol,
                                            ),
                                          ),
                                        ),
                                        items: AccountType.values
                                            .where(
                                              (t) =>
                                                  t != AccountType.creditCard ||
                                                  !_isEdit,
                                            ) // cannot change to/from Credit Card in edit mode
                                            .map(
                                              (type) => DropdownMenuItem(
                                                value: type,
                                                child: Text(
                                                  type.name.toUpperCase(),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _isEdit
                                            ? null
                                            : (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _selectedType = val;
                                                    if (val ==
                                                        AccountType
                                                            .creditCard) {
                                                      _selectedIcon = 'card';
                                                    } else {
                                                      _selectedIcon = 'bank';
                                                    }
                                                  });
                                                }
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),

                                    // Currency Dropdown
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedCurrency,
                                        dropdownColor: cardBg,
                                        style: TextStyle(color: textPrimary),
                                        decoration: InputDecoration(
                                          labelText: 'Currency',
                                          labelStyle: TextStyle(
                                            color: textSecondary,
                                          ),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(
                                              color: borderCol,
                                            ),
                                          ),
                                        ),
                                        items: _currencies
                                            .map(
                                              (curr) => DropdownMenuItem(
                                                value: curr,
                                                child: Text(curr),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: _isEdit
                                            ? null
                                            : (val) {
                                                if (val != null) {
                                                  setState(() {
                                                    _selectedCurrency = val;
                                                  });
                                                }
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.lg),

                                // Opening Balance field (only for creation)
                                if (!_isEdit) ...[
                                  TextFormField(
                                    controller: _openingBalanceController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText:
                                          'Opening Balance (${_selectedCurrency})',
                                      labelStyle: TextStyle(
                                        color: textSecondary,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: borderCol,
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppColors.darkAccentPrimary,
                                        ),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Please enter opening balance';
                                      }
                                      if (double.tryParse(val) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      if (double.parse(val) < 0) {
                                        return 'Opening balance cannot be negative';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],

                                // Credit Card Specific Fields
                                if (_selectedType ==
                                    AccountType.creditCard) ...[
                                  TextFormField(
                                    controller: _creditLimitController,
                                    keyboardType: TextInputType.number,
                                    style: TextStyle(color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText:
                                          'Credit Limit (${_selectedCurrency})',
                                      labelStyle: TextStyle(
                                        color: textSecondary,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: borderCol,
                                        ),
                                      ),
                                      focusedBorder: const UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: AppColors.darkAccentPrimary,
                                        ),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Please enter credit limit';
                                      }
                                      if (double.tryParse(val) == null) {
                                        return 'Please enter a valid number';
                                      }
                                      if (double.parse(val) < 0) {
                                        return 'Limit cannot be negative';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),

                                  if (!_isEdit) ...[
                                    TextFormField(
                                      controller: _openingOutstandingController,
                                      keyboardType: TextInputType.number,
                                      style: TextStyle(color: textPrimary),
                                      decoration: InputDecoration(
                                        labelText:
                                            'Opening Outstanding Debt (${_selectedCurrency})',
                                        labelStyle: TextStyle(
                                          color: textSecondary,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: borderCol,
                                          ),
                                        ),
                                        focusedBorder:
                                            const UnderlineInputBorder(
                                              borderSide: BorderSide(
                                                color:
                                                    AppColors.darkAccentPrimary,
                                              ),
                                            ),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Please enter opening outstanding';
                                        }
                                        if (double.tryParse(val) == null) {
                                          return 'Please enter a valid number';
                                        }
                                        if (double.parse(val) < 0) {
                                          return 'Outstanding cannot be negative';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                  ],

                                  DropdownButtonFormField<int>(
                                    value: _selectedBillDay,
                                    dropdownColor: cardBg,
                                    style: TextStyle(color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Bill-Generation Day of Month',
                                      labelStyle: TextStyle(
                                        color: textSecondary,
                                      ),
                                      enabledBorder: UnderlineInputBorder(
                                        borderSide: BorderSide(
                                          color: borderCol,
                                        ),
                                      ),
                                    ),
                                    items:
                                        List.generate(28, (index) => index + 1)
                                            .map(
                                              (day) => DropdownMenuItem(
                                                value: day,
                                                child: Text('Day $day'),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedBillDay = val;
                                        });
                                      }
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],

                                // Icon Picker
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
                                _isEdit ? 'SAVE CHANGES' : 'CREATE ACCOUNT',
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
