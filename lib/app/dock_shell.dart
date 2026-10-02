import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/floating_dock.dart';
import '../features/membership/application/membership_providers.dart';
import '../features/ministry/application/ministry_providers.dart';
import '../features/ministry/domain/ministry_context.dart';
import '../features/session/application/session_state.dart';
import 'routes.dart';

/// The dock's destinations for this person (UI_DESIGN_SYSTEM section 22).
///
/// Only screens that exist are offered, so nobody sees a destination they
/// cannot use. Showing a destination is presentation; the database still
/// decides what each screen returns.
List<DockItem> dockItemsFor({
  required bool isCoordinator,
  required bool canReview,
  required MinistryContext? ministry,
}) => [
  const DockItem(
    label: 'Home',
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    path: Routes.home,
  ),
  if (isCoordinator)
    const DockItem(
      label: 'D Groups',
      icon: Icons.groups_2_outlined,
      activeIcon: Icons.groups_2_rounded,
      path: Routes.dGroups,
    )
  else if (ministry != null)
    DockItem(
      label: 'My Group',
      icon: Icons.diversity_3_outlined,
      activeIcon: Icons.diversity_3_rounded,
      path: ministry.isLeader
          ? Routes.dGroupDetailFor(ministry.dGroupId)
          : Routes.myGroup,
    ),
  if (canReview)
    const DockItem(
      label: 'Requests',
      icon: Icons.how_to_reg_outlined,
      activeIcon: Icons.how_to_reg_rounded,
      path: Routes.pendingMembers,
    ),
  const DockItem(
    label: 'Profile',
    icon: Icons.person_outline_rounded,
    activeIcon: Icons.person_rounded,
    path: Routes.profile,
  ),
];

/// The item whose path is the longest prefix of [location], or -1.
int activeDockIndex(List<DockItem> items, String location) {
  var best = -1;
  var bestLength = -1;
  for (var i = 0; i < items.length; i++) {
    final path = items[i].path;
    final matches = location == path || location.startsWith('$path/');
    if (matches && path.length > bestLength) {
      best = i;
      bestLength = path.length;
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
      canReview: ref.watch(canReviewMembershipsProvider),
      ministry: ref.watch(myMinistryContextProvider).value,
    );
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final footprint = keyboardOpen
        ? 0.0
        : FloatingDock.height + FloatingDock.gap * 2;

    return DockScope(
      child: Stack(
        children: [
          MediaQuery(
            data: media.copyWith(
              padding: media.padding.copyWith(
                bottom: media.padding.bottom + footprint,
              ),
            ),
            child: child,
          ),
          if (!keyboardOpen)
            Positioned(
              left: 16,
              right: 16,
              bottom: media.padding.bottom + FloatingDock.gap,
              child: FloatingDock(
                items: items,
                activeIndex: activeDockIndex(items, location),
                onSelected: (i) => context.go(items[i].path),
              ),
            ),
        ],
      ),
    );
  }
}
