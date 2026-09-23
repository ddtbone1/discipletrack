import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../application/membership_review_providers.dart';
import '../domain/membership_request.dart';

/// Membership requests awaiting review, for Admins and Coordinators.
///
/// The minimum needed to complete the onboarding workflow: who asked, when,
/// Approve, Decline. Not a member-management console. Authority is decided by
/// the database on every call; this screen only reflects it.
class PendingMembersPage extends ConsumerWidget {
  const PendingMembersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requests = ref.watch(pendingMembershipRequestsProvider);
    final review = ref.watch(membershipReviewControllerProvider);

    return AppScaffold(
      title: 'Membership requests',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          if (review.error != null) ...[
            InlineError(message: review.error!.message),
            const SizedBox(height: AppSpacing.md),
          ],
          requests.when(
            loading: () => const SizedBox(height: 320, child: LoadingState()),
            error: (e, _) => SizedBox(
              height: 320,
              child: ErrorState(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(pendingMembershipRequestsProvider),
              ),
            ),
            data: (items) => items.isEmpty
                ? const _EmptyRequests()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        '${items.length} ${items.length == 1 ? 'person is' : 'people are'} '
                        'waiting to join.',
                        style: context.supportingStyle,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      for (final request in items) ...[
                        _RequestCard(
                          request: request,
                          busy: review.inFlightId == request.membershipId,
                          anyBusy: review.isBusy,
                        ),
                        const SizedBox(height: AppSpacing.cardGap),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      fill: AppCardFill.pastel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.inbox_outlined, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'No pending requests',
                style: AppTypography.sectionTitle.copyWith(
                  color: AppCardFill.pastel.foreground(p),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'When someone enters your church join code and asks to join, '
            'their request appears here.',
            style: AppTypography.body.copyWith(
              color: AppCardFill.pastel.foregroundMuted(p),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  const _RequestCard({
    required this.request,
    required this.busy,
    required this.anyBusy,
  });

  final MembershipRequest request;

  /// This row's own action is in flight.
  final bool busy;

  /// Some row's action is in flight; other rows wait.
  final bool anyBusy;

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    // UI_DESIGN_SYSTEM section 45: a destructive action confirms first.
    // Rejection archives the request and only the church can reinstate it.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Decline this request?'),
        content: Text(
          '${request.fullName} will not be able to request again from the '
          'app. Only your church can reopen a declined request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep request'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(membershipReviewControllerProvider.notifier)
          .reject(request.membershipId);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final controller = ref.read(membershipReviewControllerProvider.notifier);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.fullName, style: AppTypography.sectionTitle),
          const SizedBox(height: 2),
          Text(
            'Requested to join ${_longDate(request.requestedAt)}',
            style: AppTypography.supporting.copyWith(color: p.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  icon: Icons.check_rounded,
                  isLoading: busy,
                  onPressed: anyBusy
                      ? null
                      : () => controller.approve(request.membershipId),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Decline',
                  variant: AppButtonVariant.secondary,
                  onPressed: anyBusy ? null : () => _decline(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
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

  static String _longDate(DateTime utc) {
    final d = utc.toLocal();
    return '${_months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
