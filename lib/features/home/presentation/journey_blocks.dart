import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/connectivity/connection_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/person_row.dart';
import '../../discipleship/application/discipleship_providers.dart';
import '../../discipleship/domain/journey.dart';
import '../../discipleship/domain/journey_views.dart';
import '../../discipleship/presentation/discipleship_ui.dart';
import '../../discipleship/presentation/my_disciples_page.dart';
import '../../ministry/application/ministry_providers.dart';

/// Home's blocks per relationship (plan section F2, user rule 2L): the
/// person's own journey when they are a Disciple, and their discipleships
/// when Disciples are paired with them. Blocks compose; there is no role
/// switch. No eligibility, appointment or church-wide figure (section P).
class JourneyBlocks extends ConsumerWidget {
  const JourneyBlocks({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ministry = ref.watch(myMinistryContextProvider).value;
    final views = JourneyViews.of(ministry);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (views.hasOwnJourney) ...[
          const SectionHeading('Your journey'),
          // The Discipler's name is on the D Group card above.
          const _OwnJourney(),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (views.hasDisciples) ...[
          SectionHeading(
            'Your discipleships',
            trailing: AppTextLink(
              label: 'See all',
              onTap: () => context.go(Routes.journeyDisciples),
            ),
          ),
          const _Discipleships(),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

class _OwnJourney extends ConsumerWidget {
  const _OwnJourney();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final journey = ref.watch(myJourneyProvider);
    final Widget content;
    if (journey.hasError && !journey.hasValue) {
      content = Text(
        isNetworkFailure(journey.error!)
            ? 'Your journey needs a connection.'
            : "We couldn't load your journey. Open Journey to try again.",
        style: context.supportingStyle,
      );
    } else if (journey.value == null) {
      content = const SizedBox(height: 48);
    } else {
      final j = journey.value!;
      final current = j.currentLesson;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            current == null
                ? 'Every lesson completed'
                : 'Lesson ${current.number} · ${current.countLine}',
            style: AppTypography.body.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          JourneyProgressBar(
            total: j.lessonsTotal,
            completed: j.lessonsCompleted,
            currentNumber: current?.number,
            submitted: current?.state == LessonState.submitted,
            compact: true,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(j.summaryLine, style: context.supportingStyle),
        ],
      );
    }
    return AppCard(
      onTap: () => context.go(Routes.journey),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content,
          const SizedBox(height: AppSpacing.xs),
          Text(
            'See my journey',
            style: AppTypography.supporting.copyWith(
              color: p.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Up to three Disciples in the compact row format, and Record a meeting.
class _Discipleships extends ConsumerWidget {
  const _Discipleships();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disciples = ref.watch(myDisciplesProvider);
    final rows = disciples.value;
    if (rows == null) {
      return disciples.hasError
          ? Text(
              isNetworkFailure(disciples.error!)
                  ? 'Your Disciples need a connection.'
                  : "We couldn't load your Disciples. Open Journey to try "
                        'again.',
              style: context.supportingStyle,
            )
          : const SizedBox(height: 48);
    }
    final recordable = [
      for (final d in rows)
        if (d.currentLessonNumber != null) d,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TileGroup(
          children: [
            for (final d in rows.take(3))
              DiscipleProgressRow(
                disciple: d,
                onTap: () =>
                    context.push(Routes.discipleDetailFor(d.membershipId)),
              ),
          ],
        ),
        if (recordable.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Record a meeting',
            variant: AppButtonVariant.record,
            requiresConnection: true,
            offlineAction: 'record a meeting',
            onPressed: () => recordable.length == 1
                ? context.push(
                    Routes.recordMeetingFor(recordable.single.membershipId),
                  )
                : showChooseDiscipleSheet(context, recordable),
          ),
        ],
      ],
    );
  }
}
