import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';

/// The page shell every DiscipleTrack screen uses.
///
/// Applies the standard outer page padding (UI_DESIGN_SYSTEM section 9) and
/// keeps content clear of notches and the keyboard, so no screen re-invents
/// its own padding.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.child,
    this.title,
    this.actions,
    this.showBackButton = false,
    this.scrollable = true,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
    super.key,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;
  final bool showBackButton;

  /// Most pages scroll. Pass false for a page that manages its own scrolling.
  final bool scrollable;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);

    return Scaffold(
      appBar: title == null && !showBackButton
          ? null
          : AppBar(
              title: title == null ? null : Text(title!),
              automaticallyImplyLeading: showBackButton,
              actions: actions,
            ),
      // A plain scroll view. Deliberately no IntrinsicHeight.
      //
      // IntrinsicHeight was used here to let pages push content down with
      // Spacer inside a scroll view. It works, but it forces an extra layout
      // pass over the whole subtree, and over nested Rows of Expanded cards
      // that cost grew until frames took seconds and the page rendered blank.
      //
      // Pages must therefore not use Spacer or Expanded directly under this
      // scaffold when scrollable is true. To anchor content to the bottom,
      // pass scrollable: false and build a Column with an Expanded scroll
      // region, which costs one layout pass instead of two.
      body: SafeArea(
        child: scrollable
            ? SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: body,
              )
            : body,
      ),
    );
  }
}
