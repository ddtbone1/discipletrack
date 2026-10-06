import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/illustration.dart';
import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../domain/attendance_outcome.dart';
import '../domain/meeting_history_entry.dart';
import 'discipleship_ui.dart';

/// A person's recorded meetings as a month calendar (user decision of
/// 2026-10-05): each date with a recorded meeting carries a marker for its
/// outcome; tapping a date shows that day's meetings below. The full
/// history is told by the journey activity timeline, not a list here.
///
/// Read-only history. Dates without a record are plain: no record is never
/// an absence (ADR-014), so a blank date is not styled as a warning.
class MeetingCalendar extends StatefulWidget {
  const MeetingCalendar({
    required this.entries,
    required this.emptyMessage,
    this.emptyIllustration = Illustration.empty,
    this.emptyAction,
    this.clock,
    this.actionBuilder,
    this.entryActionBuilder,
    super.key,
  });

  /// An action shown at the foot of the calendar card, given the selected
  /// day (null when none) and whether a meeting is recorded on it. Used for
  /// "Record a meeting today" and "Record a meeting on Oct 3".
  final Widget? Function(DateTime? selectedDay, bool hasMeeting)? actionBuilder;

  /// An action beside each of the selected day's meetings, such as the
  /// void menu; null for none.
  final Widget? Function(MeetingHistoryEntry entry)? entryActionBuilder;

  /// Newest first, as `get_meeting_history()` returns them.
  final List<MeetingHistoryEntry> entries;
  final String emptyMessage;

  /// The mood of the empty state, before any meeting is recorded.
  final Illustration emptyIllustration;

  /// What to do next in the empty state, such as a link to record the
  /// first meeting.
  final Widget? emptyAction;

  /// For tests; defaults to now.
  final DateTime Function()? clock;

  @override
  State<MeetingCalendar> createState() => _MeetingCalendarState();
}

DateTime _day(DateTime utc) {
  final d = utc.toLocal();
  return DateTime(d.year, d.month, d.day);
}

/// The marker colour for a day: voided rows are muted, counted meetings
/// use the primary colour, a recorded absence the error colour, Excused a
/// neutral outline colour.
/// Pastel fills for a day with a meeting, with the day number in the same
/// hue, deep; the same in both modes (user request of 2026-10-06). They
/// match the light pill palette.
const _presentFill = Color(0xFFDDF9B5);
const _lateFill = Color(0xFFFFEDB0);
const _absentFill = Color(0xFFFFD6D6);
const _excusedFill = Color(0xFFE4E7EB);

(Color fill, Color number) _solid(AttendanceOutcome outcome) =>
    switch (outcome) {
      AttendanceOutcome.present => (_presentFill, const Color(0xFF2F5600)),
      AttendanceOutcome.late => (_lateFill, const Color(0xFF7A5A00)),
      AttendanceOutcome.absent => (_absentFill, const Color(0xFFA4231C)),
      AttendanceOutcome.excused => (_excusedFill, const Color(0xFF4A5159)),
    };

class _MeetingCalendarState extends State<MeetingCalendar> {
  late DateTime _month;
  DateTime? _selected;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  Map<DateTime, List<MeetingHistoryEntry>> get _byDay {
    final map = <DateTime, List<MeetingHistoryEntry>>{};
    for (final e in widget.entries) {
      map.putIfAbsent(_day(e.occurredAt), () => []).add(e);
    }
    return map;
  }

  @override
  void initState() {
    super.initState();
    _openLatest();
  }

  @override
  void didUpdateWidget(MeetingCalendar old) {
    super.didUpdateWidget(old);
    if (old.entries.length != widget.entries.length) _openLatest();
  }

  /// Opens on the month of the latest meeting with no day selected: the
  /// coloured days tell the outcomes, and a tap shows a day's details.
  void _openLatest() {
    final latest = widget.entries.isEmpty
        ? null
        : _day(widget.entries.first.occurredAt);
    final base = latest ?? _now;
    _month = DateTime(base.year, base.month);
    _selected = null;
  }

  DateTime get _firstMonth {
    if (widget.entries.isEmpty) return DateTime(_now.year, _now.month);
    final oldest = _day(widget.entries.last.occurredAt);
    return DateTime(oldest.year, oldest.month);
  }

  bool get _canGoBack => _month.isAfter(_firstMonth);
  bool get _canGoForward => _month.isBefore(DateTime(_now.year, _now.month));

  void _shift(int months) => setState(() {
    _month = DateTime(_month.year, _month.month + months);
  });

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      final action =
          widget.emptyAction ?? widget.actionBuilder?.call(null, false);
      return Card.filled(
        color: context.palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              IllustrationView(widget.emptyIllustration, height: 110),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.emptyMessage,
                textAlign: TextAlign.center,
                style: context.supportingStyle,
              ),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.sm),
                action,
              ],
            ],
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final byDay = _byDay;
    final selectedEntries = _selected == null
        ? const <MeetingHistoryEntry>[]
        : byDay[_selected] ?? const <MeetingHistoryEntry>[];
    final action = widget.actionBuilder?.call(
      _selected,
      selectedEntries.isNotEmpty,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card.filled(
          color: context.palette.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.xs,
              AppSpacing.md,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Previous month',
                      onPressed: _canGoBack ? () => _shift(-1) : null,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: Text(
                        AppFormat.monthYear(_month),
                        textAlign: TextAlign.center,
                        style: text.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next month',
                      onPressed: _canGoForward ? () => _shift(1) : null,
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                _MonthGrid(
                  month: _month,
                  today: _day(_now.toUtc()),
                  selected: _selected,
                  byDay: byDay,
                  onSelect: (d) => setState(() => _selected = d),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    const _Legend(color: _presentFill, label: 'Present'),
                    const _Legend(color: _lateFill, label: 'Late'),
                    const _Legend(
                      color: _absentFill,
                      label: 'Recorded absence',
                    ),
                    const _Legend(color: _excusedFill, label: 'Excused'),
                    _Legend(
                      color: Colors.transparent,
                      border: scheme.outline,
                      label: 'Voided',
                    ),
                  ],
                ),
                if (_selected != null) ...[
                  const Divider(height: AppSpacing.lg),
                  if (selectedEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                      ),
                      child: Text(
                        'No meeting recorded on '
                        '${AppFormat.shortDate(_selected!.toUtc())}.',
                        style: text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final e in selectedEntries)
                    MeetingHistoryRow(
                      entry: e,
                      trailing: widget.entryActionBuilder?.call(e),
                    ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: action,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.today,
    required this.selected,
    required this.byDay,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime? selected;
  final Map<DateTime, List<MeetingHistoryEntry>> byDay;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final firstWeekday = l10n.firstDayOfWeekIndex; // 0 = Sunday
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    // DateTime.weekday: Monday = 1 ... Sunday = 7.
    final leading =
        (DateTime(month.year, month.month).weekday % 7 - firstWeekday) % 7;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    l10n.narrowWeekdays[(firstWeekday + i) % 7],
                    textAlign: TextAlign.center,
                    style: text.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(child: _cell(context, r * 7 + c - leading + 1)),
            ],
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, int dayNumber) {
    final daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const SizedBox(height: 48);
    }
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final date = DateTime(month.year, month.month, dayNumber);
    final entries = byDay[date] ?? const <MeetingHistoryEntry>[];
    final isSelected = date == selected;
    final isToday = date == today;
    final isFuture = date.isAfter(today);
    // The latest meeting that stands sets the fill; a day with only voided
    // meetings gets an outline.
    MeetingHistoryEntry? standing;
    for (final e in entries) {
      if (!e.isVoided) {
        standing = e;
        break;
      }
    }
    final solid = standing == null ? null : _solid(standing.outcome);
    final onlyVoided = entries.isNotEmpty && standing == null;

    final label = [
      MaterialLocalizations.of(context).formatFullDate(date),
      if (entries.isEmpty)
        'no meeting recorded'
      else
        for (final e in entries) e.outcomeLine,
    ].join(', ');

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isFuture ? null : () => onSelect(date),
        child: SizedBox(
          height: 48,
          child: Center(
            // Selected: a ring around the day, outside any fill.
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: scheme.onSurface, width: 2)
                    : null,
              ),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: solid?.$1,
                  border: onlyVoided
                      ? Border.all(color: scheme.outline)
                      : isToday && solid == null
                      ? Border.all(color: scheme.primary)
                      : null,
                ),
                child: Text(
                  '$dayNumber',
                  style: text.bodyMedium?.copyWith(
                    color: solid != null
                        ? solid.$2
                        : isFuture
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : scheme.onSurface,
                    fontWeight: entries.isEmpty ? null : FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.border});

  final Color color;
  final String label;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
