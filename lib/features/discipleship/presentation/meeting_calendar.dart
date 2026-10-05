import 'package:flutter/material.dart';

import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_text_link.dart';
import '../domain/attendance_outcome.dart';
import '../domain/meeting_history_entry.dart';
import 'discipleship_ui.dart';

/// A person's recorded meetings as a month calendar (user decision of
/// 2026-10-05): each date with a recorded meeting carries a marker for its
/// outcome; tapping a date shows that day's meetings below; the full list
/// opens in a sheet.
///
/// Read-only history. Dates without a record are plain: no record is never
/// an absence (ADR-014), so a blank date is not styled as a warning.
class MeetingCalendar extends StatefulWidget {
  const MeetingCalendar({
    required this.entries,
    required this.emptyMessage,
    this.clock,
    this.actionBuilder,
    super.key,
  });

  /// An action shown at the foot of the calendar card, given the selected
  /// day (null when none) and whether a meeting is recorded on it. Used for
  /// "Record a meeting today" and "Record a meeting on Oct 3".
  final Widget? Function(DateTime? selectedDay, bool hasMeeting)? actionBuilder;

  /// Newest first, as `get_meeting_history()` returns them.
  final List<MeetingHistoryEntry> entries;
  final String emptyMessage;

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
Color _markerColor(BuildContext context, MeetingHistoryEntry e) {
  if (e.isVoided) return Theme.of(context).colorScheme.outlineVariant;
  return switch (e.outcome) {
    AttendanceOutcome.present => progressColor(context),
    AttendanceOutcome.late => pillColors(context, PillTone.warning).$2,
    AttendanceOutcome.absent => pillColors(context, PillTone.error).$2,
    AttendanceOutcome.excused => pillColors(context, PillTone.neutral).$2,
  };
}

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

  /// Opens on the month of the latest meeting, with that day selected.
  void _openLatest() {
    final latest = widget.entries.isEmpty
        ? null
        : _day(widget.entries.first.occurredAt);
    final base = latest ?? _now;
    _month = DateTime(base.year, base.month);
    _selected = latest;
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
      final action = widget.actionBuilder?.call(null, false);
      return Card.filled(
        color: context.palette.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.emptyMessage),
              if (action != null) ...[
                const SizedBox(height: AppSpacing.md),
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
                    _Legend(color: progressColor(context), label: 'Present'),
                    _Legend(
                      color: pillColors(context, PillTone.warning).$2,
                      label: 'Late',
                    ),
                    _Legend(
                      color: pillColors(context, PillTone.error).$2,
                      label: 'Recorded absence',
                    ),
                    _Legend(
                      color: pillColors(context, PillTone.neutral).$2,
                      label: 'Excused',
                    ),
                    _Legend(color: scheme.outlineVariant, label: 'Voided'),
                  ],
                ),
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
        const SizedBox(height: AppSpacing.sm),
        if (_selected != null)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.xxs,
              bottom: AppSpacing.xxs,
            ),
            child: Text(
              AppFormat.shortDate(_selected!.toUtc()),
              style: text.labelLarge,
            ),
          ),
        if (_selected != null && selectedEntries.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.xxs),
            child: Text(
              'No meeting recorded on this date.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        for (final e in selectedEntries)
          Card.filled(
            color: context.palette.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            margin: EdgeInsets.zero,
            child: MeetingHistoryRow(entry: e),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: AppTextLink(
              label: widget.entries.length == 1
                  ? 'View full history · 1 meeting'
                  : 'View full history · ${widget.entries.length} meetings',
              onTap: () => _showAll(context),
            ),
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
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (sheet, controller) => ListView.separated(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          itemCount: widget.entries.length + 1,
          separatorBuilder: (_, i) =>
              SizedBox(height: i == 0 ? 0 : AppSpacing.xs),
          itemBuilder: (sheet, i) => i == 0
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Text(
                    'Meeting history',
                    style: Theme.of(sheet).textTheme.titleLarge,
                  ),
                )
              : Material(
                  color: neutralFill(sheet),
                  borderRadius: BorderRadius.circular(18),
                  clipBehavior: Clip.antiAlias,
                  child: MeetingHistoryRow(entry: widget.entries[i - 1]),
                ),
        ),
      ),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? scheme.primaryContainer : null,
                  border: isToday && !isSelected
                      ? Border.all(color: scheme.primary)
                      : null,
                ),
                child: Text(
                  '$dayNumber',
                  style: text.bodyMedium?.copyWith(
                    color: isFuture
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : isSelected
                        ? scheme.onPrimaryContainer
                        : scheme.onSurface,
                    fontWeight: entries.isEmpty ? null : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final e in entries.take(3))
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: _markerColor(context, e),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
