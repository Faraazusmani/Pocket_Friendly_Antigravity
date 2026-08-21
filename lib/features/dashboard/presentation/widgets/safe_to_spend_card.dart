import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../../core/design_system/tokens.dart';
import '../bloc/dashboard_state.dart';

import '../../../../core/utilities/currency_formatter.dart';

class SafeToSpendCard extends StatelessWidget {
  final DashboardLoaded state;

  const SafeToSpendCard({Key? key, required this.state}) : super(key: key);

  String _formatAmount(int amountInMinorUnits, String currency) {
    return CurrencyFormatter.format(
      amountInMinorUnits,
      currency,
      privacyMode: state.privacyModeEnabled,
    );
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: borderCol, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.sparkles,
                      size: 16,
                      color: isDark
                          ? AppColors.darkAccentPrimary
                          : AppColors.lightAccentPrimary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'SAFE-TO-SPEND TODAY',
                      style: AppTypography.caption.copyWith(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      _formatAmount(state.safeToSpend, state.selectedCurrency),
                      style: AppTypography.largeAmount.copyWith(
                        color: textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      ' / day',
                      style: AppTypography.secondaryBody.copyWith(
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Based on remaining days & pending bills.',
                  style: AppTypography.caption.copyWith(color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
