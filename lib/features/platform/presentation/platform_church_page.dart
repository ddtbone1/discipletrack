import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/info_group.dart';
import '../../../core/widgets/loading_state.dart';
import '../../membership/domain/church_membership.dart';
import '../../membership/presentation/join_code_card.dart';
import '../application/platform_providers.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';
import 'platform_ui.dart';

/// One church in the Platform area (UI_DESIGN_SYSTEM section 70): its
/// status, code, counts and Coordinators, and the platform actions the
/// status allows. Every change is confirmed first and checked again by the
/// database; an archived church shows no actions.
class PlatformChurchPage extends ConsumerStatefulWidget {
  const PlatformChurchPage({required this.churchId, super.key});

  final String churchId;

  @override
  ConsumerState<PlatformChurchPage> createState() => _PlatformChurchPageState();
}

class _PlatformChurchPageState extends ConsumerState<PlatformChurchPage> {
  bool _busy = false;

  PlatformRepository get _repo => ref.read(platformRepositoryProvider);

  /// Runs [action], then reloads the church and its activity, and names the
  /// change in a snackbar. A refusal is shown in its own words.
  Future<void> _run(Future<void> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action();
      ref
        ..invalidate(platformChurchesProvider)
        ..invalidate(platformEventsProvider(widget.churchId));
      messenger.showSnackBar(SnackBar(content: Text(success)));
    } on PlatformFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _regenerate(PlatformChurch church) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Change the join code?',
      message:
          'The current code stops working at once. Requests already sent '
          'stay waiting for the Coordinator.',
      confirmLabel: 'Change code',
    );
    if (!ok) return;
    await _run(() => _repo.regenerateJoinCode(church.id), 'Join code changed');
  }

  Future<void> _addCoordinator(PlatformChurch church) async {
    final email = await confirmCoordinatorAccount(
      context,
      churchId: church.id,
      title: 'Add a Coordinator',
      confirmLabel: 'Add Coordinator',
      question: (name, email) =>
          'Make $name ($email) a Coordinator of ${church.name}?',
    );
    if (email == null) return;
    await _run(
      () => _repo.assignCoordinator(church.id, email),
      'Coordinator added',
    );
  }

  Future<void> _replace(PlatformChurch church, CoordinatorRef current) async {
    final email = await confirmCoordinatorAccount(
      context,
      churchId: church.id,
      title: 'Replace ${current.fullName}',
      confirmLabel: 'Replace',
      question: (name, email) =>
          'Make $name ($email) the Coordinator of ${church.name} in place of '
          '${current.fullName}? ${current.fullName} stays a member.',
    );
    if (email == null) return;
    await _run(
      () => _repo.replaceCoordinator(
        church.id,
        currentMembershipId: current.membershipId,
        email: email,
      ),
      'Coordinator replaced',
    );
  }

  Future<void> _remove(PlatformChurch church, CoordinatorRef c) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove ${c.fullName} as Coordinator?',
      message:
          '${c.fullName} stays a member of ${church.name}. The other '
          'Coordinators keep their role.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    await _run(
      () => _repo.endCoordinator(church.id, c.membershipId),
      'Coordinator removed',
    );
  }

  Future<void> _setStatus(PlatformChurch church, ChurchStatus to) async {
    final (title, message, label, success) = switch (to) {
      ChurchStatus.suspended => (
        'Suspend ${church.name}?',
        "Members can still sign in but won't see the church, and nobody can "
            'act in it until you reactivate it. Nothing is deleted.',
        'Suspend',
        'Church suspended',
      ),
      ChurchStatus.active => (
        'Reactivate ${church.name}?',
        'Everything returns exactly as it was before the suspension.',
        'Reactivate',
        'Church reactivated',
      ),
      ChurchStatus.archived => (
        'Archive ${church.name}?',
        "Archiving is final in the app. Everything is kept, but the church "
            "can't be reopened here.",
        'Archive',
        'Church archived',
      ),
    };
    final ok = await showConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: label,
      destructive: to == ChurchStatus.archived,
    );
    if (!ok) return;
    await _run(() => _repo.setStatus(church.id, to), success);
  }

  @override
  Widget build(BuildContext context) {
    final church = ref.watch(platformChurchProvider(widget.churchId));

    return AppScaffold(
      title: church.value?.name ?? 'Church',
      showBackButton: true,
      backFallback: Routes.platform,
      child: church.when(
        loading: () => const SizedBox(height: 320, child: LoadingState()),
        error: (e, _) => SizedBox(
          height: 320,
          child: ErrorState.load(
            subject: 'this church',
            error: e,
            onRetry: () => ref.invalidate(platformChurchesProvider),
          ),
        ),
        data: (c) => c == null
            ? const EmptyState(
                title: 'Church not found',
                message: "This church isn't on the platform list.",
              )
            : _body(context, c),
      ),
    );
  }

  Widget _body(BuildContext context, PlatformChurch c) {
    final editable = !c.isArchived;
    final events = ref.watch(platformEventsProvider(c.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            ChurchStatusPill(status: c.status),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Created ${AppFormat.shortDate(c.createdAt)}',
              style: context.captionStyle,
            ),
          ],
        ),
        if (c.status == ChurchStatus.suspended) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Suspended: members see that the church is unavailable, and '
            'nobody can act in it.',
            style: context.supportingStyle,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        InfoGroup(
          title: 'Counts',
          rows: [
            InfoRow(label: 'Members', value: '${c.membersActive}'),
            InfoRow(label: 'Waiting to join', value: '${c.membersPending}'),
            InfoRow(label: 'D Groups', value: '${c.dGroups}'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        JoinCodeCard(
          code: ChurchJoinCode(code: c.joinCode, setAt: c.joinCodeSetAt),
          footnote: c.joinCodeSetAt == null
              ? null
              : 'Set ${AppFormat.shortDate(c.joinCodeSetAt!)}',
        ),
        if (editable) ...[
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Regenerate code',
            icon: Icons.refresh_rounded,
            variant: AppButtonVariant.secondary,
            requiresConnection: true,
            offlineAction: 'change the join code',
            onPressed: _busy ? null : () => _regenerate(c),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Coordinators', style: AppTypography.sectionTitle),
        const SizedBox(height: AppSpacing.xs),
        for (final co in c.coordinators)
          _CoordinatorRow(
            coordinator: co,
            onReplace: editable && !_busy ? () => _replace(c, co) : null,
            onRemove: editable && !_busy && c.coordinators.length > 1
                ? () => _remove(c, co)
                : null,
          ),
        if (editable)
          AppButton(
            label: 'Add Coordinator',
            icon: Icons.person_add_alt_1_outlined,
            variant: AppButtonVariant.text,
            requiresConnection: true,
            offlineAction: 'add a Coordinator',
            onPressed: _busy ? null : () => _addCoordinator(c),
          ),
        if (editable) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Status', style: AppTypography.sectionTitle),
          const SizedBox(height: AppSpacing.xs),
          if (c.status == ChurchStatus.active)
            // Colour tells the story (UI_DESIGN_SYSTEM section 61): a
            // reversible pause in the warning tone, the way back as the one
            // lime action, the final step in the error tone.
            AppButton(
              label: 'Suspend church',
              icon: Icons.pause_circle_outline_rounded,
              variant: AppButtonVariant.caution,
              requiresConnection: true,
              offlineAction: 'suspend the church',
              onPressed: _busy
                  ? null
                  : () => _setStatus(c, ChurchStatus.suspended),
            ),
          if (c.status == ChurchStatus.suspended)
            AppButton(
              label: 'Reactivate church',
              icon: Icons.play_circle_outline_rounded,
              requiresConnection: true,
              offlineAction: 'reactivate the church',
              onPressed: _busy
                  ? null
                  : () => _setStatus(c, ChurchStatus.active),
            ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Archive church',
            icon: Icons.archive_outlined,
            variant: AppButtonVariant.destructive,
            requiresConnection: true,
            offlineAction: 'archive the church',
            onPressed: _busy
                ? null
                : () => _setStatus(c, ChurchStatus.archived),
          ),
        ] else ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            "This church is archived, so it can't be changed. Its records "
            'are kept.',
            style: context.supportingStyle,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        events.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : InfoGroup(
                  title: 'Activity',
                  rows: [
                    for (final e in list)
                      InfoRow(
                        label: e.label,
                        value: [
                          AppFormat.shortDate(e.at),
                          if (e.actorName != null) 'by ${e.actorName}',
                        ].join(' · '),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _CoordinatorRow extends StatelessWidget {
  const _CoordinatorRow({
    required this.coordinator,
    required this.onReplace,
    required this.onRemove,
  });

  final CoordinatorRef coordinator;
  final VoidCallback? onReplace;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, color: p.textPrimary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coordinator.fullName,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
                Text(coordinator.email, style: context.captionStyle),
              ],
            ),
          ),
          if (onReplace != null || onRemove != null)
            PopupMenuButton<String>(
              tooltip: 'Coordinator actions',
              onSelected: (v) =>
                  v == 'replace' ? onReplace?.call() : onRemove?.call(),
              itemBuilder: (_) => [
                if (onReplace != null)
                  const PopupMenuItem(value: 'replace', child: Text('Replace')),
                if (onRemove != null)
                  PopupMenuItem(
                    value: 'remove',
                    child: Text(
                      'Remove',
                      style: TextStyle(color: context.palette.error),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
