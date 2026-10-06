import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
    this.glyph,
    this.alsoActiveOn = const [],
  });

  final String label;
  final IconData icon;
  final IconData activeIcon;

  /// Draws the icon instead of [icon], for a shape no icon font has (the
  /// plain rounded house of the Home destination). [active] asks for the
  /// filled form.
  final Widget Function(Color color, double size, bool active)? glyph;

  /// Where tapping goes. Also the prefix that marks the item active.
  final String path;

  /// Further path prefixes that mark the item active: pages reached from
  /// this destination that live under another path.
  final List<String> alsoActiveOn;
}

/// The floating bottom dock (UI_DESIGN_SYSTEM section 21): a small pill
/// centred above the bottom safe area. White in light mode, charcoal in dark.
///
/// The active destination is a pill holding its filled icon and its name
/// (black in light mode, white in dark); the others are thin grey outline
/// icons. The dock's width never changes: every destination has a fixed
/// slot and the active one a fixed wider slot, so switching only moves the
/// pill, which glides across while the names cross-fade.
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

  /// Height of the active pill.
  static const pill = 40.0;

  /// Space inside the dock around the pill.
  static const inset = 6.0;

  /// Total height of the dock.
  static const height = pill + inset * 2;

  /// Width of an inactive slot, and of the active one.
  static const slot = 52.0;
  static const activeSlot = 108.0;

  /// Space between the dock and the bottom safe area.
  static const gap = AppSpacing.sm;

  static const iconSize = 20.0;

  static const duration = Duration(milliseconds: 450);

  /// Starts briskly and settles gently, so the glide reads as one motion.
  static const curve = Curves.easeOutQuart;

  /// The dock's inner width: the same whichever destination is active.
  static double contentWidth(int count) =>
      count == 0 ? 0 : activeSlot + (count - 1) * slot;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final count = items.length;
    final hasActive = activeIndex >= 0 && activeIndex < count;
    double widthOf(int i) => hasActive && i == activeIndex ? activeSlot : slot;
    double leftOf(int i) {
      var x = 0.0;
      for (var j = 0; j < i; j++) {
        x += widthOf(j);
      }
      return x;
    }

    return Container(
      height: height,
      padding: const EdgeInsets.all(inset),
      decoration: BoxDecoration(
        color: p.dock,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: p.border.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: p.textPrimary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // The dock floats outside any Scaffold, so it brings its own Material
      // for the ink of its buttons.
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: hasActive ? contentWidth(count) : count * slot,
          child: Stack(
            children: [
              // The one pill, gliding to the active slot.
              if (hasActive)
                AnimatedPositioned(
                  duration: duration,
                  curve: curve,
                  left: leftOf(activeIndex),
                  top: 0,
                  bottom: 0,
                  width: activeSlot,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: p.dockActive,
                      borderRadius: BorderRadius.circular(pill / 2),
                    ),
                  ),
                ),
              Row(
                children: [
                  for (var i = 0; i < count; i++)
                    AnimatedContainer(
                      duration: duration,
                      curve: curve,
                      width: widthOf(i),
                      child: _DockButton(
                        item: items[i],
                        active: hasActive && i == activeIndex,
                        onTap: () => onSelected(i),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
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
    final colour = active ? p.dockActiveForeground : p.dockIcon;

    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: Tooltip(
        message: item.label,
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? p.textPrimary.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: SizedBox(
            height: FloatingDock.pill,
            child: ClipRect(
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TweenAnimationBuilder<Color?>(
                      duration: FloatingDock.duration,
                      curve: FloatingDock.curve,
                      tween: ColorTween(end: colour),
                      builder: (context, c, _) =>
                          item.glyph?.call(
                            c ?? colour,
                            FloatingDock.iconSize,
                            active,
                          ) ??
                          Icon(
                            active ? item.activeIcon : item.icon,
                            size: FloatingDock.iconSize,
                            color: c,
                          ),
                    ),
                    // The name opens and fades with the pill. Flexible, so
                    // mid-glide it narrows with its slot instead of
                    // overflowing.
                    Flexible(
                      child: AnimatedSize(
                        duration: FloatingDock.duration,
                        curve: FloatingDock.curve,
                        child: AnimatedOpacity(
                          duration: FloatingDock.duration,
                          curve: FloatingDock.curve,
                          opacity: active ? 1 : 0,
                          child: active
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpacing.xs,
                                  ),
                                  child: Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                    style: AppTypography.cardLabel.copyWith(
                                      color: colour,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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

/// A plain house outline with rounded corners: a pentagon, no door and no
/// chimney. The Home glyph of the dock.
class HouseOutline extends StatelessWidget {
  const HouseOutline({
    required this.color,
    this.size = 24,
    this.filled = false,
    super.key,
  });

  final Color color;
  final double size;

  /// Solid instead of outlined, for the active destination.
  final bool filled;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _HousePainter(color, filled: filled)),
  );
}

class _HousePainter extends CustomPainter {
  _HousePainter(this.color, {required this.filled});

  final Color color;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Bottom left, bottom right, right eave, apex, left eave.
    final points = [
      Offset(w * 0.20, h * 0.86),
      Offset(w * 0.80, h * 0.86),
      Offset(w * 0.80, h * 0.44),
      Offset(w * 0.50, h * 0.16),
      Offset(w * 0.20, h * 0.44),
    ];
    final radius = w * 0.09;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final prev = points[(i - 1 + points.length) % points.length];
      final curr = points[i];
      final next = points[(i + 1) % points.length];
      final inDir = (curr - prev) / (curr - prev).distance;
      final outDir = (next - curr) / (next - curr).distance;
      final a = curr - inDir * radius;
      final b = curr + outDir * radius;
      if (i == 0) {
        path.moveTo(a.dx, a.dy);
      } else {
        path.lineTo(a.dx, a.dy);
      }
      path.quadraticBezierTo(curr.dx, curr.dy, b.dx, b.dy);
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_HousePainter old) =>
      old.color != color || old.filled != filled;
}
