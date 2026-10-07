import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/person_row.dart';
import '../../ministry/application/ministry_providers.dart';
import '../application/curriculum_providers.dart';
import '../data/curriculum_repository.dart';
import '../domain/lesson_content.dart';
import '../domain/workbook.dart';
import 'full_lesson_view.dart';

/// One lesson, read in the tiers the database allowed (ADR-019).
///
/// The reader only lays out what `get_lesson_content()` returned: the
/// Disciple tier as lettered sections, and the Discipler tier, when it is
/// present, in its own group. It never decides access itself. Block types
/// it does not know render nothing.
class LessonReaderPage extends ConsumerStatefulWidget {
  const LessonReaderPage({
    required this.lessonId,
    this.forMembershipId,
    super.key,
  });

  final String lessonId;
  final String? forMembershipId;

  @override
  ConsumerState<LessonReaderPage> createState() => _LessonReaderPageState();
}

class _LessonReaderPageState extends ConsumerState<LessonReaderPage> {
  /// For someone who is both a Disciple and a Discipler, reading their own
  /// lesson: whether they chose to see the book's answers (ADR-021).
  bool _showAnswers = false;
  bool _checking = false;

  Future<void> _check(LessonContent lesson, Workbook workbook) async {
    final responses = {
      for (final b in lesson.checkable)
        b.blockId: workbook.blanksOf(b.blockId, b.blankCount),
    }..removeWhere((_, v) => v.every((x) => x.isEmpty));
    final messenger = ScaffoldMessenger.of(context);
    if (responses.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Fill in some blanks first.')),
      );
      return;
    }
    setState(() => _checking = true);
    try {
      final results = await ref
          .read(curriculumRepositoryProvider)
          .checkAnswers(widget.lessonId, responses);
      workbook.showResults(results);
      final right = results.where((r) => r.result.correct).length;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '$right of ${results.length} right. '
            '${right == results.length ? 'Well done.' : 'The answers are shown under the others.'}',
          ),
        ),
      );
    } on CurriculumFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lessonId = widget.lessonId;
    final forMembershipId = widget.forMembershipId;
    final key = (lessonId: lessonId, forMembershipId: forMembershipId);
    final content = ref.watch(lessonContentProvider(key));
    final access = ref
        .watch(lessonAccessProvider(forMembershipId))
        .value
        ?.where((l) => l.lessonId == lessonId)
        .firstOrNull;
    // Reading their own lesson as a Disciple; a Leader or Discipler who is
    // not a Disciple reads the book with its answers (ADR-020).
    final ownJourney =
        forMembershipId == null &&
        (ref.watch(myMinistryContextProvider).value?.isDisciple ?? false);

    return AppScaffold(
      title: access == null ? 'Lesson' : 'Lesson ${access.number}',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          content.when(
            loading: () => const SizedBox(height: 320, child: LoadingState()),
            error: (e, _) => e is CurriculumFailure && e.isRefused
                ? const EmptyState.restricted(
                    title: "This lesson isn't open",
                    message:
                        'A lesson opens when the journey reaches it. Until '
                        'then it stays closed, for the Disciple and for the '
                        'people who walk with them.',
                  )
                : SizedBox(
                    height: 320,
                    child: ErrorState.load(
                      subject: 'this lesson',
                      error: e,
                      onRetry: () => ref.invalidate(lessonContentProvider(key)),
                    ),
                  ),
            data: (full) {
              final both = ownJourney && full.hasAnswers;
              final lesson = both && !_showAnswers ? full.discipleView : full;
              // Only the reader's own lesson, as a Disciple, is written in.
              final workbook = forMembershipId == null && !lesson.hasAnswers
                  ? ref.watch(workbookProvider(lessonId)).value
                  : null;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (both)
                    _AnswersSwitch(
                      value: _showAnswers,
                      onChanged: (v) => setState(() => _showAnswers = v),
                    ),
                  LessonBody(
                    lesson: lesson,
                    access: access,
                    workbook: workbook,
                  ),
                  if (workbook != null && lesson.checkable.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      label: 'Check my answers',
                      icon: Icons.fact_check_outlined,
                      isLoading: _checking,
                      requiresConnection: true,
                      offlineAction: 'check your answers',
                      onPressed: () => _check(lesson, workbook),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Compares your blanks with the book. Nothing is '
                      'graded or sent to anyone.',
                      textAlign: TextAlign.center,
                      style: context.captionStyle,
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// "Show answers": for a Disciple who is also a Discipler, in their own
/// lesson.
class _AnswersSwitch extends StatelessWidget {
  const _AnswersSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            value ? 'Showing the answers' : 'Answer it yourself first',
            style: context.supportingStyle,
          ),
        ),
        Text('Show answers', style: context.captionStyle),
        const SizedBox(width: AppSpacing.xs),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}

/// The lesson laid out for reading. Public for widget tests and previews.
class LessonBody extends StatelessWidget {
  const LessonBody({
    required this.lesson,
    this.access,
    this.workbook,
    super.key,
  });

  final LessonContent lesson;
  final LessonAccess? access;

  /// The reader's own answers, when they may write in this lesson.
  final Workbook? workbook;

  static const _metadataTypes = {
    BlockType.lessonTheme,
    BlockType.topicList,
    BlockType.sectionHeading,
    BlockType.scriptureReferences,
    BlockType.moduleHeading,
  };

  @override
  Widget build(BuildContext context) {
    final metadataOnly = lesson.blocks.every(
      (b) => _metadataTypes.contains(b.type) || b.type == BlockType.unknown,
    );
    final topics = lesson.topics;
    final sections = lesson.sections;
    final discipler = lesson.disciplerBlocks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: access?.title, theme: lesson.theme),
        if (lesson.isFull) ...[
          if (lesson.topics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeading('What this lesson covers'),
            AppCard(child: _BulletList(items: lesson.topics)),
          ],
          if (workbook != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.edit_note_rounded,
                  size: 20,
                  color: context.palette.muted,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Tap a blank to write your answer. Saved on this phone only.',
                    style: context.captionStyle,
                  ),
                ),
              ],
            ),
          ],
          FullLessonView(lesson: lesson, workbook: workbook),
        ] else ...[
          if (metadataOnly) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The full lesson is in your printed Journey book. This page '
              'lists what it covers and the scriptures it uses.',
              style: context.supportingStyle,
            ),
          ],
          if (topics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeading('What this lesson covers'),
            AppCard(child: _BulletList(items: topics)),
          ],
          for (final s in sections) ...[
            const SizedBox(height: AppSpacing.lg),
            SectionHeading(
              s.title == null
                  ? 'Section ${s.label}'
                  : 'Section ${s.label} · ${s.title}',
            ),
            AppCard(child: _SectionBody(section: s)),
          ],
          if (discipler.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const SectionHeading('For the Discipler'),
            Text(
              'Visible to the assigned Discipler and the Coordinator only.',
              style: context.captionStyle,
            ),
            const SizedBox(height: AppSpacing.xs),
            AppCard(
              fill: AppCardFill.pastel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final b in discipler) _BlockView(block: b)],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({this.title, this.theme});

  final String? title;
  final String? theme;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title ?? theme ?? 'Lesson',
            style: text.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ),
        if (theme != null && theme != title)
          Text('Theme: $theme', style: context.supportingStyle),
      ],
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});

  final LessonSection section;

  @override
  Widget build(BuildContext context) {
    final refs = section.scriptureRefs;
    final others = [
      for (final b in section.blocks)
        if (b.type != BlockType.sectionHeading &&
            b.type != BlockType.scriptureReferences &&
            b.type != BlockType.unknown)
          b,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in others) _BlockView(block: b),
        if (refs.isNotEmpty) ...[
          Text('Scriptures', style: context.captionStyle),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final r in refs)
                AppPill(label: r, icon: Icons.menu_book_outlined),
            ],
          ),
        ],
        if (refs.isEmpty && others.isEmpty)
          Text(
            'This section is in your printed book.',
            style: context.supportingStyle,
          ),
      ],
    );
  }
}

/// One block. Metadata publications contain only module headings here;
/// the other kinds are laid out generically for a later full publication.
class _BlockView extends StatelessWidget {
  const _BlockView({required this.block});

  final ContentBlock block;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final text = Theme.of(context).textTheme;
    final strong = text.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: p.textPrimary,
    );
    final body = text.bodyLarge?.copyWith(color: p.textPrimary);

    final Widget? child = switch (block.type) {
      BlockType.moduleHeading => Text(
        [
          if (block.body['number'] != null)
            'Training Module ${block.body['number']}',
          ?block.title,
        ].join(' · '),
        style: strong,
      ),
      BlockType.keyObjective ||
      BlockType.banner => Text(block.text ?? '', style: strong),
      BlockType.paragraph ||
      BlockType.scenario ||
      BlockType.disciplerNote => Text(block.text ?? '', style: body),
      BlockType.fillIn => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(block.text ?? '', style: body),
          if (block.answers case final answers? when answers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                'Answer: ${answers.join(', ')}',
                style: context.captionStyle,
              ),
            ),
        ],
      ),
      BlockType.discussionPrompts ||
      BlockType.assignments ||
      BlockType.topicList => _BulletList(items: block.items),
      BlockType.verseWriting => Text(
        [...block.refs, ?block.text].join(' · '),
        style: body,
      ),
      // Full-lesson types are laid out by FullLessonView.
      _ => null,
    };
    if (child == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: child,
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyLarge
        ?.copyWith(color: context.palette.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('•  ', style: style),
                Expanded(child: Text(i, style: style)),
              ],
            ),
          ),
      ],
    );
  }
}
