import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/di/service_locator.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../../core/platform/haptic_service.dart';
import '../../../profiles/domain/repositories/profile_repository.dart';
import '../../../accounts/domain/repositories/account_repository.dart';
import '../../../accounts/domain/payment_mode.dart';
import '../../../categories/domain/repositories/category_repository.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../../../goals/domain/repositories/goal_repository.dart';
import '../../../recurring/domain/repositories/recurring_repository.dart';
import '../../domain/transaction.dart';
import '../bloc/transactions_bloc.dart';
import '../bloc/transactions_event.dart';
import '../bloc/transactions_state.dart';
import 'split_categories_sheet.dart';
import 'split_accounts_sheet.dart';

class RecordTransactionSheet extends StatefulWidget {
  const RecordTransactionSheet({Key? key}) : super(key: key);

  @override
  State<RecordTransactionSheet> createState() => _RecordTransactionSheetState();
}

class _RecordTransactionSheetState extends State<RecordTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();

  TransactionType _selectedType = TransactionType.expense;
  DateTime _selectedDate = DateTime.now();
  String? _selectedPaymentModeId;
  String? _selectedTagId;

  // Single Category / Account selections
  String? _selectedCategoryId;
  String? _selectedSourceAccountId;
  String? _selectedDestinationAccountId;

  // For Transfers: Source and Destination can be Account or Goal
  String _transferSourceType = 'account'; // 'account' or 'goal'
  String? _transferSourceAccountId;
  String? _transferSourceGoalId;

  String _transferDestType = 'account'; // 'account' or 'goal'
  String? _transferDestAccountId;
  String? _transferDestGoalId;

  // Splits mappings
  Map<String, int> _categorySplits = {}; // categoryId -> amount minor units
  Map<String, int> _accountSplits = {}; // accountId -> amount minor units

  bool _isCategorySplitEnabled = false;
  bool _isAccountSplitEnabled = false;

  // Recurring Options
  bool _isRecurring = false;
  String _recurringFrequency = 'monthly';
  bool _isAutoRecord = true;

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  int get _parsedAmountMinor {
    final double major = double.tryParse(_amountController.text.trim()) ?? 0.0;
    return (major * 100).round();
  }

  void _openCategorySplits(
    BuildContext context,
    TransactionFormMetadataLoaded metadata,
  ) async {
    sl<HapticService>().selectionClick();
    final amountMinor = _parsedAmountMinor;
    if (amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter transaction amount first')),
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bContext) => SplitCategoriesSheet(
        totalAmount: amountMinor,
        categories: metadata.categories,
        initialAllocations: _categorySplits,
        currency: metadata.defaultCurrency,
      ),
    );

    if (result != null) {
      setState(() {
        _categorySplits = result;
        _isCategorySplitEnabled = true;
      });
    }
  }

  void _openAccountSplits(
    BuildContext context,
    TransactionFormMetadataLoaded metadata,
  ) async {
    sl<HapticService>().selectionClick();
    final amountMinor = _parsedAmountMinor;
    if (amountMinor <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter transaction amount first')),
      );
      return;
    }

    final title = _selectedType == TransactionType.expense
        ? 'Source Accounts'
        : 'Destination Accounts';

    final result = await showModalBottomSheet<Map<String, int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bContext) => SplitAccountsSheet(
        totalAmount: amountMinor,
        accounts: metadata.accounts,
        initialAllocations: _accountSplits,
        currency: metadata.defaultCurrency,
        title: title,
      ),
    );

    if (result != null) {
      setState(() {
        _accountSplits = result;
        _isAccountSplitEnabled = true;
      });
    }
  }

  void _submitForm(
    BuildContext context,
    TransactionFormMetadataLoaded metadata,
  ) {
    if (!_formKey.currentState!.validate()) {
      sl<HapticService>().vibrate();
      return;
    }

    final totalVal = _parsedAmountMinor;

    // Build Category Allocations
    final categoryAllocations = <CategoryAllocationInput>[];
    if (_selectedType != TransactionType.transfer) {
      if (_isCategorySplitEnabled && _categorySplits.isNotEmpty) {
        _categorySplits.forEach((catId, val) {
          categoryAllocations.add(
            CategoryAllocationInput(categoryId: catId, amount: val),
          );
        });
      } else {
        if (_selectedCategoryId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Category selection is required')),
          );
          return;
        }
        categoryAllocations.add(
          CategoryAllocationInput(
            categoryId: _selectedCategoryId!,
            amount: totalVal,
          ),
        );
      }
    }

    // Build Transfer Allocations
    final transferAllocations = <TransferAllocationInput>[];
    if (_selectedType == TransactionType.expense) {
      if (_isAccountSplitEnabled && _accountSplits.isNotEmpty) {
        _accountSplits.forEach((accId, val) {
          transferAllocations.add(
            TransferAllocationInput(
              role: 'source',
              endpointType: 'account',
              accountId: accId,
              amount: val,
            ),
          );
        });
      } else {
        if (_selectedSourceAccountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Source Account is required')),
          );
          return;
        }
        transferAllocations.add(
          TransferAllocationInput(
            role: 'source',
            endpointType: 'account',
            accountId: _selectedSourceAccountId!,
            amount: totalVal,
          ),
        );
      }
    } else if (_selectedType == TransactionType.income) {
      if (_isAccountSplitEnabled && _accountSplits.isNotEmpty) {
        _accountSplits.forEach((accId, val) {
          transferAllocations.add(
            TransferAllocationInput(
              role: 'destination',
              endpointType: 'account',
              accountId: accId,
              amount: val,
            ),
          );
        });
      } else {
        if (_selectedDestinationAccountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Destination Account is required')),
          );
          return;
        }
        transferAllocations.add(
          TransferAllocationInput(
            role: 'destination',
            endpointType: 'account',
            accountId: _selectedDestinationAccountId!,
            amount: totalVal,
          ),
        );
      }
    } else if (_selectedType == TransactionType.transfer) {
      // Source Allocation
      final String? srcAccId = _transferSourceType == 'account'
          ? _transferSourceAccountId
          : null;
      final String? srcGoalId = _transferSourceType == 'goal'
          ? _transferSourceGoalId
          : null;
      if (srcAccId == null && srcGoalId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer Source Account/Goal is required'),
          ),
        );
        return;
      }
      transferAllocations.add(
        TransferAllocationInput(
          role: 'source',
          endpointType: _transferSourceType,
          accountId: srcAccId,
          goalId: srcGoalId,
          amount: totalVal,
        ),
      );

      // Destination Allocation
      final String? dstAccId = _transferDestType == 'account'
          ? _transferDestAccountId
          : null;
      final String? dstGoalId = _transferDestType == 'goal'
          ? _transferDestGoalId
          : null;
      if (dstAccId == null && dstGoalId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer Destination Account/Goal is required'),
          ),
        );
        return;
      }
      transferAllocations.add(
        TransferAllocationInput(
          role: 'destination',
          endpointType: _transferDestType,
          accountId: dstAccId,
          goalId: dstGoalId,
          amount: totalVal,
        ),
      );
    }

    if (_selectedPaymentModeId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Payment Mode is required')));
      return;
    }

    context.read<TransactionsBloc>().add(
      SaveTransaction(
        type: _selectedType,
        totalAmount: totalVal,
        date: _selectedDate,
        paymentModeId: _selectedPaymentModeId!,
        note: _notesController.text.trim(),
        tagId: _selectedTagId,
        categoryAllocations: categoryAllocations,
        transferAllocations: transferAllocations,
        isRecurring: _isRecurring,
        recurringFrequency: _isRecurring ? _recurringFrequency : null,
        isAutoRecord: _isAutoRecord,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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

    return BlocProvider<TransactionsBloc>(
      create: (context) => TransactionsBloc(
        profileRepository: sl<ProfileRepository>(),
        accountRepository: sl<AccountRepository>(),
        categoryRepository: sl<CategoryRepository>(),
        transactionRepository: sl<TransactionRepository>(),
        goalRepository: sl<GoalRepository>(),
        recurringRepository: sl<RecurringRepository>(),
      )..add(const LoadTransactionFormMetadata()),
      child: BlocConsumer<TransactionsBloc, TransactionsState>(
        listener: (context, state) {
          if (state is TransactionSaveSuccess) {
            sl<HapticService>().mediumImpact();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
            Navigator.pop(context, true);
          } else if (state is TransactionFormError) {
            sl<HapticService>().vibrate();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.statusError,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TransactionFormInitial ||
              state is TransactionFormLoading) {
            return Container(
              height: 400,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.sheet),
                  topRight: Radius.circular(AppRadius.sheet),
                ),
              ),
              child: const Center(child: CircularProgressIndicator()),
            );
          }

          if (state is TransactionFormMetadataLoaded) {
            // Pick default selections if not set yet
            if (_selectedCategoryId == null && state.categories.isNotEmpty) {
              _selectedCategoryId = state.categories.first.id;
            }
            if (_selectedSourceAccountId == null && state.accounts.isNotEmpty) {
              _selectedSourceAccountId = state.accounts.first.id;
            }
            if (_selectedDestinationAccountId == null &&
                state.accounts.isNotEmpty) {
              _selectedDestinationAccountId = state.accounts.first.id;
            }
            if (_transferSourceAccountId == null && state.accounts.isNotEmpty) {
              _transferSourceAccountId = state.accounts.first.id;
            }
            if (_transferSourceGoalId == null && state.goals.isNotEmpty) {
              _transferSourceGoalId = state.goals.first.id;
            }
            if (_transferDestAccountId == null && state.accounts.isNotEmpty) {
              _transferDestAccountId = state.accounts.first.id;
            }
            if (_transferDestGoalId == null && state.goals.isNotEmpty) {
              _transferDestGoalId = state.goals.first.id;
            }

            // Filter compatibility of payment modes based on active account
            final activeAccountIdForPayment =
                _selectedType == TransactionType.expense
                ? _selectedSourceAccountId
                : (_selectedType == TransactionType.income
                      ? _selectedDestinationAccountId
                      : _transferSourceAccountId);
            final activeAccount = state.accounts
                .where((a) => a.id == activeAccountIdForPayment)
                .firstOrNull;

            final List<PaymentMode> compatibleModes = state.paymentModes.where((
              pm,
            ) {
              if (activeAccount != null) {
                return pm.isCompatibleWith(activeAccount.type);
              }
              return true;
            }).toList();

            if (compatibleModes.isNotEmpty &&
                (_selectedPaymentModeId == null ||
                    !compatibleModes.any(
                      (pm) => pm.id == _selectedPaymentModeId,
                    ))) {
              // Try finding default compatible payment mode, otherwise use the first one
              final defaultPm = compatibleModes
                  .where((pm) => pm.isDefault)
                  .firstOrNull;
              _selectedPaymentModeId =
                  defaultPm?.id ?? compatibleModes.first.id;
            }

            return Container(
              padding: EdgeInsets.only(
                left: AppSpacing.md,
                right: AppSpacing.md,
                top: AppSpacing.md,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.sheet),
                  topRight: Radius.circular(AppRadius.sheet),
                ),
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Slide bar
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: borderCol,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Sheet title
                      Text(
                        'RECORD TRANSACTION',
                        style: AppTypography.sectionHeading.copyWith(
                          color: textPrimary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 1. Transaction Type Selector
                      Row(
                        children: TransactionType.values.map((type) {
                          final isSelected = _selectedType == type;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: ChoiceChip(
                                label: Text(type.name.toUpperCase()),
                                selected: isSelected,
                                onSelected: (val) {
                                  if (val) {
                                    sl<HapticService>().selectionClick();
                                    setState(() {
                                      _selectedType = type;
                                      _selectedPaymentModeId =
                                          null; // reset to fetch default compatible
                                      _isCategorySplitEnabled = false;
                                      _isAccountSplitEnabled = false;
                                      _categorySplits.clear();
                                      _accountSplits.clear();
                                    });
                                  }
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 2. Amount input
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: AppTypography.display.copyWith(
                          color: textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '0.00',
                          prefixText: state.defaultCurrency == 'INR'
                              ? '₹ '
                              : '${state.defaultCurrency} ',
                          prefixStyle: AppTypography.display.copyWith(
                            color: textSecondary,
                          ),
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
                          if (val == null || val.trim().isEmpty)
                            return 'Enter amount';
                          if (double.tryParse(val) == null ||
                              double.parse(val) <= 0)
                            return 'Must be positive';
                          return null;
                        },
                        onChanged: (_) {
                          // Clear splits if amount changes, to ensure they re-enter matching splits
                          setState(() {
                            _categorySplits.clear();
                            _accountSplits.clear();
                            _isCategorySplitEnabled = false;
                            _isAccountSplitEnabled = false;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 3. Category Selector (Expense/Income only)
                      if (_selectedType != TransactionType.transfer) ...[
                        if (!_isCategorySplitEnabled)
                          DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            dropdownColor: cardBg,
                            style: TextStyle(color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: TextStyle(color: textSecondary),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: borderCol),
                              ),
                            ),
                            items: state.categories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c.id,
                                    child: Text(
                                      c.parentCategoryId != null
                                          ? '↳ ${c.name}'
                                          : c.name,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                              });
                            },
                          )
                        else
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Multiple Categories Split Enabled',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _categorySplits.entries
                                  .map((e) {
                                    final cat = state.categories
                                        .where((c) => c.id == e.key)
                                        .firstOrNull;
                                    final double major = e.value / 100.0;
                                    return '${cat?.name ?? 'Category'}: ₹${major.toStringAsFixed(0)}';
                                  })
                                  .join(', '),
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                LucideIcons.xCircle,
                                color: AppColors.statusError,
                              ),
                              onPressed: () {
                                setState(() {
                                  _categorySplits.clear();
                                  _isCategorySplitEnabled = false;
                                });
                              },
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),

                        // Splits Categories Trigger Button
                        TextButton(
                          child: Text(
                            'Does this ${_selectedType.name} contain multiple categories?',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkAccentPrimary
                                  : AppColors.lightAccentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () => _openCategorySplits(context, state),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // 4. Account Selector
                      // --- Expense Account ---
                      if (_selectedType == TransactionType.expense) ...[
                        if (!_isAccountSplitEnabled)
                          DropdownButtonFormField<String>(
                            value: _selectedSourceAccountId,
                            dropdownColor: cardBg,
                            style: TextStyle(color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Account',
                              labelStyle: TextStyle(color: textSecondary),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: borderCol),
                              ),
                            ),
                            items: state.accounts
                                .map(
                                  (acc) => DropdownMenuItem(
                                    value: acc.id,
                                    child: Text(
                                      '${acc.name} (${acc.currency})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedSourceAccountId = val;
                                _selectedPaymentModeId =
                                    null; // force reload default compatible
                              });
                            },
                          )
                        else
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Multiple Accounts Split Enabled',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _accountSplits.entries
                                  .map((e) {
                                    final acc = state.accounts
                                        .where((a) => a.id == e.key)
                                        .firstOrNull;
                                    final double major = e.value / 100.0;
                                    return '${acc?.name ?? 'Account'}: ₹${major.toStringAsFixed(0)}';
                                  })
                                  .join(', '),
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                LucideIcons.xCircle,
                                color: AppColors.statusError,
                              ),
                              onPressed: () {
                                setState(() {
                                  _accountSplits.clear();
                                  _isAccountSplitEnabled = false;
                                });
                              },
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),

                        // Splits Accounts Trigger Button
                        TextButton(
                          child: Text(
                            'Did you pay from two different accounts for this transaction?',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkAccentPrimary
                                  : AppColors.lightAccentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () => _openAccountSplits(context, state),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // --- Income Account ---
                      if (_selectedType == TransactionType.income) ...[
                        if (!_isAccountSplitEnabled)
                          DropdownButtonFormField<String>(
                            value: _selectedDestinationAccountId,
                            dropdownColor: cardBg,
                            style: TextStyle(color: textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Account',
                              labelStyle: TextStyle(color: textSecondary),
                              enabledBorder: UnderlineInputBorder(
                                borderSide: BorderSide(color: borderCol),
                              ),
                            ),
                            items: state.accounts
                                .map(
                                  (acc) => DropdownMenuItem(
                                    value: acc.id,
                                    child: Text(
                                      '${acc.name} (${acc.currency})',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedDestinationAccountId = val;
                                _selectedPaymentModeId = null;
                              });
                            },
                          )
                        else
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Multiple Accounts Split Enabled',
                              style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _accountSplits.entries
                                  .map((e) {
                                    final acc = state.accounts
                                        .where((a) => a.id == e.key)
                                        .firstOrNull;
                                    final double major = e.value / 100.0;
                                    return '${acc?.name ?? 'Account'}: ₹${major.toStringAsFixed(0)}';
                                  })
                                  .join(', '),
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                LucideIcons.xCircle,
                                color: AppColors.statusError,
                              ),
                              onPressed: () {
                                setState(() {
                                  _accountSplits.clear();
                                  _isAccountSplitEnabled = false;
                                });
                              },
                            ),
                          ),
                        const SizedBox(height: AppSpacing.xs),

                        TextButton(
                          child: Text(
                            'Did you receive this income in two different accounts?',
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.darkAccentPrimary
                                  : AppColors.lightAccentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          onPressed: () => _openAccountSplits(context, state),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                      ],

                      // --- Transfer Source/Destination Selector ---
                      if (_selectedType == TransactionType.transfer) ...[
                        Row(
                          children: [
                            // Source Endpoint Type
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _transferSourceType,
                                dropdownColor: cardBg,
                                style: TextStyle(color: textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Source Type',
                                  labelStyle: TextStyle(color: textSecondary),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'account',
                                    child: Text('Account'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'goal',
                                    child: Text('Goal'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _transferSourceType = val;
                                      _selectedPaymentModeId = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            // Source Endpoint dropdown selector
                            Expanded(
                              child: _transferSourceType == 'account'
                                  ? DropdownButtonFormField<String>(
                                      value: _transferSourceAccountId,
                                      dropdownColor: cardBg,
                                      style: TextStyle(color: textPrimary),
                                      decoration: InputDecoration(
                                        labelText: 'Source Account',
                                        labelStyle: TextStyle(
                                          color: textSecondary,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: borderCol,
                                          ),
                                        ),
                                      ),
                                      items: state.accounts
                                          .map(
                                            (acc) => DropdownMenuItem(
                                              value: acc.id,
                                              child: Text(acc.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _transferSourceAccountId = val;
                                          _selectedPaymentModeId = null;
                                        });
                                      },
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: _transferSourceGoalId,
                                      dropdownColor: cardBg,
                                      style: TextStyle(color: textPrimary),
                                      decoration: InputDecoration(
                                        labelText: 'Source Goal',
                                        labelStyle: TextStyle(
                                          color: textSecondary,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: borderCol,
                                          ),
                                        ),
                                      ),
                                      items: state.goals
                                          .map(
                                            (g) => DropdownMenuItem(
                                              value: g.id,
                                              child: Text(g.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _transferSourceGoalId = val;
                                          _selectedPaymentModeId = null;
                                        });
                                      },
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),

                        Row(
                          children: [
                            // Destination Endpoint Type
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _transferDestType,
                                dropdownColor: cardBg,
                                style: TextStyle(color: textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Dest Type',
                                  labelStyle: TextStyle(color: textSecondary),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'account',
                                    child: Text('Account'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'goal',
                                    child: Text('Goal'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _transferDestType = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            // Destination Endpoint dropdown selector
                            Expanded(
                              child: _transferDestType == 'account'
                                  ? DropdownButtonFormField<String>(
                                      value: _transferDestAccountId,
                                      dropdownColor: cardBg,
                                      style: TextStyle(color: textPrimary),
                                      decoration: InputDecoration(
                                        labelText: 'Dest Account',
                                        labelStyle: TextStyle(
                                          color: textSecondary,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: borderCol,
                                          ),
                                        ),
                                      ),
                                      items: state.accounts
                                          .map(
                                            (acc) => DropdownMenuItem(
                                              value: acc.id,
                                              child: Text(acc.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _transferDestAccountId = val;
                                        });
                                      },
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: _transferDestGoalId,
                                      dropdownColor: cardBg,
                                      style: TextStyle(color: textPrimary),
                                      decoration: InputDecoration(
                                        labelText: 'Dest Goal',
                                        labelStyle: TextStyle(
                                          color: textSecondary,
                                        ),
                                        enabledBorder: UnderlineInputBorder(
                                          borderSide: BorderSide(
                                            color: borderCol,
                                          ),
                                        ),
                                      ),
                                      items: state.goals
                                          .map(
                                            (g) => DropdownMenuItem(
                                              value: g.id,
                                              child: Text(g.name),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _transferDestGoalId = val;
                                        });
                                      },
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],

                      // 5. Date Picker
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                          style: TextStyle(color: textPrimary, fontSize: 14),
                        ),
                        trailing: Icon(
                          LucideIcons.calendar,
                          color: textSecondary,
                        ),
                        onTap: () async {
                          sl<HapticService>().selectionClick();
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime.now().subtract(
                              const Duration(days: 365),
                            ),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
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
                              _selectedDate = picked;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // 6. Payment Mode Selector
                      DropdownButtonFormField<String>(
                        value: _selectedPaymentModeId,
                        dropdownColor: cardBg,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Payment Mode',
                          labelStyle: TextStyle(color: textSecondary),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderCol),
                          ),
                        ),
                        items: compatibleModes
                            .map(
                              (pm) => DropdownMenuItem(
                                value: pm.id,
                                child: Text(pm.name),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedPaymentModeId = val;
                          });
                        },
                        validator: (val) {
                          if (val == null) return 'Payment mode is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 7. Notes
                      TextFormField(
                        controller: _notesController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Notes (Optional)',
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
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 8. Tag Selector
                      DropdownButtonFormField<String>(
                        value: _selectedTagId,
                        dropdownColor: cardBg,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Tag (Optional)',
                          labelStyle: TextStyle(color: textSecondary),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: borderCol),
                          ),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('No Tag'),
                          ),
                          ...state.tags.map(
                            (t) => DropdownMenuItem<String>(
                              value: t.id,
                              child: Text(t.name),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedTagId = val;
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // 9. Recurring options
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Recurring Transaction',
                          style: TextStyle(color: textPrimary, fontSize: 14),
                        ),
                        value: _isRecurring,
                        activeColor: isDark
                            ? AppColors.darkAccentPrimary
                            : AppColors.lightAccentPrimary,
                        onChanged: (val) {
                          sl<HapticService>().selectionClick();
                          setState(() {
                            _isRecurring = val;
                          });
                        },
                      ),
                      if (_isRecurring) ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _recurringFrequency,
                                dropdownColor: cardBg,
                                style: TextStyle(color: textPrimary),
                                decoration: InputDecoration(
                                  labelText: 'Frequency',
                                  labelStyle: TextStyle(color: textSecondary),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(color: borderCol),
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'daily',
                                    child: Text('DAILY'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'weekly',
                                    child: Text('WEEKLY'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'monthly',
                                    child: Text('MONTHLY'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'yearly',
                                    child: Text('YEARLY'),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _recurringFrequency = val;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Auto Record',
                                  style: TextStyle(
                                    color: textPrimary,
                                    fontSize: 12,
                                  ),
                                ),
                                value: _isAutoRecord,
                                activeColor: isDark
                                    ? AppColors.darkAccentPrimary
                                    : AppColors.lightAccentPrimary,
                                onChanged: (val) {
                                  setState(() {
                                    _isAutoRecord = val;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      const SizedBox(height: AppSpacing.xl),

                      // Save / Cancel Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                color: textSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              sl<HapticService>().selectionClick();
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark
                                  ? AppColors.darkAccentPrimary
                                  : AppColors.lightAccentPrimary,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.small,
                                ),
                              ),
                            ),
                            child: const Text(
                              'SAVE',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _submitForm(context, state),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }
}
