import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/error_state.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership/data/membership_repository.dart';
import '../../profile/application/profile_providers.dart';
import '../application/first_entry_controller.dart';

/// The one-time first-entry welcome, shown when a membership is ACTIVE and
/// `onboarding_completed_at` is still null.
///
/// Distinct from the splash: the splash appears on every launch while the
/// session resolves; this appears once per church membership, after approval.
/// "Continue" records completion on the server through
/// `complete_onboarding()`, so a reinstall or another device never shows it
/// again. The router keeps the person here until that succeeds.
///
/// Motion is a plain fade for now; the eventual welcome animation is a later
/// refinement (UI_DESIGN_SYSTEM section 53: motion must never delay the
/// action, so the button is usable immediately).
class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  Future<void> _continue() =>
      ref.read(firstEntryControllerProvider.notifier).complete();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = ref.watch(myProfileProvider).value;
    final church = ref.watch(myChurchProvider).value;
    final entry = ref.watch(firstEntryControllerProvider);
    final failure = entry.error;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
          child: Column(
            children: [
              Expanded(
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: _fade,
                    curve: Curves.easeOutCubic,
                  ),
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.xxl),
                        const BrandMark(size: 72, showWordmark: false),
                        const SizedBox(height: AppSpacing.lg),
                        Text('DiscipleTrack', style: AppTypography.pageTitle),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          profile == null
                              ? 'Welcome to the journey.'
                              : 'Welcome to the journey, ${profile.firstName}.',
                          style: AppTypography.display,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          church == null
                              ? 'Your membership has been approved.'
                              : 'Your membership at ${church.name} has been '
                                    'approved.',
                          style: context.supportingStyle,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Text(
                          'Grow. Connect. Disciple.',
                          style: AppTypography.sectionTitle.copyWith(
                            color: p.muted,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                      ],
                    ),
                  ),
                ),
              ),
              if (failure != null) ...[
                InlineError(
                  message: failure is MembershipFailure
                      ? failure.message
                      : 'Something went wrong. Please try again.',
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                isLoading: entry.isLoading,
                onPressed: entry.isLoading ? null : _continue,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
