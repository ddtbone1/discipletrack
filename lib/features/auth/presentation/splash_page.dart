import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/error_state.dart';
import '../../membership/application/membership_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/auth_providers.dart';

/// Shown while the session, profile and membership resolve.
///
/// The router sends [SessionState.unknown] here and never to sign-in, which is
/// what stops a signed-in person seeing the login screen for a frame on launch.
///
/// If the profile or membership cannot be loaded, the spinner gives way to a
/// retry. Without this the person would be stuck on a spinner with no way
/// out, since the router holds an unresolved session on this screen.
class SplashPage extends ConsumerWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final profile = ref.watch(myProfileProvider);
    final membership = ref.watch(myMembershipProvider);
    final failed = profile.hasError || membership.hasError;

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: failed
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ErrorState(
                    title: 'Could not load your account',
                    message:
                        'DiscipleTrack could not reach the server. Check your '
                        'connection and try again.',
                    onRetry: () {
                      ref.invalidate(myProfileProvider);
                      ref.invalidate(myMembershipProvider);
                    },
                  ),
                  AppButton(
                    label: 'Sign out',
                    variant: AppButtonVariant.text,
                    expand: false,
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 64, showWordmark: false),
                  const SizedBox(height: AppSpacing.md),
                  Text('DiscipleTrack', style: AppTypography.pageTitle),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
