import '../../../core/supabase/supabase_providers.dart';
import 'avatar_picker.dart';
import '../../ministry/presentation/ministry_ui.dart';
import '../../ministry/domain/d_group_member.dart';
import '../../ministry/application/ministry_providers.dart';
import '../../discipleship/application/discipleship_providers.dart';
import '../../appearance/application/theme_mode_provider.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/theme/app_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../application/profile_providers.dart';
import '../domain/profile.dart';
import 'ministry_summary.dart';

/// The signed-in user's own profile.
///
/// The avatar to change, then three cards (user, 2026-10-07): personal
/// info, ministry, and account (password, sign-in email, appearance).
/// Nothing is shown that the database does not already permit the person
/// to read.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);

    return AppScaffold(
      title: 'Profile',
      showBackButton: true,
      child: profileAsync.when(
        loading: () => const SizedBox(height: 400, child: LoadingState()),
        error: (e, _) => SizedBox(
          height: 400,
          child: ErrorState.load(
            subject: 'your profile',
            error: e,
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
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final membership = ref.watch(myMembershipProvider).value;
    final church = ref.watch(myChurchProvider).value;
    final ministry = ref.watch(myMinistryContextProvider).value;
    final journey = ref.watch(myJourneyProvider).value;
    final email = ref.watch(currentUserEmailProvider);
    final dark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final since = membership?.joinedAt ?? profile.createdAt;

    final roles = [
      for (final r in DGroupResponsibility.values)
        if (ministry?.myResponsibilities.contains(r) ?? false) r,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        // Who they are: the avatar to change, the name, the church, roles.
        Center(
          child: _EditableAvatar(
            preset: profile.avatarUrl,
            onTap: () => showAvatarPicker(context, current: profile.avatarUrl),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          profile.fullName,
          textAlign: TextAlign.center,
          style: AppTypography.pageTitle,
        ),
        if (church != null)
          Text(
            church.name,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        if (roles.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                for (final (i, r) in roles.indexed) ...[
                  if (i > 0) const TextSpan(text: '  ·  '),
                  TextSpan(
                    text: r.label,
                    style: TextStyle(
                      color: pillColors(context, roleTone(r)).$2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),

        _ProfileCard(
          title: 'Personal info',
          action: AppTextLink(
            label: 'Edit',
            onTap: () => context.push(Routes.editProfile),
          ),
          rows: [
            _ProfileRow(
              icon: Icons.person_outline_rounded,
              label: 'Name',
              value: profile.fullName,
            ),
            _ProfileRow(
              icon: Icons.mail_outline_rounded,
              label: 'Email',
              value: email ?? '',
            ),
            _ProfileRow(
              icon: Icons.call_outlined,
              label: 'Phone',
              value: profile.phone ?? 'Not added',
            ),
          ],
        ),
        if (ministry != null) ...[
          const SizedBox(height: AppSpacing.md),
          _ProfileCard(
            title: 'Ministry',
            rows: [
              _ProfileRow(
                icon: Icons.groups_outlined,
                label: 'D Group',
                value: ministry.dGroupName,
                onTap: () => context.go(Routes.myGroup),
              ),
              if (ministry.leader != null && !ministry.isLeader)
                _ProfileRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Leader',
                  value: ministry.leader!.fullName,
                ),
              if (ministry.isDisciple)
                _ProfileRow(
                  icon: Icons.person_pin_outlined,
                  label: 'Discipler',
                  value: ministry.myDiscipler?.fullName ?? 'Not paired yet',
                ),
              if (ministry.isDisciple && journey != null)
                _ProfileRow(
                  icon: Icons.menu_book_outlined,
                  label: 'Journey',
                  value:
                      '${journey.lessonsCompleted} of ${journey.lessonsTotal} '
                      'lessons completed',
                  onTap: () => context.go(Routes.journey),
                ),
              if (ministry.isDiscipler)
                _ProfileRow(
                  icon: Icons.people_alt_outlined,
                  label: 'Disciples',
                  value: discipleNames([
                    for (final d in ministry.myDisciples) d.fullName,
                  ]),
                  onTap: ministry.myDisciples.isEmpty
                      ? null
                      : () => context.go(Routes.journeyDisciples),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _ProfileCard(
          title: 'Account',
          rows: [
            _ProfileRow(
              icon: Icons.lock_outline_rounded,
              label: 'Password',
              value: 'Change password',
              onTap: () => context.push(Routes.changePassword),
            ),
            _ProfileRow(
              icon: Icons.dark_mode_outlined,
              label: 'Appearance',
              value: dark ? 'Dark' : 'Light',
              trailing: Switch(
                value: dark,
                onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),
            _ProfileRow(
              icon: Icons.event_outlined,
              label: 'Member since',
              value: _longDate(since),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: TextButton.icon(
            onPressed: ref.watch(authControllerProvider).isLoading
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: Icon(Icons.logout_rounded, color: p.error),
            label: Text(
              'Sign out',
              style: TextStyle(color: p.error, fontWeight: FontWeight.w700),
            ),
          ),
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

/// The avatar, large, ringed in lime, with a pencil badge that says it can
/// be changed.
class _EditableAvatar extends StatelessWidget {
  const _EditableAvatar({required this.preset, required this.onTap});

  final String? preset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Change avatar',
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 104,
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: p.brand, width: 2.5),
                ),
                child: AppAvatar(size: 92, preset: preset),
              ),
              Positioned(
                right: 0,
                bottom: 2,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.border),
                  ),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white card with a title (and an action on the right), its rows below.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.title, required this.rows, this.action});

  final String title;
  final List<_ProfileRow> rows;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              ?action,
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ...rows,
        ],
      ),
    );
  }
}

/// One line of a card: an icon, a small grey label over the value, and a
/// chevron or control on the right.
class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: p.textPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: text.labelSmall?.copyWith(color: p.muted)),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: text.bodyMedium?.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      child: onTap == null
          ? row
          : InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: row,
            ),
    );
  }
}
