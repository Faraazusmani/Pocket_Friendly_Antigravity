import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../design_system/tokens.dart';
import '../platform/haptic_service.dart';
import '../../features/transactions/presentation/widgets/record_transaction_sheet.dart';
import '../di/service_locator.dart';

class NavigationShellLayout extends StatefulWidget {
  final Widget child;

  const NavigationShellLayout({Key? key, required this.child})
    : super(key: key);

  @override
  State<NavigationShellLayout> createState() => _NavigationShellLayoutState();
}

class _NavigationShellLayoutState extends State<NavigationShellLayout> {
  bool _isExploreMode = false;

  void _onTabTapped(String path) {
    sl<HapticService>().selectionClick();
    context.go(path);
  }

  void _openRecordTransactionSheet(BuildContext context) async {
    sl<HapticService>().heavyImpact();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bContext) => const RecordTransactionSheet(),
    );

    // If transaction was successfully saved, we can trigger screen refresh
    if (result == true) {
      // Trigger context re-eval or pop-refresh notifications if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark
        ? AppColors.darkTextPrimary
        : AppColors.lightTextPrimary;
    final borderCol = isDark
        ? AppColors.darkBorderSubtle
        : AppColors.lightBorderSubtle;

    // Detect taps outside navigation pill to revert explore mode
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_isExploreMode) {
          setState(() {
            _isExploreMode = false;
          });
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Screen content
            Positioned.fill(child: widget.child),

            // Floating Navigation Overlay at Bottom
            Positioned(
              left: AppSpacing.md,
              right: AppSpacing.md,
              bottom: AppSpacing.lg,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Navigation Pill with glassmorphism
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            height: 52,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.black.withOpacity(0.7)
                                  : Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                              border: Border.all(color: borderCol, width: 1.0),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: _isExploreMode
                                  ? _buildExploreTabs(
                                      location,
                                      isDark,
                                      textPrimary,
                                    )
                                  : _buildPrimaryTabs(
                                      location,
                                      isDark,
                                      textPrimary,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // separate floating "+" action pill
                    Semantics(
                      button: true,
                      label: 'Record Transaction',
                      child: GestureDetector(
                        onTap: () => _openRecordTransactionSheet(context),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkAccentPrimary
                                : AppColors.lightAccentPrimary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isDark
                                            ? AppColors.darkAccentPrimary
                                            : AppColors.lightAccentPrimary)
                                        .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            LucideIcons.plus,
                            color: Colors.black,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryTabs(
    String currentLocation,
    bool isDark,
    Color textPrimary,
  ) {
    return Row(
      key: const ValueKey('primary_tabs'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabItem(
          label: 'HOME',
          isSelected:
              currentLocation == '/' ||
              currentLocation.startsWith('/dashboard'),
          onTap: () => _onTabTapped('/'),
          isDark: isDark,
          textPrimary: textPrimary,
        ),
        _buildTabItem(
          label: 'TXS',
          isSelected: currentLocation.startsWith('/transactions'),
          onTap: () => _onTabTapped('/transactions'),
          isDark: isDark,
          textPrimary: textPrimary,
        ),
        _buildTabItem(
          label: 'EXPLORE',
          isSelected: false,
          onTap: () {
            sl<HapticService>().selectionClick();
            setState(() {
              _isExploreMode = true;
            });
          },
          isDark: isDark,
          textPrimary: textPrimary,
        ),
      ],
    );
  }

  Widget _buildExploreTabs(
    String currentLocation,
    bool isDark,
    Color textPrimary,
  ) {
    return Row(
      key: const ValueKey('explore_tabs'),
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTabItem(
          label: 'GOALS',
          isSelected: currentLocation.startsWith('/goals'),
          onTap: () => _onTabTapped('/goals'),
          isDark: isDark,
          textPrimary: textPrimary,
        ),
        _buildTabItem(
          label: 'CATS',
          isSelected: currentLocation.startsWith('/categories'),
          onTap: () => _onTabTapped('/categories'),
          isDark: isDark,
          textPrimary: textPrimary,
        ),
        _buildTabItem(
          label: 'INSIGHTS',
          isSelected: currentLocation.startsWith('/insights'),
          onTap: () => _onTabTapped('/insights'),
          isDark: isDark,
          textPrimary: textPrimary,
        ),
      ],
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required Color textPrimary,
  }) {
    final activeColor = isDark
        ? AppColors.darkAccentPrimary
        : AppColors.lightAccentPrimary;
    final inactiveColor = isDark
        ? AppColors.darkTextSecondary
        : AppColors.lightTextSecondary;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTypography.label.copyWith(
              color: isSelected ? activeColor : inactiveColor,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}
