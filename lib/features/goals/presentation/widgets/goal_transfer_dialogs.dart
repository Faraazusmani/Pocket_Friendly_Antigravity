import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/design_system/tokens.dart';
import '../../domain/goal.dart';
import '../../../accounts/domain/account.dart';

class ContributeGoalDialog extends StatefulWidget {
  final Goal goal;
  final List<Account> accounts;
  final Function(String sourceAccountId, int amountMinorUnits, DateTime date)
  onSave;

  const ContributeGoalDialog({
    Key? key,
    required this.goal,
    required this.accounts,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ContributeGoalDialog> createState() => _ContributeGoalDialogState();
}

class _ContributeGoalDialogState extends State<ContributeGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
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

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: borderCol),
      ),
      title: Text(
        'CONTRIBUTE TO GOAL',
        style: AppTypography.sectionHeading.copyWith(
          color: textPrimary,
          letterSpacing: 1.5,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Source Account Dropdown
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                dropdownColor: cardBg,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Source Account',
                  labelStyle: TextStyle(color: textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderCol),
                  ),
                ),
                items: widget.accounts
                    .map(
                      (acc) => DropdownMenuItem(
                        value: acc.id,
                        child: Text('${acc.name} (${acc.currency})'),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedAccountId = val;
                  });
                },
                validator: (val) {
                  if (val == null) return 'Please select source account';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Amount (${widget.goal.currency})',
                  labelStyle: TextStyle(color: textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.darkAccentPrimary),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  if (double.tryParse(val) == null || double.parse(val) <= 0) {
                    return 'Must be positive';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Date Picker trigger
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: TextStyle(color: textPrimary, fontSize: 14),
                ),
                trailing: Icon(LucideIcons.calendar, color: textSecondary),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: isDark ? ThemeData.dark() : ThemeData.light(),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            'CANCEL',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.darkAccentPrimary
                : AppColors.lightAccentPrimary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
          ),
          child: const Text(
            'SAVE',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final double major = double.parse(_amountController.text.trim());
              final int minor = (major * 100).round();
              widget.onSave(_selectedAccountId!, minor, _selectedDate);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}

class WithdrawGoalDialog extends StatefulWidget {
  final Goal goal;
  final int currentBalance; // minor units
  final List<Account> accounts;
  final Function(
    String destinationAccountId,
    int amountMinorUnits,
    DateTime date,
  )
  onSave;

  const WithdrawGoalDialog({
    Key? key,
    required this.goal,
    required this.currentBalance,
    required this.accounts,
    required this.onSave,
  }) : super(key: key);

  @override
  State<WithdrawGoalDialog> createState() => _WithdrawGoalDialogState();
}

class _WithdrawGoalDialogState extends State<WithdrawGoalDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatAmount(int amountMinorUnits, String currency) {
    final double major = amountMinorUnits / 100.0;
    final String symbol = currency.toUpperCase() == 'INR' ? '₹' : '$currency ';
    return '$symbol${major.toStringAsFixed(0)}';
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

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: borderCol),
      ),
      title: Text(
        'WITHDRAW FROM GOAL',
        style: AppTypography.sectionHeading.copyWith(
          color: textPrimary,
          letterSpacing: 1.5,
        ),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Display current savings balance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Available Savings:',
                    style: TextStyle(color: textSecondary),
                  ),
                  Text(
                    _formatAmount(widget.currentBalance, widget.goal.currency),
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Destination Account Dropdown
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                dropdownColor: cardBg,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Destination Account',
                  labelStyle: TextStyle(color: textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderCol),
                  ),
                ),
                items: widget.accounts
                    .map(
                      (acc) => DropdownMenuItem(
                        value: acc.id,
                        child: Text('${acc.name} (${acc.currency})'),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedAccountId = val;
                  });
                },
                validator: (val) {
                  if (val == null) return 'Please select destination account';
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Amount field with withdrawal invariant check
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  labelText: 'Amount (${widget.goal.currency})',
                  labelStyle: TextStyle(color: textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: borderCol),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.darkAccentPrimary),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  final double? major = double.tryParse(val);
                  if (major == null || major <= 0) {
                    return 'Must be positive';
                  }
                  final int minor = (major * 100).round();
                  if (minor > widget.currentBalance) {
                    return 'Exceeds Goal balance. Max: ${_formatAmount(widget.currentBalance, widget.goal.currency)}';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Date Picker trigger
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: TextStyle(color: textPrimary, fontSize: 14),
                ),
                trailing: Icon(LucideIcons.calendar, color: textSecondary),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    builder: (context, child) {
                      return Theme(
                        data: isDark ? ThemeData.dark() : ThemeData.light(),
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          child: Text(
            'CANCEL',
            style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark
                ? AppColors.darkAccentPrimary
                : AppColors.lightAccentPrimary,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.small),
            ),
          ),
          child: const Text(
            'SAVE',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final double major = double.parse(_amountController.text.trim());
              final int minor = (major * 100).round();
              widget.onSave(_selectedAccountId!, minor, _selectedDate);
              Navigator.pop(context);
            }
          },
        ),
      ],
    );
  }
}
