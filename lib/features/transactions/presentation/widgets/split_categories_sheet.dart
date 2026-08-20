import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../categories/domain/category.dart';

class SplitCategoriesSheet extends StatefulWidget {
  final int totalAmount; // minor units
  final List<Category> categories;
  final Map<String, int> initialAllocations; // categoryId -> amount minor units
  final String currency;

  const SplitCategoriesSheet({
    Key? key,
    required this.totalAmount,
    required this.categories,
    required this.initialAllocations,
    required this.currency,
  }) : super(key: key);

  @override
  State<SplitCategoriesSheet> createState() => _SplitCategoriesSheetState();
}

class _SplitCategoriesSheetState extends State<SplitCategoriesSheet> {
  final Map<String, TextEditingController> _controllers = {};
  final List<String> _allocatedCategoryIds = [];

  @override
  void initState() {
    super.initState();
    // Initialize allocations from parent parameters
    widget.initialAllocations.forEach((catId, val) {
      _allocatedCategoryIds.add(catId);
      final double major = val / 100.0;
      _controllers[catId] = TextEditingController(
        text: major.toStringAsFixed(2),
      );
    });

    if (_allocatedCategoryIds.isEmpty && widget.categories.isNotEmpty) {
      // Add one default slot to ease UX
      _addSlot(widget.categories.first.id);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _addSlot(String catId) {
    if (!_allocatedCategoryIds.contains(catId)) {
      setState(() {
        _allocatedCategoryIds.add(catId);
        _controllers[catId] = TextEditingController();
      });
    }
  }

  void _removeSlot(String catId) {
    setState(() {
      _allocatedCategoryIds.remove(catId);
      _controllers[catId]?.dispose();
      _controllers.remove(catId);
    });
  }

  int get _allocatedSum {
    int sum = 0;
    for (final catId in _allocatedCategoryIds) {
      final double major =
          double.tryParse(_controllers[catId]?.text ?? '') ?? 0.0;
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

    // Build allocation map
    final result = <String, int>{};
    for (final catId in _allocatedCategoryIds) {
      final double major =
          double.tryParse(_controllers[catId]?.text ?? '') ?? 0.0;
      result[catId] = (major * 100).round();
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
          // Header Indicator
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
            'SPLIT CATEGORIES',
            style: AppTypography.sectionHeading.copyWith(
              color: textPrimary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Allocate spending across multiple categories. Total must equal transaction amount.',
            style: AppTypography.caption.copyWith(color: textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),

          // Total comparison bar
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

          // Allocation inputs
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _allocatedCategoryIds.length,
              itemBuilder: (context, index) {
                final catId = _allocatedCategoryIds[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      // Category selection dropdown
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: catId,
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
                          items: widget.categories
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
                            if (val != null && val != catId) {
                              setState(() {
                                // Swap category ID but preserve controller values
                                final ctrl = _controllers[catId]!;
                                _allocatedCategoryIds[index] = val;
                                _controllers[val] = ctrl;
                                _controllers.remove(catId);
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),

                      // Amount input
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _controllers[catId],
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
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.darkAccentPrimary,
                              ),
                            ),
                          ),
                          onChanged: (_) {
                            setState(() {}); // Recalculate progress values
                          },
                        ),
                      ),

                      // Remove button
                      IconButton(
                        icon: const Icon(
                          LucideIcons.minusCircle,
                          color: AppColors.statusError,
                        ),
                        onPressed: () => _removeSlot(catId),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Add Category button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: borderCol),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
            ),
            icon: const Icon(LucideIcons.plus, size: 16),
            label: const Text('Add Category Slot'),
            onPressed: () {
              // Find first category not yet allocated
              final nextCat = widget.categories
                  .where((c) => !_allocatedCategoryIds.contains(c.id))
                  .firstOrNull;
              if (nextCat != null) {
                _addSlot(nextCat.id);
              } else if (widget.categories.isNotEmpty) {
                // If all are allocated, allow duplicate selection which user can change
                _addSlot(widget.categories.first.id);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),

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
