import 'package:flutter/material.dart';

import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_text_link.dart';
import '../domain/attendance_outcome.dart';
import '../domain/journey_activity.dart';

/// The vertical activity timeline on the journey pages (UX decision of
/// 2026-10-06). Set to false to remove it everywhere; nothing else depends
/// on it.
const kShowJourneyActivity = true;

/// How many recent events show before "View journey history".
const _recentLimit = 5;

/// A titled section with the most recent journey events and, when there
/// are more, a link to the full history in a sheet.
///
/// For chronological storytelling only: what happened, and in what order.
/// It does not replace the monthly meeting calendar ("when did we meet?").
class JourneyActivitySection extends StatelessWidget {
  const JourneyActivitySection({
    required this.title,
    required this.events,
    super.key,
  });

  final String title;

  /// Newest first.
  final List<ActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    final recent = events.take(_recentLimit).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xxs,
            bottom: AppSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        // Each event is its own card; no shared container around them.
        ActivityTimeline(events: recent),
        if (events.length > recent.length) ...[
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.only(left: 20 + AppSpacing.sm),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AppTextLink(
                label: 'View journey history · ${events.length} events',
                onTap: () => _showAll(context),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      // Above the floating dock, which lives in the shell route.
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (sheet, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          children: [
            Text(
              'Journey history',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            ActivityTimeline(events: events),
          ],
        ),
      ),
    );
  }
}

/// A compact vertical timeline. Each event is its own thin, view-only card
/// on the plain surface, its attendance state shown by a coloured bar on
/// the inside left edge (Present and completed lime, Late amber, a recorded
/// absence red, Excused grey). The rail of dots and connecting
/// line sits outside the cards, on the left. The newest event's dot is
/// slightly stronger.
class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({required this.events, super.key});

  /// Newest first.
  final List<ActivityEvent> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < events.length; i++)
          _EventRow(
            event: events[i],
            isFirst: i == 0,
            isLast: i == events.length - 1,
          ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.isFirst,
    required this.isLast,
  });

  final ActivityEvent event;
  final bool isFirst;
  final bool isLast;

  /// The attendance (or completion) state the event's card and dot carry;
  /// null for events with no state, which stay on a plain surface.
  PillTone? get _tone => switch (event.kind) {
    ActivityKind.lessonCompleted => PillTone.brand,
    ActivityKind.meeting => switch (event.outcome) {
      AttendanceOutcome.present => PillTone.brand,
      AttendanceOutcome.late => PillTone.warning,
      AttendanceOutcome.absent => PillTone.error,
      AttendanceOutcome.excused => PillTone.outline,
      _ => null,
    },
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final tone = _tone;
    final deep = tone == null
        ? pillColors(context, PillTone.outline).$2
        : pillColors(context, tone).$2;
    // The state's own colour for the bar: lime itself for Present and
    // completed, the pill's strong tone for the rest.
    final accent = tone == PillTone.brand ? p.brand : deep;
    final size = isFirst ? 12.0 : 10.0;
    final secondary = [
      AppFormat.shortDate(event.at),
      ?event.detail,
    ].join(' · ');

    return Semantics(
      container: true,
      label: '${event.title}. $secondary',
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The timeline rail, outside the cards: a dot level with the
            // card's title and a line running on through the gap to the
            // next card.
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  if (!isFirst)
                    Container(width: 1.5, height: 12, color: p.border)
                  else
                    const SizedBox(height: 12),
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: deep,
                      shape: BoxShape.circle,
                      border: isFirst
                          ? Border.all(color: p.textPrimary, width: 1.5)
                          : null,
                    ),
                  ),
                  Expanded(
                    child: isLast
                        ? const SizedBox.shrink()
                        : Container(width: 1.5, color: p.border),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // One thin, view-only card per event on the plain surface. Its
            // state is a coloured bar on the inside left edge, not a fill
            // (user decision 2026-10-06).
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.xs),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (tone != null) Container(width: 4, color: accent),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: isFirst
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  color: p.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                secondary,
                                style: text.bodySmall?.copyWith(color: p.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
