import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/person_row.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/empty_state.dart';
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
        // The heading with View all beside it, as "See all" on Home.
        SectionHeading(
          title,
          trailing: events.length > recent.length
              ? AppTextLink(label: 'View all', onTap: () => _showAll(context))
              : null,
        ),
        // Each event is its own card; no shared container around them.
        ActivityTimeline(events: recent),
      ],
    );
  }

  void _showAll(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JourneyHistoryPage(events: events),
      ),
    );
  }
}

/// Whether meeting cards show a photo pill, to preview the layout before
/// photos can be attached to meetings (not built yet; user, 2026-10-07).
/// Debug builds only, so no one is told a photo exists when it does not.
const kPreviewMeetingPhotos = kDebugMode;

/// A compact timeline, as the user's reference (2026-10-07): the day on
/// the left, then one card per event with a thin bar in its state's colour
/// and the lesson it belongs to on the right.
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
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : AppSpacing.xs),
            child: _EventRow(event: events[i]),
          ),
      ],
    );
  }
}

/// The colour an event's bar carries: the attendance or completion state;
/// grey for events without one.
Color _accentOf(BuildContext context, ActivityEvent event) {
  final p = context.palette;
  return switch (event.kind) {
    ActivityKind.lessonCompleted => p.brand,
    ActivityKind.lessonStarted => pillColors(context, PillTone.info).$2,
    ActivityKind.meetingVoided => p.muted,
    ActivityKind.meeting => switch (event.outcome) {
      AttendanceOutcome.present => p.brand,
      AttendanceOutcome.late => pillColors(context, PillTone.warning).$2,
      AttendanceOutcome.absent => pillColors(context, PillTone.error).$2,
      AttendanceOutcome.excused => p.muted,
      null => p.muted,
    },
  };
}

/// The event in a few words; the lesson is shown beside it.
String _headline(ActivityEvent e) => switch (e.kind) {
  ActivityKind.lessonStarted => 'Lesson started',
  ActivityKind.lessonCompleted => 'Lesson completed',
  ActivityKind.meetingVoided => e.title,
  ActivityKind.meeting =>
    e.outcome == null
        ? '${e.title} · not counted'
        : 'Meeting · ${e.outcome!.label}',
};

/// "Today", "Yesterday", or the short date.
String _day(DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final d = DateTime(local.year, local.month, local.day);
  final today = DateTime(now.year, now.month, now.day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return AppFormat.shortDate(at);
}

/// "Lesson 3", small and quiet, on the right of a row.
class _LessonTag extends StatelessWidget {
  const _LessonTag(this.number);

  final int number;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: neutralFill(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Lesson $number',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: p.muted, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({required this.event});

  final ActivityEvent event;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final headline = _headline(event);
    return Semantics(
      container: true,
      label:
          '${_day(event.at)}. $headline'
          '${event.lessonNumber == null ? '' : ', Lesson ${event.lessonNumber}'}',
      excludeSemantics: true,
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              _day(event.at),
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _accentOf(context, event),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      headline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (event.lessonNumber != null) ...[
                    const SizedBox(width: AppSpacing.xs),
                    _LessonTag(event.lessonNumber!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole journey history, on its own page (user, 2026-10-07): tabs by
/// kind of event and a month filter, then one tinted card per event beside
/// its date.
class JourneyHistoryPage extends StatefulWidget {
  const JourneyHistoryPage({required this.events, super.key});

  /// Newest first.
  final List<ActivityEvent> events;

  @override
  State<JourneyHistoryPage> createState() => _JourneyHistoryPageState();
}

enum _HistoryTab {
  all('All'),
  meetings('Meetings'),
  absent('Absent'),
  lessons('Lessons');

  const _HistoryTab(this.label);

  final String label;

  bool matches(ActivityEvent e) => switch (this) {
    _HistoryTab.all => true,
    _HistoryTab.meetings =>
      e.kind == ActivityKind.meeting || e.kind == ActivityKind.meetingVoided,
    _HistoryTab.absent =>
      e.kind == ActivityKind.meeting && e.outcome == AttendanceOutcome.absent,
    _HistoryTab.lessons =>
      e.kind == ActivityKind.lessonStarted ||
          e.kind == ActivityKind.lessonCompleted,
  };
}

class _JourneyHistoryPageState extends State<JourneyHistoryPage> {
  _HistoryTab _tab = _HistoryTab.all;

  /// The first day of the chosen month, local; null for every month.
  DateTime? _month;

  static DateTime _monthOf(DateTime at) {
    final l = at.toLocal();
    return DateTime(l.year, l.month);
  }

  @override
  Widget build(BuildContext context) {
    final months = {for (final e in widget.events) _monthOf(e.at)}.toList();
    final shown = [
      for (final e in widget.events)
        if (_tab.matches(e) && (_month == null || _monthOf(e.at) == _month)) e,
    ];
    return AppScaffold(
      title: 'Journey history',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final t in _HistoryTab.values)
                        _Tab(
                          label: t.label,
                          selected: t == _tab,
                          onTap: () => setState(() => _tab = t),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              _MonthFilter(
                months: months,
                value: _month,
                onChanged: (m) => setState(() => _month = m),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (shown.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: EmptyState(
                illustration: Illustration.empty,
                title: 'Nothing here',
                message: _month == null
                    ? 'No ${_tab.label.toLowerCase()} in this journey yet.'
                    : 'Nothing of this kind in '
                          '${AppFormat.monthYear(_month!)}.',
              ),
            )
          else
            for (final e in shown) ...[
              _HistoryRow(event: e),
              const SizedBox(height: AppSpacing.sm),
            ],
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// One tab: its text, and a thin lime outline when selected, as the
/// Members tabs.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: StadiumBorder(
              side: selected
                  ? BorderSide(color: p.brand, width: 1.2)
                  : BorderSide.none,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              color: selected
                  ? pillColors(context, PillTone.brand).$2
                  : p.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// "All months", or one month, picked from the months the journey has.
class _MonthFilter extends StatelessWidget {
  const _MonthFilter({
    required this.months,
    required this.value,
    required this.onChanged,
  });

  final List<DateTime> months;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Compact: a calendar icon, with the short month once one is chosen.
    final label = value == null
        ? null
        : AppFormat.shortDate(value!.toUtc()).split(' ').first;
    return PopupMenuButton<DateTime?>(
      tooltip: 'Filter by month',
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem<DateTime?>(value: null, child: Text('All months')),
        for (final m in months)
          PopupMenuItem<DateTime?>(
            value: m,
            child: Text(AppFormat.monthYear(m)),
          ),
      ],
      child: Container(
        height: 36,
        constraints: const BoxConstraints(minWidth: 36),
        padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 10),
        decoration: BoxDecoration(
          color: label == null
              ? neutralFill(context)
              : pillColors(context, PillTone.brand).$1,
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month_outlined,
              size: 18,
              color: label == null
                  ? p.textPrimary
                  : pillColors(context, PillTone.brand).$2,
            ),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: pillColors(context, PillTone.brand).$2,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The card's soft tint: the event's state, as the reference's coloured
/// cards; grey for events without one.
PillTone _toneOf(ActivityEvent e) => switch (e.kind) {
  ActivityKind.lessonCompleted => PillTone.brand,
  ActivityKind.lessonStarted => PillTone.info,
  ActivityKind.meetingVoided => PillTone.neutral,
  ActivityKind.meeting => switch (e.outcome) {
    AttendanceOutcome.present => PillTone.brand,
    AttendanceOutcome.late => PillTone.warning,
    AttendanceOutcome.absent => PillTone.error,
    AttendanceOutcome.excused || null => PillTone.neutral,
  },
};

/// One event: its date on the left, as the reference's time column, and a
/// tinted card beside it. Inside the card, left to right: the state bar,
/// what happened with its details, and the lesson and photo on the right.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event});

  final ActivityEvent event;

  static const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final local = event.at.toLocal();
    final m = event.meeting;
    final (tint, _) = pillColors(context, _toneOf(event));
    final facts = <(IconData, String)>[
      if (event.lessonTitle != null)
        (Icons.menu_book_outlined, event.lessonTitle!),
      if (m?.recordedByName != null && event.kind == ActivityKind.meeting)
        (Icons.edit_outlined, m!.recordedByName!),
      if (event.kind == ActivityKind.meetingVoided && m?.voidedByName != null)
        (Icons.block_rounded, m!.voidedByName!),
      if (event.kind == ActivityKind.lessonCompleted && event.detail != null)
        (Icons.check_circle_outline_rounded, event.detail!),
    ];
    final notes = event.kind == ActivityKind.meeting ? m?.notes : null;
    final photo =
        kPreviewMeetingPhotos &&
        event.kind == ActivityKind.meeting &&
        m != null &&
        !m.isVoided;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The date column: day, month and weekday.
        SizedBox(
          width: 56,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${local.day}',
                  style: text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppFormat.shortDate(event.at).split(' ').first,
                  style: text.labelSmall?.copyWith(color: p.muted),
                ),
                Text(
                  _weekdays[local.weekday - 1],
                  style: text.labelSmall?.copyWith(color: p.muted),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(22),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: _accentOf(context, event),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _headline(event),
                          style: text.titleMedium?.copyWith(
                            color: p.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        for (final (icon, line) in facts) ...[
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(icon, size: 15, color: p.muted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  line,
                                  style: text.bodySmall?.copyWith(
                                    color: p.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (notes != null && notes.trim().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            notes,
                            style: text.bodySmall?.copyWith(
                              color: p.textPrimary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  // The right side: the lesson at the top, the photo at the
                  // bottom.
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (event.lessonNumber != null)
                        _LessonTag(event.lessonNumber!)
                      else
                        const SizedBox.shrink(),
                      if (photo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: p.surface.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.photo_outlined,
                                size: 14,
                                color: p.textPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '1',
                                style: text.labelSmall?.copyWith(
                                  color: p.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
