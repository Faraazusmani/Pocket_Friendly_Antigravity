import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_friendly/core/design_system/tokens.dart';
import 'package:pocket_friendly/core/theme/app_theme.dart';

void main() {
  group('Widget and Theme Smoke Tests', () {
    testWidgets('Theme loading and placeholder build test', (
      WidgetTester tester,
    ) async {
      // Pump a simple scaffold inside a MaterialApp loaded with our design system theme
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: Text('Foundation Active', style: TextStyle(fontSize: 24)),
            ),
          ),
        ),
      );

      // Verify that the widget is rendered with the expected text
      expect(find.text('Foundation Active'), findsOneWidget);

      // Verify that the resolved theme scaffold background color matches our OLED black design token
      final BuildContext context = tester.element(
        find.text('Foundation Active'),
      );
      final theme = Theme.of(context);
      expect(theme.scaffoldBackgroundColor, AppColors.darkBackgroundPrimary);
    });
  });
}
