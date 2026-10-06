import 'package:discipletrack/app/dock_shell.dart';
import 'package:discipletrack/app/routes.dart';
import 'package:discipletrack/core/theme/app_theme.dart';
import 'package:discipletrack/core/widgets/app_scaffold.dart';
import 'package:discipletrack/core/widgets/floating_dock.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MinistryContext _context(DGroupResponsibility r) => MinistryContext(
  dGroupId: 'g1',
  dGroupName: 'Young Adults A',
  roster: [
    RosterEntry(
      dGroupMembershipId: 'dgm1',
      churchMembershipId: 'cm1',
      fullName: 'Me',
      responsibility: r,
      isMe: true,
    ),
  ],
);

List<String> _labels(List<DockItem> items) => [for (final i in items) i.label];

void main() {
  group('dockItemsFor', () {
    test('an unplaced member gets Home and Profile only', () {
      final items = dockItemsFor(isCoordinator: false, ministry: null);
      expect(_labels(items), ['Home', 'Profile']);
    });

    test('the Coordinator gets D Groups; Requests is not in the dock', () {
      final items = dockItemsFor(isCoordinator: true, ministry: null);
      expect(_labels(items), ['Home', 'D Groups', 'Profile']);
      expect(items[1].path, Routes.dGroups);
    });

    test('everyone\'s group goes to the roster; for a Leader the management '
        'page keeps D Group active (ADR-020)', () {
      final leader = dockItemsFor(
        isCoordinator: false,
        ministry: _context(DGroupResponsibility.leader),
      );
      expect(_labels(leader), ['Home', 'D Group', 'Profile']);
      expect(leader[1].path, Routes.myGroup);
      expect(activeDockIndex(leader, Routes.dGroupDetailFor('g1')), 1);

      final disciple = dockItemsFor(
        isCoordinator: false,
        ministry: _context(DGroupResponsibility.disciple),
      );
      expect(disciple[2].path, Routes.myGroup);
    });

    test('Journey is offered to a Disciple and to a Discipler, from the '
        'relationship, never to a Leader who holds neither', () {
      for (final r in [
        DGroupResponsibility.disciple,
        DGroupResponsibility.discipler,
      ]) {
        final items = dockItemsFor(isCoordinator: false, ministry: _context(r));
        expect(_labels(items), ['Home', 'Journey', 'D Group', 'Profile']);
        expect(items[1].path, Routes.journey);
      }
      final leader = dockItemsFor(
        isCoordinator: false,
        ministry: _context(DGroupResponsibility.leader),
      );
      expect(_labels(leader), isNot(contains('Journey')));
    });

    test('a Coordinator who also disciples gets Journey, and the dock never '
        'exceeds five items', () {
      final items = dockItemsFor(
        isCoordinator: true,
        ministry: _context(DGroupResponsibility.discipler),
      );
      expect(_labels(items), ['Home', 'Journey', 'D Groups', 'Profile']);
      expect(items.length, lessThanOrEqualTo(5));
    });

    test('an Admin who is not Coordinator and not placed gets Home and '
        'Profile', () {
      final items = dockItemsFor(isCoordinator: false, ministry: null);
      expect(_labels(items), ['Home', 'Profile']);
    });
  });

  group('activeDockIndex', () {
    final items = dockItemsFor(isCoordinator: true, ministry: null);

    test('matches the destination and the pages under it', () {
      expect(activeDockIndex(items, Routes.home), 0);
      expect(activeDockIndex(items, Routes.dGroups), 1);
      expect(activeDockIndex(items, '/groups/g1/invite'), 1);
      expect(activeDockIndex(items, Routes.editProfile), 2);
    });

    test('a path that only shares a prefix does not match', () {
      expect(activeDockIndex(items, '/homepage'), -1);
    });
  });

  group('AppScaffold back button', () {
    Widget host(Widget child) =>
        MaterialApp(theme: AppTheme.light(), home: child);

    testWidgets('inside the dock, a top-level page has no back button', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const DockScope(
            child: AppScaffold(
              title: 'D Groups',
              showBackButton: true,
              child: SizedBox(),
            ),
          ),
        ),
      );
      expect(find.byType(BackButton), findsNothing);
    });

    testWidgets('a page navigated to always has a back button that pops', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          DockScope(
            child: Builder(
              builder: (context) => AppScaffold(
                title: 'Home',
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          const AppScaffold(title: 'Detail', child: SizedBox()),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Detail'), findsNothing);
    });

    testWidgets('outside the dock, showBackButton always offers back', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const AppScaffold(
            title: 'My profile',
            showBackButton: true,
            child: SizedBox(),
          ),
        ),
      );
      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  testWidgets('the dock renders and slides without a Scaffold above it, as '
      'in the app', (tester) async {
    final items = dockItemsFor(isCoordinator: true, ministry: null);
    Widget dock(int active) => MaterialApp(
      theme: AppTheme.light(),
      home: Align(
        alignment: Alignment.bottomCenter,
        child: FloatingDock(
          items: items,
          activeIndex: active,
          onSelected: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(dock(0));
    expect(tester.takeException(), isNull);

    // Only the active destination shows its name, in the white pill.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('D Groups'), findsNothing);

    final widthBefore = tester.getSize(find.byType(FloatingDock)).width;

    await tester.pumpWidget(dock(1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull, reason: 'mid-slide');
    // The width is fixed: switching moves the pill, never the dock's edges.
    expect(tester.getSize(find.byType(FloatingDock)).width, widthBefore);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('D Groups'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
    expect(tester.getSize(find.byType(FloatingDock)).width, widthBefore);
  });

  testWidgets('the dock marks the active destination', (tester) async {
    final items = dockItemsFor(isCoordinator: true, ministry: null);
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: FloatingDock(items: items, activeIndex: 1, onSelected: (_) {}),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('D Groups')),
      matchesSemantics(
        label: 'D Groups',
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
      ),
    );
    handle.dispose();
  });
}
