import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../auth/application/auth_providers.dart';
import '../../membership/application/membership_providers.dart';
import '../../membership/presentation/membership_status_pill.dart';
import '../../profile/application/profile_providers.dart';
import '../domain/onboarding_steps.dart';
import 'onboarding_timeline.dart';

/// Shown while a membership is PENDING.
///
/// Answers "where is my request?".
///
/// RBAC_RLS_MATRIX section 1a: a PENDING member may access only the minimum
/// onboarding state, which is their own pending membership row and the name
/// of the church they asked to join. No other church data, announcements,
/// curriculum or member visibility. The database enforces the rest.
///
/// Approval is noticed without a re-login: the membership is re-read every
/// [pollInterval] while this screen is open, when the app returns to the
/// foreground, and on demand with "Check status". Realtime is deliberately
/// not used; one polled screen is the smallest reliable mechanism.
class PendingApprovalPage extends ConsumerStatefulWidget {
  const PendingApprovalPage({super.key});

  static const pollInterval = Duration(seconds: 20);

  @override
  ConsumerState<PendingApprovalPage> createState() =>
      _PendingApprovalPageState();
}

class _PendingApprovalPageState extends ConsumerState<PendingApprovalPage> {
  Timer? _poll;
  bool _checking = false;
  bool _checkedNoChange = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(PendingApprovalPage.pollInterval, (_) => _refresh());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<bool> _refresh() => ref.read(myMembershipProvider.notifier).refresh();

  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _checkedNoChange = false;
    });
    final before = ref.read(myMembershipProvider).value?.status;
    final ok = await _refresh();
    if (!mounted) return;
    final after = ref.read(myMembershipProvider).value?.status;
    setState(() {
      _checking = false;
      _checkedNoChange = ok && before == after;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).value;
    final membership = ref.watch(myMembershipProvider).value;
    final church = ref.watch(myChurchProvider).value;
    final signingOut = ref.watch(authControllerProvider).isLoading;

    final steps = onboardingSteps(
      OnboardingStage.pending,
      churchName: church?.name,
    );
    final requestedAt = membership?.requestedAt;

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppPageHeader(
            greeting: 'Hello, ${profile?.firstName ?? 'friend'}',
            subtitle: 'Your request is being reviewed',
            onAvatarTap: () => context.go(Routes.profile),
            actions: const [ThemeModeToggle()],
            status: MembershipStatusPill(status: membership?.status),
          ),
          const SizedBox(height: AppSpacing.xl),

          Text('Waiting for approval', style: AppTypography.pageTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            church == null
                ? 'Your request was sent to your church.'
                : 'Your request was sent to ${church.name}.'
                      '${requestedAt == null ? '' : ' Sent ${_shortDate(requestedAt)}.'}',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.lg),

          OnboardingTimeline(steps: steps),
          const SizedBox(height: AppSpacing.xl),

          AppListRow(
            title: 'Until you are approved',
            subtitle: 'You can view and edit your profile only.',
            icon: Icons.lock_clock_outlined,
          ),
          const SizedBox(height: AppSpacing.md),

          AppButton(
            label: _checkedNoChange ? 'Still waiting' : 'Check status',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.secondary,
            isLoading: _checking,
            onPressed: _checking ? null : _checkNow,
          ),
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              'This screen updates on its own when your request is approved.',
              style: context.captionStyle,
              textAlign: TextAlign.center,
            ),
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

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _shortDate(DateTime utc) {
    final d = utc.toLocal();
    return '${_months[d.month - 1]} ${d.day}';
  }
}
