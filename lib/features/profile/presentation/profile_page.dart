import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/info_group.dart';
import '../../../core/widgets/loading_state.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership/presentation/membership_status_pill.dart';
import '../application/profile_providers.dart';
import '../domain/profile.dart';

/// The signed-in user's own profile.
///
/// MVP_SPEC section 28 describes a richer profile carrying D Group, Discipler,
/// attendance and progress. Those appear as each feature lands and its read
/// authorization exists. Nothing is shown that RLS does not already permit.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return AppScaffold(
      title: 'My profile',
      showBackButton: true,
      actions: const [
        ThemeModeToggle(size: 40),
        SizedBox(width: AppSpacing.page),
      ],
      child: profileAsync.when(
        loading: () => const SizedBox(height: 400, child: LoadingState()),
        error: (e, _) => SizedBox(
          height: 400,
          child: ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(myProfileProvider),
          ),
        ),
        data: (profile) => profile == null
            ? const SizedBox(
                height: 400,
                child: ErrorState(
                  title: 'Profile unavailable',
                  message: 'We could not find your profile.',
                ),
              )
            : _ProfileBody(profile: profile),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(myMembershipProvider).value;
    final joinedAt = membership?.joinedAt;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),

        // Identity, directly on the page background.
        const Center(child: AppAvatar(size: 84)),
        const SizedBox(height: AppSpacing.sm),
        Text(
          profile.fullName,
          style: AppTypography.pageTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(child: MembershipStatusPill(status: membership?.status)),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: AppButton(
            label: 'Edit profile',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.secondary,
            expand: false,
            onPressed: () => context.go(Routes.editProfile),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        InfoGroup(
          title: 'Contact',
          rows: [
            InfoRow(label: 'Full name', value: profile.fullName),
            InfoRow(label: 'Phone', value: profile.phone ?? 'Not added'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        InfoGroup(
          title: 'Membership',
          rows: [
            InfoRow(
              label: 'Status',
              value: membershipStatusLabel(membership?.status),
            ),
            // church_memberships.joined_at, not the account creation date.
            if (joinedAt != null)
              InfoRow(label: 'Joined church', value: _longDate(joinedAt)),
            InfoRow(
              label: 'Account created',
              value: _longDate(profile.createdAt),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Database timestamps parse as UTC; show the person's local calendar day.
  static String _longDate(DateTime utc) {
    final d = utc.toLocal();
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
