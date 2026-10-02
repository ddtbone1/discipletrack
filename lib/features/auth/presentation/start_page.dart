import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';

/// The first screen for someone signed out: pure white in light mode, pure
/// black in dark mode, like every other page.
///
/// The illustration sits centred just above the hero line, and Sign up and
/// Log in share the bottom row, Log in in lime as the primary action.
class StartPage extends StatelessWidget {
  const StartPage({super.key});

  static const illustration = 'assets/brand/login_icon.png';

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final height = MediaQuery.sizeOf(context).height;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                // One cheap page, so the extra layout pass is fine here.
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Spacer(),
                        // Centred, a little above the hero line.
                        Center(
                          child: ExcludeSemantics(
                            child: Image.asset(
                              illustration,
                              height: height * 0.32,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.medium,
                              errorBuilder: (context, error, stack) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Semantics(
                          header: true,
                          child: Text(
                            'Your\nDiscipleship\nCompanion',
                            style: AppTypography.display.copyWith(
                              color: p.textPrimary,
                              fontSize: 46,
                              height: 1.08,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -1,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Walk with your D Group and grow in faith, one '
                          'meeting at a time.',
                          style: AppTypography.body.copyWith(
                            color: p.muted,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            Expanded(
                              child: AppButton(
                                label: 'Sign up',
                                variant: AppButtonVariant.secondary,
                                onPressed: () => context.push(Routes.signUp),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: AppButton(
                                label: 'Log in',
                                onPressed: () => context.push(Routes.signIn),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
