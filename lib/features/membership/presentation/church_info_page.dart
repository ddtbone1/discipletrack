import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_format.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../ministry/application/ministry_providers.dart';
import '../application/membership_providers.dart';
import '../data/membership_repository.dart';
import '../domain/church_membership.dart';
import 'join_code_card.dart';

/// The church's join code for its Coordinator (ADR-022 decision 10a,
/// UI_DESIGN_SYSTEM section 70): read-only, with Copy. Only the platform
/// administrator generates or changes the code.
///
/// Whether the code is shown is the database's answer: anyone else who
/// reaches this page sees the restricted state, never the code.
final churchJoinCodeProvider = FutureProvider.autoDispose<ChurchJoinCode?>((
  ref,
) async {
  final church = ref.watch(myChurchProvider).value;
  if (church == null || !ref.watch(isCoordinatorProvider)) return null;
  return ref.watch(membershipRepositoryProvider).fetchJoinCode(church.id);
});

class ChurchInfoPage extends ConsumerWidget {
  const ChurchInfoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final church = ref.watch(myChurchProvider).value;
    final code = ref.watch(churchJoinCodeProvider);

    return AppScaffold(
      title: 'Church information',
      showBackButton: true,
      backFallback: '/profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Text(
            'Share this code so people can ask to join your church.',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (church != null) ...[
            Text(church.name, style: AppTypography.pageTitle),
            const SizedBox(height: AppSpacing.md),
          ],
          code.when(
            loading: () => const SizedBox(height: 160, child: LoadingState()),
            error: (e, _) => e is MembershipFailure && !e.isNetwork
                ? const EmptyState.restricted(
                    message:
                        "The join code is shown to the church's Coordinator.",
                  )
                : SizedBox(
                    height: 240,
                    child: ErrorState.load(
                      subject: 'the join code',
                      error: e,
                      onRetry: () => ref.invalidate(churchJoinCodeProvider),
                    ),
                  ),
            data: (c) => c == null
                ? const EmptyState.restricted(
                    message:
                        "The join code is shown to the church's Coordinator.",
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      JoinCodeCard(
                        code: c,
                        footnote: c.setAt == null
                            ? null
                            : 'Set ${AppFormat.shortDate(c.setAt!)}',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Only the DiscipleTrack administrator can change '
                        'this code.',
                        style: context.captionStyle,
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
