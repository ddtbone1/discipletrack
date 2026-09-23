import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/step_list.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';

/// Where an authenticated user without a church membership lands.
///
/// Answers "what do I do next?" by laying out the MVP_SPEC section 11 flow,
/// Register -> Enter Join Code -> Confirm Church -> Request Membership, with
/// the person's position in it.
///
/// The join-code steps need `lookup_church_by_join_code()` and
/// `request_join_church()`, which are controlled operations arriving in a later
/// slice. The entry point is shown disabled rather than faked.
class JoinChurchPage extends ConsumerWidget {
  const JoinChurchPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider).value;
    final signingOut = ref.watch(authControllerProvider).isLoading;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppPageHeader(
            greeting: 'Hello, ${profile?.firstName ?? 'friend'}',
            subtitle: 'One step left before you begin',
            onAvatarTap: () => context.go(Routes.profile),
            actions: const [ThemeModeToggle()],
          ),
          const SizedBox(height: AppSpacing.xl),

          Text('Join your church', style: AppTypography.pageTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Your Discipleship Coordinator gives you a join code. Once they '
            'approve you, your D Group, lessons and gatherings appear here.',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.lg),

          const StepList(
            steps: [
              StepItem(
                title: 'Create your account',
                subtitle: 'Done',
                state: StepProgress.done,
              ),
              StepItem(
                title: 'Enter your join code',
                subtitle: 'Ask your Coordinator for your church code.',
                state: StepProgress.current,
                detail: _JoinCodeCard(),
              ),
              StepItem(
                title: 'Confirm your church',
                subtitle: 'Check the church name before you send a request.',
                state: StepProgress.upcoming,
              ),
              StepItem(
                title: 'Coordinator approval',
                subtitle: 'You get full access once your request is approved.',
                state: StepProgress.upcoming,
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Sign out',
            variant: AppButtonVariant.text,
            isLoading: signingOut,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// The current step's action. Disabled, with the reason stated, until the
/// join-code operations exist.
class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const fill = AppCardFill.mint;

    return AppCard(
      fill: fill,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.key_outlined, size: 20),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Joining by code is not available in this build yet.',
                  style: AppTypography.supporting.copyWith(
                    color: fill.foreground(p),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          const AppButton(
            label: 'Enter join code',
            icon: Icons.lock_outline,
            onPressed: null,
          ),
        ],
      ),
    );
  }
}
