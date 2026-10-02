import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../connectivity/connection_status.dart';
import '../theme/app_spacing.dart';
import 'offline_banner.dart';
import 'floating_dock.dart';

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
    this.backFallback = '/home',
    this.scrollable = true,
    this.padding = const EdgeInsets.symmetric(horizontal: AppSpacing.page),
    super.key,
  });

  final Widget child;
  final String? title;
  final List<Widget>? actions;

  /// Outside the dock shell, always offer a back button, even when the page
  /// was opened with `go` and there is nothing to pop.
  ///
  /// Inside the dock shell this is ignored: a back button appears exactly
  /// when the page was navigated to (there is something to pop), and the
  /// dock is the way out of a top-level destination.
  final bool showBackButton;

  /// Where back goes when there is nothing to pop. The router redirects
  /// `/home` to whatever the current session state allows, so it is a safe
  /// default in every state.
  final String backFallback;

  /// Most pages scroll. Pass false for a page that manages its own scrolling.
  final bool scrollable;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final showBack = canPop || (showBackButton && !DockScope.of(context));

    return Scaffold(
      appBar: title == null && !showBack
          ? null
          : AppBar(
              title: title == null ? null : Text(title!),
              automaticallyImplyLeading: false,
              leading: showBack
                  ? BackButton(
                      onPressed: () => canPop
                          ? Navigator.of(context).pop()
                          : context.go(backFallback),
                    )
                  : null,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Every page says when it is showing saved data.
            if (ConnectionScope.isOffline(context))
              OfflineBanner(onRetry: ConnectionScope.retryOf(context)),
            Expanded(
              child: scrollable
                  ? SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: body,
                    )
                  : body,
            ),
          ],
        ),
      ),
    );
  }
}
