import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../../core/widgets/person_row.dart';
import '../application/discipleship_providers.dart';
import '../domain/disciple_progress_summary.dart';
import 'discipleship_ui.dart';

/// My Disciples, a body of the Journey page: the people the caller
/// disciples, always a list (one Discipler may have several Disciples).
/// Each row opens the Disciple's detail; the primary action records a
/// meeting.
///
/// Who appears is decided by list_disciple_progress(): the caller's own
/// currently assigned Disciples only (N7). Journey shows this body only to
/// someone with a DISCIPLER row.
class MyDisciplesBody extends ConsumerWidget {
  const MyDisciplesBody({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final disciples = ref.watch(myDisciplesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'The people you disciple. Tap someone to record a meeting or see '
          'their journey.',
          style: context.supportingStyle,
        ),
        const SizedBox(height: AppSpacing.lg),
        disciples.when(
          loading: () => const SizedBox(height: 320, child: LoadingState()),
          error: (e, _) => SizedBox(
            height: 320,
            child: ErrorState.load(
              subject: 'your Disciples',
              error: e,
              onRetry: () => ref.invalidate(myDisciplesProvider),
            ),
          ),
          data: (rows) => rows.isEmpty
              ? const EmptyState(
                  title: 'No Disciples yet',
                  message:
                      'No Disciples are paired with you yet. Your Leader or '
                      'the Coordinator pairs Disciples with you.',
                )
              : _DiscipleList(disciples: rows),
        ),
      ],
    );
  }
}

class _DiscipleList extends StatelessWidget {
  const _DiscipleList({required this.disciples});

  final List<DiscipleProgressSummary> disciples;

  @override
  Widget build(BuildContext context) {
    final recordable = [
      for (final d in disciples)
        if (d.currentLessonNumber != null) d,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (recordable.isNotEmpty) ...[
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
          const SizedBox(height: AppSpacing.lg),
        ],
        const SectionHeading('Longest since last meeting first'),
        TileGroup(
          children: [
            for (final d in disciples)
              DiscipleProgressRow(
                disciple: d,
                onTap: () =>
                    context.push(Routes.discipleDetailFor(d.membershipId)),
              ),
          ],
        ),
      ],
    );
  }
}

/// Choosing who a meeting is for, from Home or My Disciples. Each row shows
/// the lesson the person is on, so who can share a meeting is visible first.
Future<void> showChooseDiscipleSheet(
  BuildContext context,
  List<DiscipleProgressSummary> disciples,
) {
  return showModalBottomSheet<void>(
    context: context,
    // Above the floating dock, which lives in the shell route.
    useRootNavigator: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) {
      final p = sheet.palette;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.xs,
                ),
                child: Text(
                  'Who is this meeting for?',
                  style: AppTypography.sectionTitle.copyWith(
                    color: p.textPrimary,
                  ),
                ),
              ),
              for (final d in disciples)
                PersonRow(
                  name: d.fullName,
                  detail: 'On Lesson ${d.currentLessonNumber}',
                  onTap: () {
                    Navigator.of(sheet).pop();
                    context.push(Routes.recordMeetingFor(d.membershipId));
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}
