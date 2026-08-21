import 'package:flutter/material.dart';
import '../../../../core/design_system/tokens.dart';
import '../bloc/dashboard_state.dart';

import '../../../../core/utilities/currency_formatter.dart';

class SnapshotCard extends StatefulWidget {
  final DashboardLoaded state;

  const SnapshotCard({Key? key, required this.state}) : super(key: key);

  @override
  State<SnapshotCard> createState() => _SnapshotCardState();
}

class _SnapshotCardState extends State<SnapshotCard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _formatAmount(int amountInMinorUnits, String currency) {
    return CurrencyFormatter.format(
      amountInMinorUnits,
      currency,
      privacyMode: widget.state.privacyModeEnabled,
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
      height: 180,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: borderCol, width: 1.0),
      ),
      child: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                // VIEW 1: Budget Snapshot
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'AVAILABLE BUDGET',
                        style: AppTypography.caption.copyWith(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: Text(
                          _formatAmount(
                            widget.state.availableBudget,
                            widget.state.selectedCurrency,
                          ),
                          key: ValueKey(
                            widget.state.availableBudget +
                                (widget.state.privacyModeEnabled ? 1 : 0),
                          ),
                          style: AppTypography.display.copyWith(
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Budget',
                            style: AppTypography.secondaryBody.copyWith(
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            _formatAmount(
                              widget.state.totalBudget,
                              widget.state.selectedCurrency,
                            ),
                            style: AppTypography.body.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // VIEW 2: Balance Snapshot
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'NET AVAILABLE BALANCE',
                        style: AppTypography.caption.copyWith(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AnimatedSwitcher(
                        duration: AppMotion.fast,
                        child: Text(
                          _formatAmount(
                            widget.state.netAvailableBalance,
                            widget.state.selectedCurrency,
                          ),
                          key: ValueKey(
                            widget.state.netAvailableBalance +
                                (widget.state.privacyModeEnabled ? 1 : 0),
                          ),
                          style: AppTypography.display.copyWith(
                            color: textPrimary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Income this month',
                            style: AppTypography.secondaryBody.copyWith(
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            _formatAmount(
                              widget.state.monthlyIncome,
                              widget.state.selectedCurrency,
                            ),
                            style: AppTypography.body.copyWith(
                              color: AppColors.statusSuccess,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Spent this month',
                            style: AppTypography.secondaryBody.copyWith(
                              color: textSecondary,
                            ),
                          ),
                          Text(
                            _formatAmount(
                              widget.state.monthlySpent,
                              widget.state.selectedCurrency,
                            ),
                            style: AppTypography.body.copyWith(
                              color: AppColors.statusError,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Page Indicator
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (index) {
                final active = _currentPage == index;
                return AnimatedContainer(
                  duration: AppMotion.fast,
                  margin: const EdgeInsets.symmetric(horizontal: 3.0),
                  height: 6.0,
                  width: active ? 16.0 : 6.0,
                  decoration: BoxDecoration(
                    color: active
                        ? (isDark
                              ? AppColors.darkAccentPrimary
                              : AppColors.lightAccentPrimary)
                        : (isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightSurfaceElevated),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
