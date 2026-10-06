import 'package:discipletrack/core/connectivity/connection_status.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/core/widgets/app_button.dart';
import 'package:discipletrack/core/widgets/app_text_link.dart';
import 'package:discipletrack/core/widgets/confirm_dialog.dart';
import 'package:discipletrack/core/widgets/empty_state.dart';
import 'package:discipletrack/core/widgets/error_state.dart';
import 'package:discipletrack/core/widgets/illustration.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _NetworkFailure implements NetworkAwareFailure {
  @override
  bool get isNetwork => true;
}

Widget _host(Widget child, {bool offline = false}) => MaterialApp(
  theme: AppTheme.light(),
  home: ConnectionScope(
    offline: offline,
    onRetry: () {},
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

void main() {
  group('ErrorState.load', () {
    testWidgets('names what failed and never shows the exception text', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(
        _host(
          ErrorState.load(
            subject: 'your D Group',
            error: Exception('PostgrestException: relation does not exist'),
            onRetry: () => retries++,
          ),
        ),
      );

      expect(find.text("Couldn't load your D Group"), findsOneWidget);
      expect(
        find.text(
          "We couldn't load your D Group. Check your connection and try again.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Postgrest'), findsNothing);
      expect(find.textContaining('Exception'), findsNothing);

      await tester.tap(find.text('Try again'));
      expect(retries, 1);
    });

    testWidgets('a network failure uses the offline wording', (tester) async {
      await tester.pumpWidget(
        _host(
          ErrorState.load(subject: 'your D Group', error: _NetworkFailure()),
        ),
      );

      expect(find.text("You're offline"), findsOneWidget);
      expect(
        find.text('Your D Group needs a connection. Connect and try again.'),
        findsOneWidget,
      );
    });
  });

  group('EmptyState', () {
    testWidgets('shows its title, message and action', (tester) async {
      await tester.pumpWidget(
        _host(
          EmptyState(
            title: 'No pending requests',
            message: 'Requests appear here.',
            action: TextButton(onPressed: () {}, child: const Text('Refresh')),
          ),
        ),
      );
      expect(find.text('No pending requests'), findsOneWidget);
      expect(find.text('Requests appear here.'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
    });

    testWidgets(
      'restricted explains, with its illustration and a default title',
      (tester) async {
        await tester.pumpWidget(
          _host(const EmptyState.restricted(message: 'For the Coordinator.')),
        );
        expect(find.text("This isn't available to you"), findsOneWidget);
        expect(find.text('For the Coordinator.'), findsOneWidget);
        expect(find.byType(IllustrationView), findsOneWidget);
      },
    );
  });

  group('showConfirmDialog', () {
    final results = <bool>[];

    Future<void> open(WidgetTester tester) async {
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Remove Ana?'), findsOneWidget);
      expect(find.text('Ana leaves this D Group.'), findsOneWidget);
    }

    Future<void> pump(WidgetTester tester) async {
      results.clear();
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => results.add(
                await showConfirmDialog(
                  context,
                  title: 'Remove Ana?',
                  message: 'Ana leaves this D Group.',
                  confirmLabel: 'Remove',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
    }

    testWidgets('resolves true only on the confirm label', (tester) async {
      await pump(tester);
      await open(tester);
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      await open(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(results, [true, false]);
    });

    testWidgets('dismissing counts as cancel', (tester) async {
      await pump(tester);
      await open(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('Remove Ana?'), findsNothing);
      expect(results, [false]);
    });
  });

  group('offline actions', () {
    testWidgets('a blocked button does not act, and a tap explains why', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Record meeting',
            requiresConnection: true,
            offlineAction: 'record this meeting',
            onPressed: () => taps++,
          ),
          offline: true,
        ),
      );
      await tester.tap(find.text('Record meeting'));
      await tester.pump();

      expect(taps, 0);
      expect(
        find.text("You're offline. Connect to record this meeting."),
        findsOneWidget,
      );
    });

    testWidgets('without an action, the generic sentence is used', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          AppTextLink(label: 'Invite', requiresConnection: true, onTap: () {}),
          offline: true,
        ),
      );
      await tester.tap(find.text('Invite'));
      await tester.pump();
      expect(
        find.text("You're offline. Connect to make changes."),
        findsOneWidget,
      );
    });

    testWidgets('online, the button acts and nothing is explained', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _host(
          AppButton(
            label: 'Record meeting',
            requiresConnection: true,
            onPressed: () => taps++,
          ),
        ),
      );
      await tester.tap(find.text('Record meeting'));
      await tester.pump();
      expect(taps, 1);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
