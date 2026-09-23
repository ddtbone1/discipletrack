import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Assembles the Flutter [ThemeData] from the DiscipleTrack design tokens.
///
/// Light and dark share one builder, so the two modes can differ only in
/// [AppPalette] values, never in structure. The palette is registered as a
/// theme extension and read by widgets through `context.palette`.
///
/// Nothing here introduces a value that is not already a token.
abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.ink,
      onPrimary: p.onInk,
      secondary: p.mint,
      onSecondary: p.onMint,
      tertiary: p.sky,
      onTertiary: p.onSky,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.muted,
      error: p.error,
      onError: Colors.white,
      outline: p.border,
      outlineVariant: p.border,
    );

    final textTheme = const TextTheme(
      displaySmall: AppTypography.display,
      titleLarge: AppTypography.pageTitle,
      titleMedium: AppTypography.sectionTitle,
      titleSmall: AppTypography.cardLabel,
      bodyMedium: AppTypography.body,
      bodySmall: AppTypography.supporting,
      labelSmall: AppTypography.caption,
    ).apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      extensions: [p],
      scaffoldBackgroundColor: p.background,
      splashFactory: InkSparkle.splashFactory,

      textTheme: textTheme.copyWith(
        bodySmall: textTheme.bodySmall?.copyWith(color: p.muted),
        labelSmall: textTheme.labelSmall?.copyWith(color: p.muted),
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.pageTitle.copyWith(color: p.textPrimary),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: _fieldBorder(p.border),
        enabledBorder: _fieldBorder(p.border),
        disabledBorder: _fieldBorder(p.border),
        focusedBorder: _fieldBorder(p.textPrimary, width: 1.5),
        errorBorder: _fieldBorder(p.error),
        focusedErrorBorder: _fieldBorder(p.error, width: 1.5),
        hintStyle: AppTypography.body.copyWith(color: p.disabled),
        // Errors are rendered by AppTextField in a reserved slot so the form
        // never reflows. Suppress the built-in one.
        errorStyle: const TextStyle(height: 0, fontSize: 0),
      ),

      textSelectionTheme: TextSelectionThemeData(
        cursorColor: p.textPrimary,
        selectionColor: p.sky.withValues(alpha: 0.4),
        selectionHandleColor: p.textPrimary,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: AppTypography.body.copyWith(color: p.onInk),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.control),
      ),

      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),

      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.textPrimary),
    );
  }

  static OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: AppRadius.control,
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
