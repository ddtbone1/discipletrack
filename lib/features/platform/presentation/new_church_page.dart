import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/step_indicator.dart';
import '../../membership/domain/church_membership.dart';
import '../../membership/presentation/join_code_card.dart';
import '../application/platform_providers.dart';
import '../data/platform_repository.dart';
import '../domain/platform_models.dart';

/// Creating a church with its Coordinator (ADR-022 decision 7) as a stepper
/// of separate pages (UI_DESIGN_SYSTEM sections 60 and 70): the name, then
/// the Coordinator's account (a server check), then a confirmation that
/// names what will be created. Nothing is created before the last step, and
/// then everything is created in one transaction.
const _steps = ['Name', 'Coordinator', 'Confirm'];

/// What the steps have gathered so far.
@immutable
class NewChurchDraft {
  const NewChurchDraft({this.name = '', this.email = '', this.account});

  final String name;
  final String email;

  /// The confirm-step answer for [email]; set only when it can be chosen.
  final AccountPreview? account;
}

class NewChurchDraftController extends Notifier<NewChurchDraft> {
  @override
  NewChurchDraft build() => const NewChurchDraft();

  void setName(String name) => state = NewChurchDraft(name: name.trim());

  void setAccount(String email, AccountPreview account) => state =
      NewChurchDraft(name: state.name, email: email.trim(), account: account);

  void reset() => state = const NewChurchDraft();
}

final newChurchDraftProvider =
    NotifierProvider<NewChurchDraftController, NewChurchDraft>(
      NewChurchDraftController.new,
    );

/// The steps' shared frame: the indicator at the top, a one-line purpose,
/// the step's content, and its action last (section 60, Task / Action).
class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.step,
    required this.title,
    required this.purpose,
    required this.children,
  });

  final int step;
  final String title;
  final String purpose;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppScaffold(
    title: 'New church',
    showBackButton: true,
    backFallback: Routes.platform,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        StepIndicator(steps: _steps, current: step),
        const SizedBox(height: AppSpacing.xl),
        Text(title, style: AppTypography.pageTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(purpose, style: context.supportingStyle),
        const SizedBox(height: AppSpacing.lg),
        ...children,
        const SizedBox(height: AppSpacing.xl),
      ],
    ),
  );
}

/// Step 1: the church's name.
class NewChurchPage extends ConsumerStatefulWidget {
  const NewChurchPage({super.key});

  @override
  ConsumerState<NewChurchPage> createState() => _NewChurchPageState();
}

class _NewChurchPageState extends ConsumerState<NewChurchPage> {
  late final _name = TextEditingController(
    text: ref.read(newChurchDraftProvider).name,
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _next() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(
        () => _error = PlatformFailure.messageFor('church_name_required'),
      );
      return;
    }
    ref.read(newChurchDraftProvider.notifier).setName(name);
    context.push(Routes.platformNewChurchCoordinator);
  }

  @override
  Widget build(BuildContext context) => _StepPage(
    step: 0,
    title: 'Name the church',
    purpose: 'As its members will see it. Its join code is made for it.',
    children: [
      AppTextField(
        label: 'Church name',
        controller: _name,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => _next(),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      if (_error != null) ...[
        const SizedBox(height: AppSpacing.xs),
        InlineError(message: _error!),
      ],
      const SizedBox(height: AppSpacing.lg),
      AppButton(
        label: 'Next',
        icon: Icons.arrow_forward_rounded,
        onPressed: _next,
      ),
    ],
  );
}

/// Step 2: the Coordinator, by the email of an account that already exists
/// (ADR-022 decision 8). The server says whose account it is.
class NewChurchCoordinatorPage extends ConsumerStatefulWidget {
  const NewChurchCoordinatorPage({super.key});

  @override
  ConsumerState<NewChurchCoordinatorPage> createState() =>
      _NewChurchCoordinatorPageState();
}

class _NewChurchCoordinatorPageState
    extends ConsumerState<NewChurchCoordinatorPage> {
  late final _email = TextEditingController(
    text: ref.read(newChurchDraftProvider).email,
  );
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter the email they signed up with.');
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final account = await ref
          .read(platformRepositoryProvider)
          .previewAccount(null, email);
      if (!mounted) return;
      if (account.problem != null) {
        setState(() => _error = account.problem);
        return;
      }
      ref.read(newChurchDraftProvider.notifier).setAccount(email, account);
      context.push(Routes.platformNewChurchConfirm);
    } on PlatformFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(newChurchDraftProvider);
    return _StepPage(
      step: 1,
      title: 'Choose its Coordinator',
      purpose:
          'The email they signed up with. They need a DiscipleTrack account '
          'already; no invitation is sent.',
      children: [
        if (draft.name.isNotEmpty) ...[
          _Fact(icon: Icons.church_outlined, text: draft.name),
          const SizedBox(height: AppSpacing.md),
        ],
        AppTextField(
          label: 'Their email',
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _next(),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          InlineError(message: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Next',
          icon: Icons.arrow_forward_rounded,
          isLoading: _checking,
          requiresConnection: true,
          offlineAction: 'check this email',
          onPressed: _next,
        ),
      ],
    );
  }
}

/// Step 3: what will be created, named, and the one action that creates it.
class NewChurchConfirmPage extends ConsumerStatefulWidget {
  const NewChurchConfirmPage({super.key});

  @override
  ConsumerState<NewChurchConfirmPage> createState() =>
      _NewChurchConfirmPageState();
}

class _NewChurchConfirmPageState extends ConsumerState<NewChurchConfirmPage> {
  bool _creating = false;
  String? _error;

  Future<void> _create(NewChurchDraft draft) async {
    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final created = await ref
          .read(platformRepositoryProvider)
          .createChurch(name: draft.name, coordinatorEmail: draft.email);
      ref.invalidate(platformChurchesProvider);
      if (!mounted) return;
      context.go(
        Routes.platformNewChurchDone,
        extra: (
          churchId: created.churchId,
          churchName: draft.name,
          joinCode: created.joinCode,
          coordinatorName: draft.account?.fullName ?? 'The Coordinator',
        ),
      );
      ref.read(newChurchDraftProvider.notifier).reset();
    } on PlatformFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(newChurchDraftProvider);
    final account = draft.account;
    if (draft.name.isEmpty || account == null) {
      // Reached without the earlier steps (a deep link or a lost draft).
      return _StepPage(
        step: 2,
        title: 'Start from the name',
        purpose: 'This step needs the church name and its Coordinator first.',
        children: [
          AppButton(
            label: 'Start again',
            onPressed: () => context.go(Routes.platformNewChurch),
          ),
        ],
      );
    }
    return _StepPage(
      step: 2,
      title: 'Create ${draft.name}?',
      purpose: 'Check the person: nothing is created until you confirm.',
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Fact(icon: Icons.church_outlined, text: draft.name),
              const SizedBox(height: AppSpacing.sm),
              _Fact(
                icon: Icons.verified_user_outlined,
                text: '${account.fullName}  ·  Coordinator',
                detail: draft.email,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'The church starts active with ${account.fullName} as its '
          'Coordinator, and its join code is made. They go straight to Home '
          'on their next sign-in.',
          style: context.supportingStyle,
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          InlineError(message: _error!),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Create church',
          isLoading: _creating,
          requiresConnection: true,
          offlineAction: 'create a church',
          onPressed: () => _create(draft),
        ),
        const SizedBox(height: AppSpacing.xs),
        AppButton(
          label: 'Not this person',
          variant: AppButtonVariant.text,
          onPressed: _creating ? null : () => context.pop(),
        ),
      ],
    );
  }
}

/// What the done page shows; passed from the confirm step.
typedef CreatedChurch = ({
  String churchId,
  String churchName,
  String joinCode,
  String coordinatorName,
});

/// The church exists: its join code, and where its Coordinator finds it.
class NewChurchDonePage extends StatelessWidget {
  const NewChurchDonePage({required this.created, super.key});

  final CreatedChurch? created;

  @override
  Widget build(BuildContext context) {
    final c = created;
    final first = c?.coordinatorName.split(' ').first;
    return AppScaffold(
      title: 'New church',
      showBackButton: true,
      backFallback: Routes.platform,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xl),
          Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: context.palette.brand,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            c == null ? 'Church created' : '${c.churchName} is ready',
            style: AppTypography.pageTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (c != null) ...[
            JoinCodeCard(code: ChurchJoinCode(code: c.joinCode)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$first can find this code under Profile, Church information, '
              'and share it with the church.',
              style: context.supportingStyle,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Done',
            onPressed: () => c == null
                ? context.go(Routes.platform)
                : context.go(Routes.platformChurchFor(c.churchId)),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// An icon and a fact, with an optional second line.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text, this.detail});

  final IconData icon;
  final String text;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        Icon(icon, size: 22, color: p.textPrimary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: AppTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
              if (detail != null) Text(detail!, style: context.captionStyle),
            ],
          ),
        ),
      ],
    );
  }
}
