import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/design_system/tokens.dart';
import '../../domain/account.dart';

class AdjustBalanceDialog extends StatefulWidget {
  final Account account;
  final int trackedBalance; // minor units
  final Function(int actualBalanceMinorUnits) onAdjust;

  const AdjustBalanceDialog({
    Key? key,
    required this.account,
    required this.trackedBalance,
    required this.onAdjust,
  }) : super(key: key);

  @override
  State<AdjustBalanceDialog> createState() => _AdjustBalanceDialogState();
}

class _AdjustBalanceDialogState extends State<AdjustBalanceDialog> {
  final _controller = TextEditingController();
  int _calculatedDiff = 0; // minor units
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCalculations);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateCalculations() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _calculatedDiff = 0;
        _isValid = false;
      });
      return;
    }

    final double? majorVal = double.tryParse(text);
    if (majorVal == null || majorVal < 0) {
      setState(() {
        _calculatedDiff = 0;
        _isValid = false;
      });
      return;
    }

    final int minorVal = (majorVal * 100).round();
    setState(() {
      _calculatedDiff = minorVal - widget.trackedBalance;
      _isValid = _calculatedDiff != 0;
    });
  }

  String _formatAmount(int amountMinorUnits, String currency) {
    final double major = amountMinorUnits.abs() / 100.0;
    final String symbol = currency.toUpperCase() == 'INR'
        ? '₹'
        : (currency.toUpperCase() == 'USD'
              ? '\$'
              : (currency.toUpperCase() == 'EUR' ? '€' : '$currency '));
    final sign = amountMinorUnits < 0 ? '-' : (amountMinorUnits > 0 ? '+' : '');
    return '$sign$symbol${major.toStringAsFixed(0)}';
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

    final isCreditCard = widget.account.type == AccountType.creditCard;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: BorderSide(color: borderCol),
      ),
      title: Text(
        'ADJUST BALANCE',
        style: AppTypography.sectionHeading.copyWith(
          color: textPrimary,
          letterSpacing: 1.5,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tracked Balance info
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isCreditCard ? 'Tracked Outstanding:' : 'Tracked Balance:',
                  style: TextStyle(color: textSecondary),
                ),
                Text(
                  _formatAmount(
                    widget.trackedBalance,
                    widget.account.currency,
                  ).replaceAll('+', ''),
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Actual Balance Input
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: TextStyle(color: textPrimary),
              decoration: InputDecoration(
                labelText: isCreditCard
                    ? 'Actual Outstanding Debt'
                    : 'Actual Balance',
                labelStyle: TextStyle(color: textSecondary),
                hintText: 'e.g. 500',
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: borderCol),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.darkAccentPrimary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Dynamic Difference output
            if (_isValid) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Calculated Adjustment:',
                    style: TextStyle(color: textSecondary),
                  ),
                  Text(
                    _formatAmount(_calculatedDiff, widget.account.currency),
                    style: TextStyle(
                      color: _calculatedDiff > 0
                          ? (isCreditCard
                                ? AppColors.statusError
                                : AppColors.darkAccentPrimary)
                          : (isCreditCard
                                ? AppColors.darkAccentPrimary
                                : AppColors.statusError),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            // Disclaimer Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(AppRadius.small),
                border: Border.all(color: borderCol),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.info, size: 16, color: textSecondary),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'This adjustment is recorded as a specialized Balance Adjustment transaction. It does not count as income, spending, savings, or affect your category budgets.',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          onPressed: _isValid
              ? () {
                  final double major = double.parse(_controller.text.trim());
                  final int minor = (major * 100).round();
                  widget.onAdjust(minor);
                  Navigator.pop(context);
                }
              : null,
        ),
      ],
    );
  }
}
