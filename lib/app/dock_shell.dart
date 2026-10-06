import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/floating_dock.dart';
import '../features/discipleship/domain/journey_views.dart';
import '../features/ministry/application/ministry_providers.dart';
import '../features/ministry/domain/ministry_context.dart';
import '../features/session/application/session_state.dart';
import 'routes.dart';

/// The dock's destinations for this person (UI_DESIGN_SYSTEM section 22).
///
/// Only screens that exist are offered, so nobody sees a destination they
/// cannot use. Showing a destination is presentation; the database still
/// decides what each screen returns. Membership requests are reached from
/// the Home tile, not the dock. Never more than five items: Home, Journey,
/// D Group or D Groups, Profile.
List<DockItem> dockItemsFor({
  required bool isCoordinator,
  required MinistryContext? ministry,
}) => [
  const DockItem(
    label: 'Home',
    icon: CupertinoIcons.house,
    activeIcon: CupertinoIcons.house,
    glyph: _house,
    path: Routes.home,
  ),
  // Journey (N8): offered from relationships, never from a role. Every
  // Leader disciples (ADR-020), so every Leader has it; a Coordinator gets
  // it when they also disciple or are a Disciple. Lessons are read from
  // the journey, so the lesson pages keep it active.
  if (JourneyViews.of(ministry).isOffered)
    const DockItem(
      label: 'Journey',
      icon: CupertinoIcons.book,
      activeIcon: CupertinoIcons.book_fill,
      path: Routes.journey,
      alsoActiveOn: [Routes.lessons, Routes.myDisciples],
    ),
  if (isCoordinator)
    const DockItem(
      label: 'D Groups',
      icon: CupertinoIcons.person_2,
      activeIcon: CupertinoIcons.person_2_fill,
      path: Routes.dGroups,
    )
  else if (ministry != null)
    DockItem(
      label: 'D Group',
      icon: CupertinoIcons.person_2,
      activeIcon: CupertinoIcons.person_2_fill,
      // One roster for everyone (ADR-020); the Leader manages the group
      // from there, on a page that keeps this item active.
      path: Routes.myGroup,
      alsoActiveOn: [if (ministry.isLeader) Routes.dGroups],
    ),
  const DockItem(
    label: 'Profile',
    icon: CupertinoIcons.person_crop_circle,
    activeIcon: CupertinoIcons.person_crop_circle_fill,
    path: Routes.profile,
  ),
];

Widget _house(Color color, double size, bool active) =>
    HouseOutline(color: color, size: size, filled: active);

/// The item whose path is the longest prefix of [location], or -1.
int activeDockIndex(List<DockItem> items, String location) {
  var best = -1;
  var bestLength = -1;
  for (var i = 0; i < items.length; i++) {
    for (final path in [items[i].path, ...items[i].alsoActiveOn]) {
      final matches = location == path || location.startsWith('$path/');
      if (matches && path.length > bestLength) {
        best = i;
        bestLength = path.length;
      }
    }
  }
  return best;
}

/// Wraps every screen of an ACTIVE member with the floating dock.
///
/// The child is given extra bottom padding equal to the dock's footprint, so
/// [AppScaffold]'s SafeArea keeps content clear of it. While the keyboard is
/// open the dock steps aside, so forms keep the whole screen.
class DockShell extends ConsumerWidget {
  const DockShell({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(sessionStateProvider) != SessionState.active) return child;

    final items = dockItemsFor(
      isCoordinator: ref.watch(isCoordinatorProvider),
      ministry: ref.watch(myMinistryContextProvider).value,
    );
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final footprint = keyboardOpen
        ? 0.0
        : FloatingDock.height + FloatingDock.gap * 2;

    final theme = Theme.of(context);

    return DockScope(
      child: Stack(
        children: [
          MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom: media.padding.bottom + footprint,
              ),
            ),
            // Floating snackbars sit above the dock rather than under it.
            child: Theme(
              data: theme.copyWith(
                snackBarTheme: theme.snackBarTheme.copyWith(
                  insetPadding: EdgeInsets.fromLTRB(16, 5, 16, footprint + 10),
                ),
              ),
              child: child,
            ),
          ),
          if (!keyboardOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: media.padding.bottom + FloatingDock.gap,
              // Only as wide as its contents, centred.
              child: Center(
                child: FloatingDock(
                  items: items,
                  activeIndex: activeDockIndex(items, location),
                  onSelected: (i) => context.go(items[i].path),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
