import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/app_format.dart';
import '../../../core/supabase/postgrest_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_link.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/person_row.dart';
import '../../profile/presentation/member_avatar.dart';
import '../application/discipleship_providers.dart';
import '../data/discipleship_repository.dart';
import '../domain/attendance_outcome.dart';
import '../domain/meeting_draft.dart';
import 'discipleship_ui.dart';

/// Record a meeting: one meetup, after the fact, with each Disciple's
/// outcome stated explicitly (ADR-014: the only place attendance exists).
///
/// Lesson-centred (UI_DESIGN_SYSTEM section 25): the lesson is the opened
/// person's current lesson and is shown, not chosen. Other Disciples of the
/// same Discipler on that lesson can be added; those on another lesson are
/// listed but cannot be. Recording never completes a lesson.
class RecordMeetingPage extends ConsumerWidget {
  const RecordMeetingPage({
    required this.membershipId,
    this.initialDate,
    super.key,
  });

  final String membershipId;

  /// A preselected day, from the calendar; clamped to the allowed range.
  final DateTime? initialDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(recordingOptionsProvider(membershipId));
    return AppScaffold(
      title: 'Record a meeting',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          options.when(
            loading: () => const SizedBox(height: 320, child: LoadingState()),
            error: (e, _) =>
                e is DiscipleshipFailure && e.code == DbFailureCode.forbidden
                ? const EmptyState.restricted(
                    title: "You can't record for this person",
                    message:
                        "Meetings are recorded by the person's Discipler, or "
                        'by their Leader or the Coordinator on the '
                        "Discipler's behalf.",
                  )
                : SizedBox(
                    height: 320,
                    child: ErrorState.load(
                      subject: 'who can be recorded',
                      error: e,
                      onRetry: () => ref.invalidate(
                        recordingOptionsProvider(membershipId),
                      ),
                    ),
                  ),
            data: (rows) {
              final target = rows.where((r) => r.isTarget).firstOrNull;
              if (target == null) {
                return const EmptyState(
                  illustration: Illustration.empty,
                  message:
                      'No Disciples can be recorded together for this lesson.',
                );
              }
              return RecordMeetingForm(
                target: target,
                options: rows,
                initialDate: initialDate,
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// The form itself, given what `get_recording_options()` returned.
class RecordMeetingForm extends ConsumerStatefulWidget {
  const RecordMeetingForm({
    required this.target,
    required this.options,
    this.clock,
    this.initialDate,
    super.key,
  });

  final DateTime? initialDate;

  final RecordingOption target;
  final List<RecordingOption> options;

  /// For tests; defaults to now.
  final DateTime Function()? clock;

  @override
  ConsumerState<RecordMeetingForm> createState() => _RecordMeetingFormState();
}

class _RecordMeetingFormState extends ConsumerState<RecordMeetingForm> {
  late final Map<String, AttendanceOutcome?> _outcomes = {
    widget.target.membershipId: AttendanceOutcome.present,
  };
  late DateTime _day = _initialDay;
  final _notes = TextEditingController();
  String? _problem;

  DateTime get _now => (widget.clock ?? DateTime.now)();
  DateTime get _today => DateTime(_now.year, _now.month, _now.day);

  /// The calendar's day when given, never before the first allowed day or
  /// after today.
  DateTime get _initialDay {
    final d = widget.initialDate;
    if (d == null) return _today;
    final day = DateTime(d.year, d.month, d.day);
    if (day.isAfter(_today)) return _today;
    if (day.isBefore(_firstDay)) return _firstDay;
    return day;
  }

  RecordingOption get _target => widget.target;

  List<RecordingOption> get _sameLesson => [
    for (final o in widget.options)
      if (o.lessonId == _target.lessonId) o,
  ];

  List<RecordingOption> get _otherLesson => [
    for (final o in widget.options)
      if (o.lessonId != _target.lessonId) o,
  ];

  /// The earliest day the opened person can be recorded on: when both they
  /// and their Discipler were in place.
  DateTime get _firstDay {
    final a = _target.pairedSince.toLocal();
    final b = _target.disciplerSince.toLocal();
    final first = a.isAfter(b) ? a : b;
    return DateTime(first.year, first.month, first.day);
  }

  MeetingDraft? get _draft {
    if (_outcomes.values.any((o) => o == null)) return null;
    return MeetingDraft(
      lessonId: _target.lessonId,
      lessonNumber: _target.lessonNumber,
      disciplerDGroupMembershipId: _target.disciplerDGroupMembershipId,
      occurredOn: _day,
      outcomes: {for (final e in _outcomes.entries) e.key: e.value!},
      names: {for (final o in widget.options) o.membershipId: o.fullName},
      notes: _notes.text.trim().isEmpty ? null : _notes.text,
    );
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: _firstDay,
      lastDate: _today,
      helpText: 'Date of the meeting',
    );
    if (picked != null) setState(() => _day = picked);
  }

  void _nobodyCame() => setState(() {
    for (final id in _outcomes.keys) {
      _outcomes[id] = AttendanceOutcome.absent;
    }
  });

  Future<void> _submit() async {
    final missing = _outcomes.entries.where((e) => e.value == null);
    if (missing.isNotEmpty) {
      final name = widget.options
          .firstWhere((o) => o.membershipId == missing.first.key)
          .fullName;
      setState(() => _problem = 'Choose an outcome for $name.');
      return;
    }
    final draft = _draft!;
    final problem = draft.problem(_now);
    setState(() => _problem = problem);
    if (problem != null) return;

    final ok = await ref
        .read(recordMeetingControllerProvider.notifier)
        .record(draft);
    if (!ok || !mounted) return;
    final names = [
      for (final id in draft.outcomes.keys) draft.names[id] ?? 'Disciple',
    ];
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Meeting recorded for ${names.join(', ')}')),
    );
    await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(recordMeetingControllerProvider);
    final draft = _draft;
    final error = _problem ?? state.error?.message;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The lesson, shown, not chosen: one heading, no card.
        Text(
          'Lesson ${_target.lessonNumber}  ·  with ${_target.disciplerName}',
          style: text.bodySmall?.copyWith(color: p.muted),
        ),
        const SizedBox(height: 2),
        Text(
          _target.lessonTitle,
          style: text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeading('When'),
        // Recent days as one row of tabs, the calendar for any other day.
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final day in _quickDays)
                      _DayTab(
                        label: _dayLabel(day),
                        selected: day == _day,
                        onTap: () => setState(() {
                          _day = day;
                          _problem = null;
                        }),
                      ),
                    if (!_quickDays.contains(_day))
                      _DayTab(
                        label: AppFormat.shortDate(_day.toUtc()),
                        selected: true,
                        onTap: _pickDay,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filledTonal(
              tooltip: 'Other date',
              onPressed: _pickDay,
              icon: const Icon(Icons.calendar_month_outlined, size: 20),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        SectionHeading(
          'Who came',
          trailing: AppTextLink(label: 'Nobody came', onTap: _nobodyCame),
        ),
        TileGroup(children: [for (final o in _sameLesson) _participant(o)]),
        for (final o in _otherLesson)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Row(
              children: [
                MemberAvatar(
                  name: o.fullName,
                  membershipId: o.membershipId,
                  radius: 14,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    '${o.fullName} is on Lesson ${o.lessonNumber}; record '
                    'separately.',
                    style: text.bodySmall?.copyWith(color: p.muted),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.lg),

        const SectionHeading('Notes'),
        TextField(
          controller: _notes,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'Optional. The Disciples in this meeting see it.',
            filled: true,
            fillColor: p.surface,
            contentPadding: const EdgeInsets.all(AppSpacing.md),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: p.brand, width: 2),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        if (error != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              error,
              style: AppTypography.supporting.copyWith(color: p.error),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppButton(
          label: 'Record meeting',
          variant: AppButtonVariant.record,
          icon: Icons.check_rounded,
          isLoading: state.isSending,
          requiresConnection: true,
          offlineAction: 'record this meeting',
          onPressed: _submit,
        ),
        // What will be saved, in one quiet line.
        if (draft != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            draft.reviewLine,
            textAlign: TextAlign.center,
            style: text.bodySmall?.copyWith(color: p.muted),
          ),
        ],
      ],
    );
  }

  /// Today and up to six earlier days, never before the first allowed day.
  List<DateTime> get _quickDays => [
    for (var i = 0; i < 7; i++)
      if (!DateTime(
        _today.year,
        _today.month,
        _today.day - i,
      ).isBefore(_firstDay))
        DateTime(_today.year, _today.month, _today.day - i),
  ];

  String _dayLabel(DateTime day) {
    final diff = _today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return MaterialLocalizations.of(context).formatShortMonthDay(day);
  }

  Widget _participant(RecordingOption o) {
    final included = _outcomes.containsKey(o.membershipId);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MemberAvatar(
                name: o.fullName,
                membershipId: o.membershipId,
                radius: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  o.fullName,
                  style: text.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (!o.isTarget)
                Semantics(
                  label: 'Include ${o.fullName}',
                  toggled: included,
                  excludeSemantics: true,
                  child: Switch(
                    value: included,
                    onChanged: (v) => setState(() {
                      if (v) {
                        _outcomes[o.membershipId] = null;
                      } else {
                        _outcomes.remove(o.membershipId);
                      }
                    }),
                  ),
                ),
            ],
          ),
          if (included) ...[
            const SizedBox(height: AppSpacing.sm),
            OutcomeSelector(
              personName: o.fullName,
              value: _outcomes[o.membershipId],
              onChanged: (v) => setState(() {
                _outcomes[o.membershipId] = v;
                _problem = null;
              }),
            ),
          ],
        ],
      ),
    );
  }
}

/// A day to record on, as a tab: text, and a thin lime outline when
/// chosen (as the Members and history tabs).
class _DayTab extends StatelessWidget {
  const _DayTab({
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
          height: 38,
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
