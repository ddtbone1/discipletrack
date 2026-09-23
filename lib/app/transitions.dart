import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The single page transition in DiscipleTrack.
///
/// Every route uses it, so navigation feels the same everywhere. A short fade
/// communicates the change without delaying the action, per UI_DESIGN_SYSTEM
/// section 53 (motion must never delay important actions).
///
/// Elaborate transitions are deliberately out of scope for this milestone.
CustomTransitionPage<T> buildPage<T>({
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        // A small rise, not a slide. Enough to read as "a new page arrived"
        // without the motion becoming the point.
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.015),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
