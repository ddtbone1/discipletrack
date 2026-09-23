import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_page_header.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/error_state.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../../auth/application/auth_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/join_church_controller.dart';
import '../domain/join_code.dart';
import '../domain/onboarding_steps.dart';
import 'onboarding_timeline.dart';

/// Where an authenticated user without a church membership lands.
///
/// MVP_SPEC section 11: Enter Join Code -> Confirm Church -> Request
/// Membership. The code identifies the church the person wants to join; it
/// grants nothing by itself. The church's name is shown and confirmed before
/// any request is created, and the request lands as PENDING for the church to
/// review.
class JoinChurchPage extends ConsumerStatefulWidget {
  const JoinChurchPage({super.key});

  @override
  ConsumerState<JoinChurchPage> createState() => _JoinChurchPageState();
}

class _JoinChurchPageState extends ConsumerState<JoinChurchPage> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    FocusScope.of(context).unfocus();
    await ref.read(joinChurchControllerProvider.notifier).lookup(_code.text);
  }

  Future<void> _join() =>
      ref.read(joinChurchControllerProvider.notifier).confirm();

  void _notMyChurch() =>
      ref.read(joinChurchControllerProvider.notifier).reset();

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(myProfileProvider).value;
    final signingOut = ref.watch(authControllerProvider).isLoading;
    final join = ref.watch(joinChurchControllerProvider);

    final steps = onboardingSteps(OnboardingStage.join);

    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.md),
          AppPageHeader(
            greeting: 'Hello, ${profile?.firstName ?? 'friend'}',
            subtitle: 'One step left before you begin',
            onAvatarTap: () => context.go(Routes.profile),
            actions: const [ThemeModeToggle()],
          ),
          const SizedBox(height: AppSpacing.xl),

          Text('Join your church', style: AppTypography.pageTitle),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Your church gives you a join code. Once your request is '
            'approved, your D Group, lessons and gatherings appear here.',
            style: context.supportingStyle,
          ),
          const SizedBox(height: AppSpacing.lg),

          OnboardingTimeline(
            steps: steps,
            detailFor: (step) => step.title == 'Join church'
                ? (join.phase == JoinPhase.found ||
                          join.phase == JoinPhase.submitting
                      ? _ChurchFoundCard(
                          churchName: join.church!.name,
                          error: join.error,
                          isSubmitting: join.phase == JoinPhase.submitting,
                          onJoin: _join,
                          onNotMyChurch: _notMyChurch,
                        )
                      : _JoinCodeCard(
                          controller: _code,
                          error: join.error,
                          isLookingUp: join.phase == JoinPhase.lookingUp,
                          onFind: _find,
                        ))
                : null,
          ),

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Sign out',
            variant: AppButtonVariant.text,
            isLoading: signingOut,
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

/// Uppercases as you type and drops anything outside the code alphabet or a
/// separator, so what is shown is what will be sent.
class _JoinCodeFormatter extends TextInputFormatter {
  const _JoinCodeFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    for (final rune in newValue.text.runes) {
      final char = String.fromCharCode(rune);
      if (isJoinCodeCharacter(char)) {
        buffer.write(char.toUpperCase());
      } else if (char == ' ' || char == '-') {
        buffer.write(char);
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Step 3's action while no church has been found yet.
class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({
    required this.controller,
    required this.error,
    required this.isLookingUp,
    required this.onFind,
  });

  final TextEditingController controller;
  final String? error;
  final bool isLookingUp;
  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      fill: AppCardFill.plain,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            InlineError(message: error!),
            const SizedBox(height: AppSpacing.sm),
          ],
          AppTextField(
            label: 'JOIN CODE',
            controller: controller,
            hint: 'e.g. ABCD2EFGH3',
            enabled: !isLookingUp,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.search,
            textCapitalization: TextCapitalization.characters,
            autofillHints: const [],
            inputFormatters: const [_JoinCodeFormatter()],
            textStyle: AppTypography.body.copyWith(
              fontSize: 20,
              letterSpacing: 3,
              fontWeight: FontWeight.w600,
            ),
            onSubmitted: (_) => onFind(),
          ),
          AppButton(
            label: 'Find church',
            icon: Icons.search_rounded,
            isLoading: isLookingUp,
            onPressed: isLookingUp ? null : onFind,
          ),
        ],
      ),
    );
  }
}

/// Step 3's confirmation once the code resolved. The person confirms the
/// church by name before any request exists.
class _ChurchFoundCard extends StatelessWidget {
  const _ChurchFoundCard({
    required this.churchName,
    required this.error,
    required this.isSubmitting,
    required this.onJoin,
    required this.onNotMyChurch,
  });

  final String churchName;
  final String? error;
  final bool isSubmitting;
  final VoidCallback onJoin;
  final VoidCallback onNotMyChurch;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    const fill = AppCardFill.mint;

    return AppCard(
      fill: fill,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            InlineError(message: error!),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.church_outlined, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Church found',
                      style: AppTypography.caption.copyWith(
                        color: fill.foregroundMuted(p),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      churchName,
                      style: AppTypography.sectionTitle.copyWith(
                        color: fill.foreground(p),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Is this your church? Your request goes to its leaders for '
            'approval.',
            style: AppTypography.supporting.copyWith(
              color: fill.foregroundMuted(p),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Join church',
            icon: Icons.check_rounded,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onJoin,
          ),
          const SizedBox(height: AppSpacing.xs),
          AppButton(
            label: 'Not my church',
            variant: AppButtonVariant.text,
            onPressed: isSubmitting ? null : onNotMyChurch,
          ),
        ],
      ),
    );
  }
}
