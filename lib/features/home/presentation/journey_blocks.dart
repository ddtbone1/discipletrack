import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/format/app_format.dart';
import '../../../core/connectivity/connection_status.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/person_row.dart';
import '../../curriculum/presentation/lesson_carousel.dart';
import '../../discipleship/application/discipleship_providers.dart';
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
          SectionHeading(
            'Your journey',
            trailing: AppTextLink(
              label: 'See all',
              onTap: () => context.go(Routes.journey),
            ),
          ),
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
      final id = ref.watch(myMembershipIdProvider);
      final last = id == null
          ? null
          : ref.watch(meetingSummaryProvider(id)).value?.lastRecordedMeetingAt;
      // One line of facts, then the lessons to swipe through; the current
      // one opens straight into the reader.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${j.lessonsCompleted} of ${j.lessonsTotal} completed',
                  style: TextStyle(
                    color: pillColors(context, PillTone.brand).$2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (last != null)
                  TextSpan(text: '  ·  Last met ${AppFormat.shortDate(last)}'),
              ],
            ),
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          LessonCarousel(journey: j),
        ],
      );
    }
    return AppCard(onTap: () => context.go(Routes.journey), child: content);
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
