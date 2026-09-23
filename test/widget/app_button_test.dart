import 'package:discipletrack/core/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('AppButton', () {
    testWidgets('shows its label and fires onPressed', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(AppButton(label: 'Sign in', onPressed: () => taps++)),
      );

      expect(find.text('Sign in'), findsOneWidget);
      await tester.tap(find.text('Sign in'));
      expect(taps, 1);
    });

    testWidgets('a null onPressed disables it', (tester) async {
      await tester.pumpWidget(
        host(const AppButton(label: 'Sign in', onPressed: null)),
      );

      await tester.tap(find.text('Sign in'));
      await tester.pump();
      // Nothing to assert beyond not throwing; the tap must be inert.
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('loading swaps the label for a spinner and blocks taps', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          AppButton(label: 'Sign in', isLoading: true, onPressed: () => taps++),
        ),
      );

      expect(find.text('Sign in'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(taps, 0, reason: 'a loading button must not re-submit');
    });

    testWidgets('loading does not change the button size', (tester) async {
      // A resize here would make the form jump mid-submit.
      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 300,
            child: AppButton(label: 'Create account', onPressed: _noop),
          ),
        ),
      );
      final idle = tester.getSize(find.byType(AppButton));

      await tester.pumpWidget(
        host(
          const SizedBox(
            width: 300,
            child: AppButton(
              label: 'Create account',
              isLoading: true,
              onPressed: _noop,
            ),
          ),
        ),
      );
      final loading = tester.getSize(find.byType(AppButton));

      expect(loading, idle);
    });

    testWidgets('meets the 44px minimum tap target', (tester) async {
      await tester.pumpWidget(
        host(const AppButton(label: 'Sign in', onPressed: _noop)),
      );
      expect(
        tester.getSize(find.byType(AppButton)).height,
        greaterThanOrEqualTo(44),
      );
    });

    testWidgets('renders each variant', (tester) async {
      for (final variant in AppButtonVariant.values) {
        await tester.pumpWidget(
          host(AppButton(label: 'Go', variant: variant, onPressed: _noop)),
        );
        expect(find.text('Go'), findsOneWidget, reason: '$variant');
      }
    });
  });
}

void _noop() {}
