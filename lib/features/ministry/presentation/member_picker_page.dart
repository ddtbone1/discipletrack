import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/connectivity/connection_status.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_pill.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../application/ministry_providers.dart';
import '../application/ministry_structure_controller.dart';
import '../domain/member_option.dart';
import 'ministry_ui.dart';

/// Chooses the Leader of a new group, or the replacement Leader of an
/// existing one ([MemberPickPurpose.appointLeader]). Picking a person pops
/// with the chosen [MemberOption]; the caller performs the appointment.
///
/// Everyone the database returns is listed. Those who cannot be chosen are
/// shown disabled with the reason, rather than hidden, so a Coordinator can
/// see why someone is missing from the choices.
class MemberPickerPage extends ConsumerStatefulWidget {
  const MemberPickerPage({
    required this.purpose,
    this.groupId,
    this.title,
    super.key,
  });

  final MemberPickPurpose purpose;

  /// The group being acted on; null when choosing the Leader of a new group.
  final String? groupId;
  final String? title;

  @override
  ConsumerState<MemberPickerPage> createState() => _MemberPickerPageState();
}

class _MemberPickerPageState extends ConsumerState<MemberPickerPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _pick(MemberOption option) => Navigator.of(context).pop(option);

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(placeableMembersProvider(widget.groupId));
    final structure = ref.watch(ministryStructureControllerProvider);
    final title = widget.title ?? 'Choose a Leader';

    return AppScaffold(
      title: title,
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          if (structure.error != null) ...[
            InlineError(message: structure.error!.message),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            label: 'Search',
            leadingIcon: Icons.search_rounded,
            controller: _search,
            hint: 'Search by name, e.g. Maria',
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
          members.when(
            loading: () => const SizedBox(height: 240, child: LoadingState()),
            error: (e, _) => SizedBox(
              height: 240,
              child: ErrorState.load(
                subject: 'the members you can choose from',
                error: e,
                onRetry: () =>
                    ref.invalidate(placeableMembersProvider(widget.groupId)),
              ),
            ),
            data: (all) {
              final shown = [
                for (final m in all)
                  if (_query.isEmpty ||
                      m.fullName.toLowerCase().contains(_query))
                    m,
              ];
              if (all.isEmpty) {
                return Text(
                  'There are no active members to choose from.',
                  style: context.supportingStyle,
                );
              }
              if (shown.isEmpty) {
                return Text(
                  'No one matches "${_search.text.trim()}".',
                  style: context.supportingStyle,
                );
              }
              return TileGroup(
                children: [
                  for (final m in shown)
                    _OptionRow(
                      option: m,
                      reason: m.ineligibilityReason(
                        widget.purpose,
                        dGroupId: widget.groupId,
                      ),
                      busy: false,
                      // Choosing someone is a change, so not offline.
                      enabled:
                          !structure.isBusy &&
                          !ConnectionScope.isOffline(context),
                      onTap: () => _pick(m),
                    ),
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

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.reason,
    required this.busy,
    required this.enabled,
    required this.onTap,
  });

  final MemberOption option;

  /// Why the option cannot be chosen; null when it can.
  final String? reason;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selectable = reason == null;
    return Opacity(
      opacity: selectable ? 1 : 0.55,
      child: PersonRow(
        name: option.fullName,
        detail: reason ?? option.placementLabel ?? 'Not in a D Group',
        trailing: busy
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : (selectable
                  ? Icon(Icons.chevron_right_rounded, color: p.muted)
                  : null),
        onTap: selectable && enabled ? onTap : null,
      ),
    );
  }
}
