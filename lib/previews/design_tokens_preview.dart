import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_radius.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/app_typography.dart';

/// Live previews of the DiscipleTrack design tokens.
///
/// Run with: flutter widget-preview start
///
/// Every value shown here comes from `core/theme`. Editing a token and saving
/// updates these previews immediately, which is the fastest way to judge the
/// palette without rebuilding the app.

@Preview(name: 'Colours, light', group: 'Design tokens', size: Size(420, 1000))
Widget colourTokensLight() => const _Sheet(title: 'Colours', child: _Colours());

@Preview(name: 'Colours, dark', group: 'Design tokens', size: Size(420, 1000))
Widget colourTokensDark() =>
    const _Sheet(title: 'Colours', dark: true, child: _Colours());

@Preview(name: 'Typography', group: 'Design tokens', size: Size(420, 760))
Widget typographyTokens() => const _Sheet(
  title: 'Typography',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TypeRow('display', AppTypography.display, 'Hello, James'),
      _TypeRow('pageTitle', AppTypography.pageTitle, 'Your discipleship'),
      _TypeRow('sectionTitle', AppTypography.sectionTitle, 'This week'),
      _TypeRow('cardLabel', AppTypography.cardLabel, 'Lesson 4'),
      _TypeRow(
        'body',
        AppTypography.body,
        'Attendance is recorded per gathering.',
      ),
      _TypeRow('supporting', AppTypography.supporting, 'Secondary information'),
      _TypeRow('caption', AppTypography.caption, 'JOINED CHURCH'),
    ],
  ),
);

@Preview(name: 'Spacing & radius', group: 'Design tokens', size: Size(420, 640))
Widget spacingTokens() => const _Sheet(
  title: 'Spacing and radius',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionLabel('Spacing scale'),
      _SpaceBar('xxs', AppSpacing.xxs),
      _SpaceBar('xs', AppSpacing.xs),
      _SpaceBar('sm', AppSpacing.sm),
      _SpaceBar('md', AppSpacing.md),
      _SpaceBar('lg', AppSpacing.lg),
      _SpaceBar('xl', AppSpacing.xl),
      _SpaceBar('xxl', AppSpacing.xxl),
      SizedBox(height: AppSpacing.lg),
      _SectionLabel('Corner radius'),
      Row(
        children: [
          _RadiusBox('sm', AppRadius.sm),
          _RadiusBox('md', AppRadius.md),
          _RadiusBox('lg', AppRadius.lg),
          _RadiusBox('xl', AppRadius.xl),
        ],
      ),
    ],
  ),
);

// ---------------------------------------------------------------------------
// Preview-only helpers. Not part of the application.
// ---------------------------------------------------------------------------

class _Colours extends StatelessWidget {
  const _Colours();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Accents (always dark text)'),
        _Swatch('mint', p.mint, 'primary accent surface'),
        _Swatch('sky', p.sky, 'secondary accent surface'),
        _Swatch('ink', p.ink, 'primary buttons, high emphasis'),
        const SizedBox(height: AppSpacing.md),

        const _SectionLabel('Surfaces'),
        _Swatch('background', p.background, 'page'),
        _Swatch('surface', p.surface, 'cards'),
        _Swatch('surfaceAlt', p.surfaceAlt, 'fields, soft panels'),
        _Swatch('pastel', p.pastel, 'quiet rows'),
        _Swatch('border', p.border, 'low-contrast dividers'),
        const SizedBox(height: AppSpacing.md),

        const _SectionLabel('Text'),
        _Swatch('textPrimary', p.textPrimary, ''),
        _Swatch('muted', p.muted, ''),
        _Swatch('disabled', p.disabled, ''),
        const SizedBox(height: AppSpacing.md),

        const _SectionLabel('Semantic (meaning, never decoration)'),
        _Swatch('success', p.success, 'completed, resolved'),
        _Swatch('warning', p.warning, 'needs attention, overdue'),
        _Swatch('error', p.error, 'destructive, validation'),
        _Swatch('info', p.info, 'informational'),
        const SizedBox(height: AppSpacing.lg),

        const _SectionLabel('Contrast check'),
        _ContrastRow(label: 'ink + onInk', bg: p.ink, fg: p.onInk),
        _ContrastRow(label: 'mint + onMint', bg: p.mint, fg: p.onMint),
        _ContrastRow(label: 'sky + onSky', bg: p.sky, fg: p.onSky),
        _ContrastRow(label: 'pastel + onPastel', bg: p.pastel, fg: p.onPastel),
      ],
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child, this.dark = false});

  final String title;
  final Widget child;
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTypography.display),
                const SizedBox(height: AppSpacing.lg),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text.toUpperCase(), style: context.captionStyle),
  );
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.name, this.color, this.note);

  final String name;
  final Color color;
  final String note;

  String get _hex =>
      '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: context.palette.border),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name  $_hex', style: AppTypography.cardLabel),
                if (note.isNotEmpty) Text(note, style: context.captionStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContrastRow extends StatelessWidget {
  const _ContrastRow({required this.label, required this.bg, required this.fg});

  final String label;
  final Color bg;
  final Color fg;

  /// WCAG 2.x contrast ratio.
  double get _ratio {
    final a = bg.computeLuminance();
    final b = fg.computeLuminance();
    final (hi, lo) = a > b ? (a, b) : (b, a);
    return (hi + 0.05) / (lo + 0.05);
  }

  @override
  Widget build(BuildContext context) {
    final r = _ratio;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 120,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: AppRadius.smAll,
              border: Border.all(color: context.palette.border),
            ),
            child: Text(
              'Sample',
              style: AppTypography.button.copyWith(color: fg),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.captionStyle),
                Text(
                  '${r.toStringAsFixed(1)}:1  ${r >= 4.5 ? 'AA pass' : 'below AA'}',
                  style: context.supportingStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow(this.name, this.style, this.sample);

  final String name;
  final TextStyle style;
  final String sample;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$name  ${style.fontSize?.toStringAsFixed(0)}px  w${style.fontWeight?.value}',
            style: context.captionStyle,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(sample, style: style),
        ],
      ),
    );
  }
}

class _SpaceBar extends StatelessWidget {
  const _SpaceBar(this.name, this.value);

  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              '$name ${value.toStringAsFixed(0)}',
              style: context.captionStyle,
            ),
          ),
          Container(width: value, height: 16, color: context.palette.mint),
        ],
      ),
    );
  }
}

class _RadiusBox extends StatelessWidget {
  const _RadiusBox(this.name, this.value);

  final String name;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.palette.sky,
              borderRadius: BorderRadius.circular(value),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$name ${value.toStringAsFixed(0)}',
            style: context.captionStyle,
          ),
        ],
      ),
    );
  }
}
