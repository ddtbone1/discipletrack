import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/info_group.dart';
import '../../../core/widgets/person_row.dart';
import '../../discipleship/application/discipleship_providers.dart';
import '../../discipleship/domain/journey.dart';
import '../../discipleship/domain/journey_views.dart';
import '../../discipleship/presentation/discipleship_ui.dart';
import '../../ministry/application/ministry_providers.dart';
import '../../ministry/domain/d_group_member.dart';
import '../../ministry/domain/ministry_context.dart';

/// "Disciple · Discipler": every responsibility the person holds, from their
/// roster rows. Additive; never one role.
String responsibilityLine(MinistryContext ministry) => [
  for (final r in const [
    DGroupResponsibility.leader,
    DGroupResponsibility.disciple,
    DGroupResponsibility.discipler,
  ])
    if (ministry.myResponsibilities.contains(r)) r.label,
].join(' · ');

/// "Anna Cruz and Ben Lim", or "3 people" from three on.
String discipleNames(List<String> names) => switch (names.length) {
  0 => 'Nobody yet',
  1 => names.single,
  2 => '${names.first} and ${names.last}',
  _ => '${names.length} people',
};

/// The ministry part of the person's own profile (UI_DESIGN_SYSTEM section
/// 63): their group and responsibilities, one journey summary when they are
/// a Disciple, and one line naming who they disciple. Summaries only; the
/// journey itself lives in Journey.
class MinistrySummary extends ConsumerWidget {
  const MinistrySummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministry = ref.watch(myMinistryContextProvider).value;
    if (ministry == null) return const SizedBox.shrink();
    final views = JourneyViews.of(ministry);
    final disciples = [for (final d in ministry.myDisciples) d.fullName];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoGroup(
          title: 'Ministry',
          rows: [
            InfoRow(label: 'D Group', value: ministry.dGroupName),
            InfoRow(
              label: 'Responsibilities',
              value: responsibilityLine(ministry),
            ),
            if (views.hasDisciples)
              InfoRow(
                label: 'Currently discipling',
                value: discipleNames(disciples),
                onTap: () => context.go(Routes.journeyDisciples),
              ),
          ],
        ),
        if (views.hasOwnJourney) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionHeading('Your journey'),
          const _JourneySummary(),
        ],
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }
}

class _JourneySummary extends ConsumerWidget {
  const _JourneySummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final journey = ref.watch(myJourneyProvider).value;
    return AppCard(
      onTap: () => context.go(Routes.journey),
      child: journey == null
          ? Text('See my journey', style: context.supportingStyle)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                JourneyProgressBar(
                  total: journey.lessonsTotal,
                  completed: journey.lessonsCompleted,
                  currentNumber: journey.currentLesson?.number,
                  submitted:
                      journey.currentLesson?.state == LessonState.submitted,
                  compact: true,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  journey.summaryLine,
                  style: AppTypography.supporting.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
    );
  }
}
