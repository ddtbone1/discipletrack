import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/connectivity/connection_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/offline_banner.dart';

/// The full-screen, centred page the login and sign-up forms live in: the
/// logo, a title, then the form, centred vertically when it fits and
/// scrolling when it does not (a small phone, or the keyboard open).
///
/// Back returns to the welcome page.
class AuthFormLayout extends StatelessWidget {
  const AuthFormLayout({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  /// Keeps the form a comfortable width on tablets and wide windows.
  static const maxWidth = 440.0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.start),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (ConnectionScope.isOffline(context))
              OfflineBanner(onRetry: ConnectionScope.retryOf(context)),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: maxWidth),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // The bare lime mark, no tile.
                            Center(
                              child: Semantics(
                                label: 'DiscipleTrack',
                                child: const SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: BrandLogo(),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                textAlign: TextAlign.center,
                                style: AppTypography.display.copyWith(
                                  color: p.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                subtitle!,
                                textAlign: TextAlign.center,
                                style: context.supportingStyle,
                              ),
                            ],
                            const SizedBox(height: AppSpacing.xl),
                            child,
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
