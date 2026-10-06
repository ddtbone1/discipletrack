import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/format/app_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../application/ministry_providers.dart';
import '../application/ministry_structure_controller.dart';
import '../domain/d_group_placement.dart';

/// Adds members to a D Group (route `/groups/:groupId/add-members`).
///
/// A full screen rather than a sheet, because a church may have a couple of
/// hundred members: search narrows the list, rows are built lazily, and the
/// selection stays visible in a bar pinned to the bottom.
///
/// Who is listed is decided by `list_addable_members()`: ACTIVE members of
/// the church in no D Group. The search only narrows that list by name; it
/// grants nothing. Adding is all or nothing, and the database refuses anyone
/// placed meanwhile by another Leader, so a refusal refreshes the list.
///
/// Pops with the number of people added, or null when nothing was added.
class AddMembersPage extends ConsumerStatefulWidget {
  const AddMembersPage({required this.groupId, super.key});

  final String groupId;

  @override
  ConsumerState<AddMembersPage> createState() => _AddMembersPageState();
}

class _AddMembersPageState extends ConsumerState<AddMembersPage> {
  final _search = TextEditingController();
  String _query = '';
  final _selected = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toggle(String id) => setState(() {
    if (!_selected.remove(id)) _selected.add(id);
  });

  Future<void> _add(List<AddableMember> available) async {
    // Only people still listed: a refresh may have removed someone.
    final ids = [
      for (final m in available)
        if (_selected.contains(m.churchMembershipId)) m.churchMembershipId,
    ];
    if (ids.isEmpty) return;
    final ok = await ref
        .read(ministryStructureControllerProvider.notifier)
        .addMembers(widget.groupId, ids);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(ids.length);
    } else {
      // The list was refreshed on a conflict; drop anyone no longer in it
      // when it arrives (see build).
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(addableMembersProvider(widget.groupId));
    final structure = ref.watch(ministryStructureControllerProvider);
    final groupName = ref
        .watch(dGroupDetailProvider(widget.groupId))
        .value
        ?.group
        .name;
    final available = members.value ?? const <AddableMember>[];
    // Keep the selection to people still listed.
    final availableIds = {for (final m in available) m.churchMembershipId};
    if (members.hasValue) _selected.retainAll(availableIds);

    return AppScaffold(
      title: 'Add members',
      showBackButton: true,
      scrollable: false,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.md,
              AppSpacing.page,
              AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  groupName == null
                      ? 'Choose who joins this group. They start with no role '
                            'until you set them up.'
                      : 'Choose who joins $groupName. They start with no role '
                            'until you set them up.',
                  style: context.supportingStyle,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (structure.error != null) ...[
                  InlineError(message: structure.error!.message),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppTextField(
                  label: 'Search',
                  leadingIcon: Icons.search_rounded,
                  controller: _search,
                  hint: 'Search by name',
                  textInputAction: TextInputAction.search,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ],
            ),
          ),
          Expanded(
            child: members.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState.load(
                subject: 'the members you can add',
                error: e,
                onRetry: () =>
                    ref.invalidate(addableMembersProvider(widget.groupId)),
              ),
              data: (all) => _MemberList(
                all: all,
                query: _query,
                rawQuery: _search.text.trim(),
                selected: _selected,
                enabled: !structure.isBusy,
                onToggle: _toggle,
              ),
            ),
          ),
          _SelectionBar(
            count: _selected.length,
            busy: structure.isRunning('add:${widget.groupId}'),
            enabled: !structure.isBusy,
            onClear: () => setState(_selected.clear),
            onAdd: () => _add(available),
          ),
        ],
      ),
    );
  }
}

class _MemberList extends StatelessWidget {
  const _MemberList({
    required this.all,
    required this.query,
    required this.rawQuery,
    required this.selected,
    required this.enabled,
    required this.onToggle,
  });

  final List<AddableMember> all;
  final String query;
  final String rawQuery;
  final Set<String> selected;
  final bool enabled;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    if (all.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.page),
        child: EmptyState(
          illustration: Illustration.complete,
          icon: Icons.groups_2_outlined,
          title: 'Everyone is already in a D Group',
          message:
              'New members appear here once their request to join the church '
              'is approved.',
        ),
      );
    }
    final shown = [
      for (final m in all)
        if (query.isEmpty || m.fullName.toLowerCase().contains(query)) m,
    ];
    final offline = ConnectionScope.isOffline(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.page,
            AppSpacing.xs,
            AppSpacing.page,
            AppSpacing.xs,
          ),
          child: Text(
            query.isEmpty
                ? '${AppFormat.count(all.length, 'member')} in no D Group'
                : '${shown.length} of ${all.length} '
                      '${shown.length == 1 ? 'matches' : 'match'}',
            style: context.captionStyle,
          ),
        ),
        Expanded(
          child: shown.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.page,
                  ),
                  child: Text(
                    'No one matches "$rawQuery".',
                    style: context.supportingStyle,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  itemCount: shown.length,
                  itemBuilder: (context, i) {
                    final m = shown[i];
                    return _MemberTile(
                      member: m,
                      selected: selected.contains(m.churchMembershipId),
                      enabled: enabled && !offline,
                      onTap: () => onToggle(m.churchMembershipId),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final AddableMember member;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final joined = member.joinedAt;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.brand.withValues(alpha: 0.16) : Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: selected
                      ? CircleAvatar(
                          key: const ValueKey('on'),
                          radius: 20,
                          backgroundColor: p.brand,
                          child: Icon(
                            Icons.check_rounded,
                            color: p.onBrand,
                            size: 22,
                          ),
                        )
                      : InitialsAvatar(
                          key: const ValueKey('off'),
                          name: member.fullName,
                        ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.fullName,
                        style: Theme.of(context).textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (joined != null)
                        Text(
                          'Member since ${AppFormat.monthYear(joined.toLocal())}',
                          style: context.captionStyle,
                        ),
                    ],
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: enabled ? (_) => onTap() : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The pinned bottom bar: how many are chosen, a way to clear them, and the
/// one primary action.
class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.busy,
    required this.enabled,
    required this.onClear,
    required this.onAdd,
  });

  final int count;
  final bool busy;
  final bool enabled;
  final VoidCallback onClear;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.sm,
          AppSpacing.page,
          AppSpacing.sm,
        ),
        child: Row(
          children: [
            Expanded(
              child: count == 0
                  ? Text('No one chosen yet', style: context.supportingStyle)
                  : Row(
                      children: [
                        Flexible(
                          child: Text(
                            '$count chosen',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        TextButton(
                          onPressed: enabled ? onClear : null,
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
            ),
            AppButton(
              label: count <= 1 ? 'Add' : 'Add $count',
              icon: Icons.person_add_alt_1_rounded,
              requiresConnection: true,
              expand: false,
              isLoading: busy,
              onPressed: count == 0 || !enabled ? null : onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
