import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/design_system/tokens.dart';
import '../../../transactions/domain/transaction.dart';
import '../bloc/dashboard_state.dart';

class RecentTransactions extends StatelessWidget {
  final DashboardLoaded state;

  const RecentTransactions({Key? key, required this.state}) : super(key: key);

  String _formatAmount(int amountInMinorUnits, String currency) {
    if (state.privacyModeEnabled) return '••••';
    final double amt = amountInMinorUnits / 100.0;
    final symbol = currency.toUpperCase() == 'INR'
        ? '₹'
        : (currency.toUpperCase() == 'USD' ? '\$' : '$currency ');

    final digits = amt.toStringAsFixed(0);
    final buffer = StringBuffer();
    int count = 0;
    for (int i = digits.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(digits[i]);
      count++;
    }
    return '$symbol${buffer.toString().split('').reversed.join('')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) return 'Today';
    if (txDate == yesterday) return 'Yesterday';

    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  IconData _getTransactionIcon(Transaction tx) {
    switch (tx.type) {
      case TransactionType.income:
        return LucideIcons.trendingUp;
      case TransactionType.expense:
        return LucideIcons.shoppingBag;
      case TransactionType.transfer:
        return LucideIcons.arrowLeftRight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? AppColors.darkSurfacePrimary
        : AppColors.lightBackgroundSecondary;
    final borderCol = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final textSecondary = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    if (state.recentTransactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECENT TRANSACTIONS',
              style: AppTypography.caption.copyWith(
                color: textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: borderCol, width: 1.0),
              ),
              child: Text(
                'No transactions recorded yet.',
                style: AppTypography.secondaryBody.copyWith(
                  color: textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Map category list for fast lookup
    final categoryMap = {for (final c in state.categories) c.id: c.name};
    // Map account list for fast lookup
    final accountMap = {for (final a in state.accounts) a.id: a.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'RECENT TRANSACTIONS',
            style: AppTypography.caption.copyWith(
              color: textSecondary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: state.recentTransactions.length,
          itemBuilder: (context, index) {
            final tx = state.recentTransactions[index];
            final isIncome = tx.type == TransactionType.income;

            // Generate description text
            String desc = tx.note?.isNotEmpty == true
                ? tx.note!
                : tx.type.name.toUpperCase();
            if (tx.categoryAllocations.isNotEmpty) {
              final catNames = tx.categoryAllocations
                  .map((ca) => categoryMap[ca.categoryId] ?? 'Category')
                  .join(', ');
              desc = catNames;
            }

            // Generate account/payment mode metadata text
            String meta = '';
            if (tx.type == TransactionType.transfer) {
              final src = tx.transferAllocations
                  .where((ta) => ta.role == AllocationRole.source)
                  .firstOrNull;
              final dst = tx.transferAllocations
                  .where((ta) => ta.role == AllocationRole.destination)
                  .firstOrNull;
              final srcName = src?.endpointType == EndpointType.account
                  ? (accountMap[src?.accountId] ?? 'Account')
                  : 'Goal';
              final dstName = dst?.endpointType == EndpointType.account
                  ? (accountMap[dst?.accountId] ?? 'Account')
                  : 'Goal';
              meta = '$srcName → $dstName';
            } else {
              final acc = tx.transferAllocations.firstOrNull;
              final accName = acc?.endpointType == EndpointType.account
                  ? (accountMap[acc?.accountId] ?? 'Account')
                  : 'Goal';
              meta = accName;
            }

            return Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: borderCol, width: 1.0),
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    height: 40,
                    width: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackgroundSecondary
                          : AppColors.lightSurfacePrimary,
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Icon(
                      _getTransactionIcon(tx),
                      color: isIncome
                          ? AppColors.statusSuccess
                          : (isDark
                                ? AppColors.darkAccentPrimary
                                : AppColors.lightAccentPrimary),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Transaction Note/Category & Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          desc,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body.copyWith(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2.0),
                        Row(
                          children: [
                            Text(
                              _formatDate(tx.date),
                              style: AppTypography.caption.copyWith(
                                color: textSecondary,
                              ),
                            ),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '•',
                                style: AppTypography.caption.copyWith(
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  meta,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // Transaction Amount
                  Text(
                    '${isIncome ? '+' : '-'}${_formatAmount(tx.totalAmount, tx.currency)}',
                    style: AppTypography.body.copyWith(
                      color: isIncome ? AppColors.statusSuccess : textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
