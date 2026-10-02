import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// One destination in the [FloatingDock].
@immutable
class DockItem {
  const DockItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.path,
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Where tapping goes. Also the prefix that marks the item active.
  final String path;
}

/// The floating bottom dock (UI_DESIGN_SYSTEM section 21): a soft elevated
/// pill above the bottom safe area, with clear active and inactive states.
///
/// Which destinations it holds is decided by the caller, per role (section
/// 22); the dock only draws them.
class FloatingDock extends StatelessWidget {
  const FloatingDock({
    required this.items,
    required this.activeIndex,
    required this.onSelected,
    super.key,
  });

  final List<DockItem> items;

  /// -1 when no item matches the current page.
  final int activeIndex;
  final ValueChanged<int> onSelected;

  /// Height of the pill itself, without the gap below it.
  static const height = 64.0;

  /// Space between the pill and the bottom safe area.
  static const gap = AppSpacing.sm;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: p.border),
        boxShadow: [
          BoxShadow(
            color: p.ink.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: _DockButton(
                item: items[i],
                active: i == activeIndex,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final DockItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final fg = active ? p.onSky : p.muted;
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Material(
          color: active ? p.sky : Colors.transparent,
          borderRadius: AppRadius.control,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.control,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.pressed)
                  ? (active ? p.skyPressed : p.surfaceAlt)
                  : Colors.transparent,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(active ? item.activeIcon : item.icon, size: 22, color: fg),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: fg,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Marks a subtree as living inside the dock shell, so [AppScaffold] knows
/// the dock already offers a way out and shows a back button only on pages
/// that were navigated to.
class DockScope extends InheritedWidget {
  const DockScope({required super.child, super.key});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DockScope>() != null;

  @override
  bool updateShouldNotify(DockScope oldWidget) => false;
}
