import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../application/theme_mode_provider.dart';

/// Switches between light and dark mode. Sits beside the profile avatar.
///
/// The icon shows the mode the tap switches to, and the tooltip and semantics
/// say it in words.
class ThemeModeToggle extends ConsumerWidget {
  const ThemeModeToggle({this.size = 46, super.key});

  /// Matches the avatar it sits beside.
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final label = isDark ? 'Switch to light mode' : 'Switch to dark mode';

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: p.surfaceAlt,
          shape: CircleBorder(side: BorderSide(color: p.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => ref.read(themeModeProvider.notifier).toggle(),
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                size: size * 0.45,
                color: p.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
