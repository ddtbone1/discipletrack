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
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../auth/application/auth_providers.dart';
import '../../platform/application/platform_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/membership_providers.dart';
import '../domain/church_membership.dart';

/// The one sentence for a church that is not ACTIVE (UI_DESIGN_SYSTEM
/// section 70). Public for tests.
String churchUnavailableMessage({
  required String churchName,
  required ChurchStatus status,
  required MembershipStatus? membership,
}) => switch ((status, membership)) {
  (ChurchStatus.archived, _) =>
    '$churchName has been closed on DiscipleTrack. Its records are kept.',
  (_, MembershipStatus.pending) =>
    "$churchName isn't available on DiscipleTrack right now. Your request "
        'to join is kept.',
  _ =>
    "$churchName isn't available on DiscipleTrack right now. Nothing has "
        'been deleted. You can still update your profile.',
};

/// Shown instead of the app to a PENDING or ACTIVE member whose church is
/// SUSPENDED or ARCHIVED (ADR-022 decision 14). No dock and nothing of the
/// church: the person's profile and account, sign out, and a way to check
/// again. A Super Admin who is also a member keeps the Platform area.
///
/// There is no Join Church: a person belongs to one church (decision 9).
class ChurchUnavailablePage extends ConsumerStatefulWidget {
  const ChurchUnavailablePage({super.key});

  @override
  ConsumerState<ChurchUnavailablePage> createState() =>
      _ChurchUnavailablePageState();
}

class _ChurchUnavailablePageState extends ConsumerState<ChurchUnavailablePage> {
  bool _checking = false;

  /// Re-reads the membership and the church; the router leaves this page by
  /// itself once the church is ACTIVE again.
  Future<void> _tryAgain() async {
    setState(() => _checking = true);
    try {
      await ref.read(myMembershipProvider.notifier).refresh();
      ref.invalidate(myChurchProvider);
      await ref.read(myChurchProvider.future);
    } on Object {
      // The page stays; the state shown is the last one known.
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).value;
    final membership = ref.watch(myMembershipProvider).value;
    final church = ref.watch(myChurchProvider).value;
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    final signingOut = ref.watch(authControllerProvider).isLoading;

    final name = church?.name ?? 'Your church';
    final status = church?.status ?? ChurchStatus.suspended;
    final title = status == ChurchStatus.archived
        ? 'This church is closed'
        : 'This church is unavailable';

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppPageHeader(
            name: profile?.fullName ?? 'Friend',
            avatar: profile?.avatarUrl,
            subtitle: name,
            onAvatarTap: () => context.push(Routes.profile),
            actions: const [ThemeModeToggle()],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(title, style: AppTypography.pageTitle),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            fill: AppCardFill.pastel,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 22),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    churchUnavailableMessage(
                      churchName: name,
                      status: status,
                      membership: membership?.status,
                    ),
                    style: AppTypography.body.copyWith(
                      color: AppCardFill.pastel.foreground(context.palette),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Profile',
            icon: Icons.person_outline_rounded,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push(Routes.profile),
          ),
          if (isSuperAdmin) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Platform',
              icon: Icons.apartment_rounded,
              variant: AppButtonVariant.secondary,
              onPressed: () => context.push(Routes.platform),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Try again',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.secondary,
            isLoading: _checking,
            onPressed: _tryAgain,
          ),
          const SizedBox(height: AppSpacing.lg),
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
