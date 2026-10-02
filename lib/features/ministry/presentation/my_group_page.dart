import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../application/ministry_providers.dart';
import '../domain/ministry_context.dart';
import 'ministry_ui.dart';

/// The roster for a Discipler or Disciple: their Leader, their own Discipler,
/// a Discipler's own Disciples, and everyone else in the group by name.
///
/// Phone numbers appear only where `get_my_d_group_roster()` returned them
/// (Plan decision 8): the person's own Leader and own Discipler, and a
/// Discipler's assigned Disciples.
class MyGroupPage extends ConsumerWidget {
  const MyGroupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctx = ref.watch(myMinistryContextProvider);

    return AppScaffold(
      title: ctx.value?.dGroupName ?? 'My group',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          ctx.when(
            loading: () => const SizedBox(height: 320, child: LoadingState()),
            error: (e, _) => SizedBox(
              height: 320,
              child: ErrorState(
                message: e.toString(),
                onRetry: () => ref.invalidate(myMinistryContextProvider),
              ),
            ),
            data: (c) => c == null ? const _NotPlaced() : _Roster(ministry: c),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _Roster extends StatelessWidget {
  const _Roster({required this.ministry});

  final MinistryContext ministry;

  @override
  Widget build(BuildContext context) {
    final c = ministry;
    final leader = c.leader;
    final discipler = c.myDiscipler;
    final disciples = c.myDisciples;
    final shown = {
      ?leader?.churchMembershipId,
      ?discipler?.churchMembershipId,
      for (final d in disciples) d.churchMembershipId,
    };
    final others = [
      for (final m in c.groupMates)
        if (!shown.contains(m.churchMembershipId)) m,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'You are ${_roles(c)} in ${c.dGroupName}.',
          style: context.supportingStyle,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (leader != null) ...[
          const SectionHeading('Your Leader'),
          AppCard(
            padding: EdgeInsets.zero,
            child: PersonRow(name: leader.fullName, detail: leader.phone),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (c.isDisciple) ...[
          const SectionHeading('Your Discipler'),
          AppCard(
            padding: EdgeInsets.zero,
            child: discipler == null
                ? const PersonRow(
                    name: 'Not paired yet',
                    detail: 'Your Leader will pair you with a Discipler.',
                  )
                : PersonRow(name: discipler.fullName, detail: discipler.phone),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (c.isDiscipler) ...[
          const SectionHeading('Your Disciples'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: dividedRows([
                if (disciples.isEmpty)
                  const PersonRow(
                    name: 'No Disciples paired with you yet',
                    detail: 'Your Leader pairs Disciples with you.',
                  ),
                for (final d in disciples)
                  PersonRow(name: d.fullName, detail: d.phone),
              ]),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (others.isNotEmpty) ...[
          const SectionHeading('In your group'),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: dividedRows([
                for (final m in others)
                  PersonRow(name: m.fullName, detail: m.responsibility.label),
              ]),
            ),
          ),
        ],
      ],
    );
  }

  static String _roles(MinistryContext c) {
    final labels = [
      if (c.isLeader) 'the Leader',
      if (c.isDiscipler) 'a Discipler',
      if (c.isDisciple) 'a Disciple',
    ];
    return labels.join(' and ');
  }
}

class _NotPlaced extends StatelessWidget {
  const _NotPlaced();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      fill: AppCardFill.pastel,
      child: Text(
        'You are not in a D Group yet. When a Leader invites you, the '
        'invitation appears on your Home screen.',
        style: AppTypography.body.copyWith(
          color: AppCardFill.pastel.foreground(p),
        ),
      ),
    );
  }
}
