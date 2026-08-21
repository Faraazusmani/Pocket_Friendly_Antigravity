import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../accounts/domain/account.dart';

class SplitAccountsSheet extends StatefulWidget {
  final int totalAmount; // minor units
  final List<Account> accounts;
  final Map<String, int> initialAllocations; // accountId -> amount minor units
  final String currency;
  final String title; // "Source Accounts" or "Destination Accounts"

  const SplitAccountsSheet({
    Key? key,
    required this.totalAmount,
    required this.accounts,
    required this.initialAllocations,
    required this.currency,
    required this.title,
  }) : super(key: key);

  @override
  State<SplitAccountsSheet> createState() => _SplitAccountsSheetState();
}

class _SplitAccountsSheetState extends State<SplitAccountsSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _allocatedAccountIds = [];

  @override
  void initState() {
    super.initState();
    widget.initialAllocations.forEach((accId, val) {
      _allocatedAccountIds.add(accId);
      final double major = val / 100.0;
      _controllers[accId] = TextEditingController(
        text: major.toStringAsFixed(2),
      );
    });

    if (_allocatedAccountIds.isEmpty && widget.accounts.isNotEmpty) {
      _addSlot(widget.accounts.first.id);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSlot(String accId) {
    if (!_allocatedAccountIds.contains(accId)) {
      setState(() {
        _allocatedAccountIds.add(accId);
        _controllers[accId] = TextEditingController();
      });
    }
  }

  void _removeSlot(String accId) {
    setState(() {
      _allocatedAccountIds.remove(accId);
      _controllers[accId]?.dispose();
      _controllers.remove(accId);
    });
  }

  int get _allocatedSum {
    int sum = 0;
    for (final accId in _allocatedAccountIds) {
      final double major =
          double.tryParse(_controllers[accId]?.text ?? '') ?? 0.0;
      sum += (major * 100).round();
    }
    return sum;
  }

  String _formatAmount(int amountMinor) {
    final double major = amountMinor / 100.0;
    final String symbol = widget.currency.toUpperCase() == 'INR'
        ? '₹'
        : '${widget.currency} ';
    return '$symbol${major.toStringAsFixed(2)}';
  }

  void _saveSplit() {
    final sum = _allocatedSum;
    if (sum != widget.totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Total allocated (${_formatAmount(sum)}) must exactly equal transaction total (${_formatAmount(widget.totalAmount)}).',
          ),
          backgroundColor: AppColors.statusError,
        ),
      );
      return;
    }

    final result = <String, int>{};
    for (final accId in _allocatedAccountIds) {
      final double major =
          double.tryParse(_controllers[accId]?.text ?? '') ?? 0.0;
      result[accId] = (major * 100).round();
    }
    Navigator.pop(context, result);
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

    final sum = _allocatedSum;
    final remains = widget.totalAmount - sum;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.sheet),
          topRight: Radius.circular(AppRadius.sheet),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          Text(
            widget.title.toUpperCase(),
            style: AppTypography.sectionHeading.copyWith(
              color: textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Allocate transaction funding across multiple accounts. Total must equal transaction amount.',
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark ? Colors.black26 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppRadius.medium),
              border: Border.all(color: borderCol),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Transaction',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                      ),
                    ),
                    Text(
                      _formatAmount(widget.totalAmount),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      remains == 0
                          ? 'Fully Allocated'
                          : remains > 0
                          ? 'Remaining to Allocate'
                          : 'Over Allocated',
                      style: AppTypography.caption.copyWith(
                        color: remains == 0
                            ? AppColors.statusSuccess
                            : remains > 0
                            ? textSecondary
                            : AppColors.statusError,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _formatAmount(remains.abs()),
                      style: AppTypography.body.copyWith(
                        fontWeight: FontWeight.bold,
                        color: remains == 0
                            ? AppColors.statusSuccess
                            : remains > 0
                            ? textPrimary
                            : AppColors.statusError,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _allocatedAccountIds.length,
              itemBuilder: (context, index) {
                final accId = _allocatedAccountIds[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: accId,
                          dropdownColor: cardBg,
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: borderCol),
                            ),
                          ),
                          items: widget.accounts
                              .map(
                                (a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text('${a.name} (${a.currency})'),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null && val != accId) {
                              setState(() {
                                final ctrl = _controllers[accId]!;
                                _allocatedAccountIds[index] = val;
                                _controllers[val] = ctrl;
                                _controllers.remove(accId);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _controllers[accId],
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: TextStyle(color: textPrimary),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: borderCol),
                            ),
                            focusedBorder: AppBorders.focusedOutline(context),
                          ),
                          onChanged: (_) {
                            setState(() {});
                          },
                        ),
                      ),

                      IconButton(
                        icon: const Icon(
                          LucideIcons.minusCircle,
                          color: AppColors.statusError,
                        ),
                        onPressed: () => _removeSlot(accId),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: borderCol),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
            ),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add Account Slot'),
            onPressed: () {
              final nextAcc = widget.accounts
                  .where((a) => !_allocatedAccountIds.contains(a.id))
                  .firstOrNull;
              if (nextAcc != null) {
                _addSlot(nextAcc.id);
              } else if (widget.accounts.isNotEmpty) {
                _addSlot(widget.accounts.first.id);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),

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
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: remains == 0
                      ? (isDark
                            ? AppColors.darkAccentPrimary
                            : AppColors.lightAccentPrimary)
                      : borderCol,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                ),
                child: const Text(
                  'SAVE SPLIT',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: _saveSplit,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
