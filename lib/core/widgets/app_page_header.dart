import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// "Good morning", "Good afternoon" or "Good evening" for the local time.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// The row at the top of every signed-in page: the avatar on the left, then
/// two lines beside it (the person's [name], bold and larger, over a
/// lighter, smaller [subtitle] such as the church name), and round icon
/// buttons ([actions]) on the right. An optional [status] sits underneath.
///
/// The time-of-day greeting is not part of it; pages that greet show it as
/// a title in their body (see [greetingFor]).
///
/// Extracted because several screens use it identically, which is the
/// threshold UI_DESIGN_SYSTEM section 15 sets for a component.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    required this.name,
    this.subtitle,
    this.onAvatarTap,
    this.status,
    this.actions = const [],
    super.key,
  });

  /// The first line, bold and larger, usually the person's full name.
  final String name;

  /// The second line, lighter, smaller and thinner.
  final String? subtitle;
  final VoidCallback? onAvatarTap;

  /// Optional status under the header row, such as a [StatusPill].
  final Widget? status;

  /// Round icon buttons on the right, such as the theme toggle.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppAvatar(size: 48, onTap: onAvatarTap),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: AppTypography.sectionTitle.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: p.muted,
                        fontWeight: FontWeight.w400,
                        fontSize: 12,
                        letterSpacing: 0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            for (final action in actions) ...[
              const SizedBox(width: AppSpacing.xs),
              action,
            ],
          ],
        ),
        if (status != null) ...[const SizedBox(height: AppSpacing.md), status!],
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
        color: p.surface,
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
