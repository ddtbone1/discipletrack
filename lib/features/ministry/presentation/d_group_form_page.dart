import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/info_group.dart';
import '../application/ministry_providers.dart';
import '../application/ministry_structure_controller.dart';
import '../domain/member_option.dart';
import 'member_picker_page.dart';

/// A new D Group: name, optional description, and its Leader.
///
/// The Coordinator creates each group together with its Leader (Plan
/// decision 2), so the form cannot be submitted without one. Name uniqueness
/// and Leader eligibility are checked again by `create_d_group()`.
class DGroupFormPage extends ConsumerStatefulWidget {
  const DGroupFormPage({super.key});

  @override
  ConsumerState<DGroupFormPage> createState() => _DGroupFormPageState();
}

class _DGroupFormPageState extends ConsumerState<DGroupFormPage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  MemberOption? _leader;
  String? _nameError;
  String? _leaderError;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _chooseLeader() async {
    final picked = await Navigator.of(context).push<MemberOption>(
      MaterialPageRoute(
        builder: (_) =>
            const MemberPickerPage(purpose: MemberPickPurpose.appointLeader),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _leader = picked;
        _leaderError = null;
      });
    }
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    setState(() {
      _nameError = name.isEmpty ? 'Enter a name for the group' : null;
      _leaderError = _leader == null ? 'Choose the group\'s Leader' : null;
    });
    if (_nameError != null || _leaderError != null) return;
    FocusScope.of(context).unfocus();

    final id = await ref
        .read(ministryStructureControllerProvider.notifier)
        .createGroup(
          name: name,
          description: _description.text.trim().isEmpty
              ? null
              : _description.text.trim(),
          leaderMembershipId: _leader!.churchMembershipId,
        );
    if (id != null && mounted) {
      context.pushReplacement(Routes.dGroupDetailFor(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final structure = ref.watch(ministryStructureControllerProvider);
    final isCoordinator = ref.watch(isCoordinatorProvider);
    final busy = structure.isRunning('create');
    final p = context.palette;

    return AppScaffold(
      title: 'New D Group',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          if (!isCoordinator) ...[
            const InlineError(
              message: 'Only your church Coordinator can create D Groups.',
            ),
            const SizedBox(height: AppSpacing.md),
          ] else if (structure.error != null) ...[
            InlineError(message: structure.error!.message),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            label: 'GROUP NAME',
            controller: _name,
            hint: 'e.g. Young Adults A',
            errorText: _nameError,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !busy,
          ),
          AppTextField(
            label: 'DESCRIPTION (OPTIONAL)',
            controller: _description,
            hint: 'e.g. Ages 18 to 30, Thursdays 7 PM at the fellowship hall',
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            enabled: !busy,
          ),
          InfoGroup(
            title: 'Leader',
            rows: [
              InfoRow(
                label: _leader == null ? 'Choose a Leader' : 'Leader',
                value: _leader?.fullName,
                icon: Icons.person_outline,
                onTap: busy || !isCoordinator ? null : _chooseLeader,
              ),
            ],
          ),
          SizedBox(
            height: AppSpacing.errorSlot + AppSpacing.xs,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xxs,
                top: AppSpacing.xxs,
              ),
              child: _leaderError == null
                  ? null
                  : Text(
                      _leaderError!,
                      style: AppTypography.caption.copyWith(color: p.error),
                    ),
            ),
          ),
          Text(
            'The Leader must not already be in a D Group. They lead this '
            'group and can invite members into it.',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Create group',
            requiresConnection: true,
            isLoading: busy,
            onPressed: !isCoordinator || structure.isBusy ? null : _submit,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
