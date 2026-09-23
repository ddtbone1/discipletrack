import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/app_button.dart';
import '../core/widgets/app_card.dart';
import '../core/widgets/app_text_field.dart';
import '../core/widgets/error_state.dart';
import '../core/widgets/info_group.dart';
import '../core/widgets/loading_state.dart';
import '../core/widgets/status_pill.dart';
import '../core/widgets/step_list.dart';

/// Previews of the shared UI primitives in every state they can take.
///
/// Run with: flutter widget-preview start

@Preview(name: 'Buttons', group: 'Components', size: Size(420, 720))
Widget buttons() => _Sheet(
  title: 'AppButton',
  children: [
    _Label('Primary (ink fill)'),
    AppButton(label: 'Create account', onPressed: _noop),
    const SizedBox(height: AppSpacing.sm),
    _Label('Primary, loading (same size, no jump)'),
    AppButton(label: 'Create account', isLoading: true, onPressed: _noop),
    const SizedBox(height: AppSpacing.sm),
    _Label('Primary, disabled'),
    const AppButton(label: 'Create account', onPressed: null),
    const SizedBox(height: AppSpacing.lg),

    _Label('Secondary'),
    AppButton(
      label: 'View my profile',
      variant: AppButtonVariant.secondary,
      onPressed: _noop,
    ),
    const SizedBox(height: AppSpacing.sm),
    _Label('Text'),
    AppButton(
      label: 'Already have an account? Sign in',
      variant: AppButtonVariant.text,
      onPressed: _noop,
    ),
    const SizedBox(height: AppSpacing.lg),

    _Label('With icon'),
    AppButton(
      label: 'Edit profile',
      icon: Icons.edit_outlined,
      onPressed: _noop,
    ),
  ],
);

@Preview(name: 'Text fields', group: 'Components', size: Size(420, 640))
Widget textFields() => _Sheet(
  title: 'AppTextField',
  children: [
    _Label('Default'),
    AppTextField(label: 'FULL NAME', controller: _c('Juan dela Cruz')),

    _Label('Empty with hint'),
    AppTextField(label: 'EMAIL', controller: _c(''), hint: 'you@example.com'),

    _Label('With error (note the height does not change)'),
    AppTextField(
      label: 'EMAIL',
      controller: _c('not-an-email'),
      errorText: 'Enter a valid email',
    ),

    _Label('Obscured'),
    AppTextField(
      label: 'PASSWORD',
      controller: _c('secret123'),
      obscureText: true,
    ),

    _Label('Disabled'),
    AppTextField(
      label: 'FULL NAME',
      controller: _c('Juan dela Cruz'),
      enabled: false,
    ),
  ],
);

@Preview(name: 'States', group: 'Components', size: Size(420, 760))
Widget states() => _Sheet(
  title: 'Loading and error',
  children: [
    _Label('InlineError, used in forms'),
    const InlineError(message: 'That email or password is not correct.'),
    const SizedBox(height: AppSpacing.lg),

    _Label('LoadingState'),
    const SizedBox(height: 120, child: LoadingState()),
    const SizedBox(height: AppSpacing.sm),
    const SizedBox(
      height: 140,
      child: LoadingState(message: 'Restoring your session'),
    ),
    const SizedBox(height: AppSpacing.lg),

    _Label('ErrorState with retry'),
    SizedBox(
      height: 260,
      child: ErrorState(
        message: 'Could not reach DiscipleTrack. Check your connection.',
        onRetry: _noop,
      ),
    ),
  ],
);

@Preview(
  name: 'Buttons, large text',
  group: 'Components',
  size: Size(420, 520),
  textScaleFactor: 1.6,
)
Widget buttonsLargeText() => _Sheet(
  title: 'Accessibility check',
  children: [
    _Label('textScaleFactor 1.6, nothing should clip'),
    AppButton(label: 'Create account', onPressed: _noop),
    const SizedBox(height: AppSpacing.sm),
    AppTextField(
      label: 'EMAIL',
      controller: _c(''),
      hint: 'you@example.com',
      errorText: 'Enter a valid email',
    ),
  ],
);

List<Widget> _surfaces() => [
  _Label('StatusPill, one per tone'),
  const Wrap(
    spacing: AppSpacing.xs,
    runSpacing: AppSpacing.xs,
    children: [
      StatusPill(label: 'Active member', tone: StatusTone.positive),
      StatusPill(label: 'Awaiting approval', tone: StatusTone.waiting),
      StatusPill(label: 'Not in a church yet', tone: StatusTone.neutral),
    ],
  ),
  const SizedBox(height: AppSpacing.lg),

  _Label('StepList'),
  const StepList(
    steps: [
      StepItem(title: 'Account created', state: StepProgress.done),
      StepItem(
        title: 'Coordinator review',
        subtitle: 'Your Coordinator is reviewing your request.',
        state: StepProgress.current,
      ),
      StepItem(
        title: 'Access to your church',
        subtitle: 'Your D Group appears here.',
        state: StepProgress.upcoming,
      ),
    ],
  ),
  const SizedBox(height: AppSpacing.lg),

  _Label('InfoGroup'),
  InfoGroup(
    title: 'Contact',
    rows: [
      const InfoRow(label: 'Full name', value: 'James Mercado'),
      const InfoRow(label: 'Phone', value: 'Not added'),
      InfoRow(label: 'My profile', icon: Icons.person_outline, onTap: _noop),
    ],
  ),
  const SizedBox(height: AppSpacing.lg),

  _Label('AppCard fills'),
  for (final fill in AppCardFill.values) ...[
    AppCard(fill: fill, child: Text('AppCardFill.${fill.name}')),
    const SizedBox(height: AppSpacing.xs),
  ],
];

@Preview(name: 'Surfaces', group: 'Components', size: Size(420, 1100))
Widget surfaces() => _Sheet(title: 'Surfaces', children: _surfaces());

@Preview(name: 'Surfaces, dark', group: 'Components', size: Size(420, 1100))
Widget surfacesDark() =>
    _Sheet(title: 'Surfaces', dark: true, children: _surfaces());

@Preview(name: 'Buttons, dark', group: 'Components', size: Size(420, 420))
Widget buttonsDark() => _Sheet(
  title: 'AppButton',
  dark: true,
  children: [
    AppButton(label: 'Create account', onPressed: _noop),
    const SizedBox(height: AppSpacing.sm),
    const AppButton(label: 'Create account', onPressed: null),
    const SizedBox(height: AppSpacing.sm),
    AppButton(
      label: 'Edit profile',
      variant: AppButtonVariant.secondary,
      onPressed: _noop,
    ),
    AppButton(
      label: 'Sign out',
      variant: AppButtonVariant.text,
      onPressed: _noop,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Preview-only helpers.
// ---------------------------------------------------------------------------

void _noop() {}

TextEditingController _c(String text) => TextEditingController(text: text);

class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.title,
    required this.children,
    this.dark = false,
  });

  final String title;
  final List<Widget> children;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppTypography.display),
                const SizedBox(height: AppSpacing.lg),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs, top: AppSpacing.xs),
    child: Text(text.toUpperCase(), style: context.captionStyle),
  );
}
