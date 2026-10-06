import 'package:flutter/material.dart';

import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_card.dart';
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
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ActivityTimeline(events: recent),
              if (events.length > recent.length) ...[
                const SizedBox(height: AppSpacing.xs),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppTextLink(
                    label: 'View journey history · ${events.length} events',
                    onTap: () => _showAll(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _showAll(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
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

/// A compact vertical timeline: one row per event with a small dot, a thin
/// connector to the next event, the event in bold, and its date and context
/// beneath. The newest event's dot is slightly stronger.
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

  /// A dot colour only where it carries meaning.
  Color _dotColor(BuildContext context) {
    final p = context.palette;
    final neutral = pillColors(context, PillTone.outline).$2;
    return switch (event.kind) {
      ActivityKind.lessonCompleted => p.brand,
      ActivityKind.meeting => switch (event.outcome) {
        AttendanceOutcome.present => p.brand,
        AttendanceOutcome.late => pillColors(context, PillTone.warning).$2,
        AttendanceOutcome.absent => pillColors(context, PillTone.error).$2,
        _ => neutral,
      },
      _ => neutral,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
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
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 5),
                  Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      color: _dotColor(context),
                      shape: BoxShape.circle,
                      border: isFirst
                          ? Border.all(color: p.textPrimary, width: 1.5)
                          : null,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        color: p.border,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: text.bodyMedium?.copyWith(
                        fontWeight: isFirst ? FontWeight.w700 : FontWeight.w600,
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
    );
  }
}
