import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The colours pills, avatars, steps and progress may use: the brand theme
/// (lime, black, white and grey) plus exactly three hues, blue, amber and
/// red (user decision of 2026-10-05). Nothing else.
///
/// Each tone is a Material 3 style tonal pair: a bright, light container
/// and a deep "on" colour with readable contrast, with separate values for
/// dark mode. Containers are tints, never solid fills.
enum PillTone {
  /// Grey fill with dark text (light text in dark mode): the default for
  /// supporting facts, so colour is kept for what matters most.
  outline,

  /// Grey: quiet fills, such as avatar placeholders.
  neutral,

  /// Lime: counted meetings, Present, completed, progress, the Discipler.
  brand,

  /// Black: the strongest neutral, the Leader.
  ink,

  /// Blue: in progress, the Disciple role.
  info,

  /// Yellow: Late, a lesson not started yet, and anything needing
  /// attention ("Not paired yet").
  warning,

  /// Red: a recorded absence.
  error,
}

typedef _Pair = ({Color bg, Color fg});

const _light = <PillTone, _Pair>{
  PillTone.outline: (bg: Color(0xFFECEEF1), fg: Color(0xFF3D434A)),
  PillTone.neutral: (bg: Color(0xFFECEEF1), fg: Color(0xFF525A63)),
  PillTone.brand: (bg: Color(0xFFE3FDC4), fg: Color(0xFF3A6400)),
  PillTone.ink: (bg: Color(0xFFE2E3E6), fg: Color(0xFF111111)),
  PillTone.info: (bg: Color(0xFFD7E8FF), fg: Color(0xFF1D5BB8)),
  PillTone.warning: (bg: Color(0xFFFFF1BA), fg: Color(0xFF8A6A00)),
  PillTone.error: (bg: Color(0xFFFFDCDC), fg: Color(0xFFB3261E)),
};

const _dark = <PillTone, _Pair>{
  PillTone.outline: (bg: Color(0xFF2C2C2E), fg: Color(0xFFD9DCE0)),
  PillTone.neutral: (bg: Color(0xFF2D3035), fg: Color(0xFFBCC2C9)),
  PillTone.brand: (bg: Color(0xFF253A0E), fg: Color(0xFF9BFC28)),
  PillTone.ink: (bg: Color(0xFF3A3A3C), fg: Color(0xFFFFFFFF)),
  PillTone.info: (bg: Color(0xFF17304F), fg: Color(0xFFA8CCFF)),
  PillTone.warning: (bg: Color(0xFF3B3210), fg: Color(0xFFFFD84D)),
  PillTone.error: (bg: Color(0xFF451C1C), fg: Color(0xFFFFA8A8)),
};

bool _isDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

/// Background and foreground for [tone].
(Color, Color) pillColors(BuildContext context, PillTone tone) {
  final pair = (_isDark(context) ? _dark : _light)[tone]!;
  return (pair.bg, pair.fg);
}

/// A visible track or quiet fill on a card. The palette's surfaceAlt is
/// white in light mode, so it cannot be used as a track.
Color neutralFill(BuildContext context) =>
    _isDark(context) ? context.palette.surfaceAlt : const Color(0xFFEEF0F2);

/// The colour of progress on rings, steppers and bars: the brand lime.
Color progressColor(BuildContext context) => context.palette.brand;

/// A stable colour for a name, for avatar placeholders, so the same person
/// always gets the same colour. Never lime: the brand colour is kept for
/// actions and progress.
PillTone toneForName(String name) {
  const tones = [
    PillTone.info,
    PillTone.warning,
    PillTone.neutral,
    PillTone.error,
  ];
  var hash = 0;
  for (final unit in name.trim().toLowerCase().codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return tones[hash % tones.length];
}

/// A small rounded label for a state, role or fact. Never the only carrier
/// of meaning: the text says it, the colour only helps.
///
/// Use sparingly: [PillTone.outline] (the default) for supporting facts,
/// [PillTone.brand] (lime) for the single most important, active fact, and
/// [PillTone.warning] only for something needing attention.
class AppPill extends StatelessWidget {
  const AppPill({
    required this.label,
    this.tone = PillTone.outline,
    this.icon,
    this.outlined = false,
    super.key,
  });

  final String label;
  final PillTone tone;
  final IconData? icon;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = pillColors(context, tone);
    return Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 10 : 8, 4, 10, 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: outlined ? Border.all(color: fg.withValues(alpha: 0.55)) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: fg,
                fontWeight: outlined ? FontWeight.w600 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A person's initials in a circle. Tinted by [tone] when the person's role
/// or state should show; otherwise a stable colour chosen from the name.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    required this.name,
    this.tone,
    this.radius = 20,
    this.background,
    this.foreground,
    super.key,
  });

  final String name;
  final PillTone? tone;
  final double radius;

  /// Overrides the tone, for avatars on a coloured card.
  final Color? background;
  final Color? foreground;

  static String initialsOf(String name) => [
    for (final part in name.trim().split(RegExp(r'\s+')).take(2))
      if (part.isNotEmpty) part[0].toUpperCase(),
  ].join();

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = pillColors(context, tone ?? toneForName(name));
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: background ?? bg,
        foregroundColor: foreground ?? fg,
        child: Text(
          initialsOf(name),
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: radius * 0.7),
        ),
      ),
    );
  }
}

/// Related items as separate white cards with space between: one card per
/// item, never rows joined by dividers, and no outer card around them (user
/// decisions of 2026-10-05: one component holds one related content).
class TileGroup extends StatelessWidget {
  const TileGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Material(
            color: p.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: children[i],
          ),
        ],
      ],
    );
  }
}
