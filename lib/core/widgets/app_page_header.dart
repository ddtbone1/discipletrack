import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The greeting row at the top of every signed-in page: a two-line greeting on
/// the left, then any [actions] and the avatar on the right.
///
/// Extracted because three screens already use it identically, which is the
/// threshold UI_DESIGN_SYSTEM section 15 sets for a component.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.greeting,
    required this.subtitle,
    this.onAvatarTap,
    this.status,
    this.actions = const [],
    super.key,
  });

  final String greeting;
  final String subtitle;
  final VoidCallback? onAvatarTap;

  /// Optional status line under the subtitle, typically a [StatusPill].
  final Widget? status;

  /// Controls shown immediately left of the avatar, such as the theme toggle.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTypography.display,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(subtitle, style: context.supportingStyle),
              if (status != null) ...[
                const SizedBox(height: AppSpacing.sm),
                status!,
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        for (final action in actions) ...[
          action,
          const SizedBox(width: AppSpacing.xs),
        ],
        AppAvatar(onTap: onAvatarTap),
      ],
    );
  }
}

/// Circular profile placeholder: a person icon on a neutral fill.
///
/// Uses the palette's quiet surface and muted foreground, so it sits back into
/// the page in both light and dark mode rather than standing out as an accent.
/// There is no image upload path yet, so there is nothing else to show.
class AppAvatar extends StatelessWidget {
  const AppAvatar({this.size = 46, this.onTap, super.key});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        shape: BoxShape.circle,
        border: Border.all(color: p.border),
      ),
      child: Icon(Icons.person_rounded, size: size * 0.56, color: p.muted),
    );

    if (onTap == null) return ExcludeSemantics(child: avatar);

    return Semantics(
      button: true,
      label: 'Open profile',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: avatar,
      ),
    );
  }
}

/// A full-width quiet row, for a note or secondary link that stands on its
/// own rather than belonging to a group.
class AppListRow extends StatelessWidget {
  const AppListRow({
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    super.key,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.pastel,
      borderRadius: AppRadius.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: p.onPastel),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.cardLabel.copyWith(
                        color: p.onPastel,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.caption.copyWith(
                          color: p.onPastel.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
