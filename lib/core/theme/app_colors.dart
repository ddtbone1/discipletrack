import 'package:flutter/material.dart';

/// Raw colour tokens. Nothing outside `core/theme` reads these directly;
/// widgets read the active [AppPalette] through `context.palette`, so every
/// screen follows the system light or dark setting.
///
/// Light palette:
///
///   #C8E9CA  mint      primary accent surface
///   #87DCFB  sky       secondary accent surface
///   #201F1F  ink       near-black, text and high-emphasis fills
///   #FFFFFF  white     page
///
/// Both accents are light, so they always carry dark text and never white.
abstract final class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF4F7F4); // fields, quiet panels
  static const border = Color(0xFFE7EDE7); // soft, low contrast

  /// Near-black. Primary buttons and other high-emphasis fills.
  static const ink = Color(0xFF201F1F);

  /// Primary accent. Soft mint green.
  static const mint = Color(0xFFC8E9CA);

  /// Secondary accent. Sky blue.
  static const sky = Color(0xFF87DCFB);

  /// Quiet fill for list rows, a paler mint.
  static const pastel = Color(0xFFEDF6EE);

  static const textPrimary = Color(0xFF201F1F);
  static const muted = Color(0xFF6B706B);
  static const disabled = Color(0xFFA6ADA6);

  static const onInk = Color(0xFFFFFFFF);
  static const onInkMuted = Color(0xB3FFFFFF); // white at 70%

  /// On [mint], [sky] and [pastel]. Always the dark ink, never white.
  static const onMint = Color(0xFF201F1F);
  static const onSky = Color(0xFF201F1F);
  static const onPastel = Color(0xFF201F1F);

  // Section 7: these communicate meaning and are never decoration.
  // success is a deeper green than [mint] so a "completed" state is never
  // confused with an ordinary accent surface.
  static const success = Color(0xFF2F7D4F);
  static const warning = Color(0xFFB57A18);
  static const error = Color(0xFFCE3B3B);
  static const info = Color(0xFF2B87B8);

  static const successSurface = Color(0xFFE6F3EA);
  static const warningSurface = Color(0xFFFBF2E1);
  static const errorSurface = Color(0xFFFBEBEB);
}

/// Dark scheme: a near-black page with raised charcoal cards and white text.
/// The mint and sky accents carry across unchanged, still with dark text, so
/// the product reads as one system in either mode.
abstract final class AppColorsDark {
  static const background = Color(0xFF0E0E0E);
  static const surface = Color(0xFF1A1A1A); // raised card
  static const surfaceAlt = Color(0xFF232323); // fields, quiet panels
  static const border = Color(0xFF2E2E2E);

  /// The high-emphasis fill inverts to near-white so a primary button still
  /// stands out most against a dark page.
  static const ink = Color(0xFFF2F2F2);

  static const mint = Color(0xFFC8E9CA);
  static const sky = Color(0xFF87DCFB);
  static const pastel = Color(0xFF232B24);

  static const textPrimary = Color(0xFFF5F5F5);
  static const muted = Color(0xFF9BA09B);
  static const disabled = Color(0xFF5E635E);

  static const onInk = Color(0xFF201F1F);
  static const onInkMuted = Color(0xB3201F1F);

  static const onMint = Color(0xFF201F1F);
  static const onSky = Color(0xFF201F1F);
  static const onPastel = Color(0xFFE8F0E9);

  static const success = Color(0xFF5FC98A);
  static const warning = Color(0xFFE0A93F);
  static const error = Color(0xFFF07070);
  static const info = Color(0xFF6BC2EC);

  static const successSurface = Color(0xFF17291E);
  static const warningSurface = Color(0xFF2B2415);
  static const errorSurface = Color(0xFF2E1A1A);
}

/// The active colour set, registered on [ThemeData.extensions] by `AppTheme`.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.ink,
    required this.mint,
    required this.sky,
    required this.pastel,
    required this.textPrimary,
    required this.muted,
    required this.disabled,
    required this.onInk,
    required this.onInkMuted,
    required this.onMint,
    required this.onSky,
    required this.onPastel,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.successSurface,
    required this.warningSurface,
    required this.errorSurface,
  });

  static const light = AppPalette(
    background: AppColors.background,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt,
    border: AppColors.border,
    ink: AppColors.ink,
    mint: AppColors.mint,
    sky: AppColors.sky,
    pastel: AppColors.pastel,
    textPrimary: AppColors.textPrimary,
    muted: AppColors.muted,
    disabled: AppColors.disabled,
    onInk: AppColors.onInk,
    onInkMuted: AppColors.onInkMuted,
    onMint: AppColors.onMint,
    onSky: AppColors.onSky,
    onPastel: AppColors.onPastel,
    success: AppColors.success,
    warning: AppColors.warning,
    error: AppColors.error,
    info: AppColors.info,
    successSurface: AppColors.successSurface,
    warningSurface: AppColors.warningSurface,
    errorSurface: AppColors.errorSurface,
  );

  static const dark = AppPalette(
    background: AppColorsDark.background,
    surface: AppColorsDark.surface,
    surfaceAlt: AppColorsDark.surfaceAlt,
    border: AppColorsDark.border,
    ink: AppColorsDark.ink,
    mint: AppColorsDark.mint,
    sky: AppColorsDark.sky,
    pastel: AppColorsDark.pastel,
    textPrimary: AppColorsDark.textPrimary,
    muted: AppColorsDark.muted,
    disabled: AppColorsDark.disabled,
    onInk: AppColorsDark.onInk,
    onInkMuted: AppColorsDark.onInkMuted,
    onMint: AppColorsDark.onMint,
    onSky: AppColorsDark.onSky,
    onPastel: AppColorsDark.onPastel,
    success: AppColorsDark.success,
    warning: AppColorsDark.warning,
    error: AppColorsDark.error,
    info: AppColorsDark.info,
    successSurface: AppColorsDark.successSurface,
    warningSurface: AppColorsDark.warningSurface,
    errorSurface: AppColorsDark.errorSurface,
  );

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color ink;
  final Color mint;
  final Color sky;
  final Color pastel;
  final Color textPrimary;
  final Color muted;
  final Color disabled;
  final Color onInk;
  final Color onInkMuted;
  final Color onMint;
  final Color onSky;
  final Color onPastel;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color successSurface;
  final Color warningSurface;
  final Color errorSurface;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? ink,
    Color? mint,
    Color? sky,
    Color? pastel,
    Color? textPrimary,
    Color? muted,
    Color? disabled,
    Color? onInk,
    Color? onInkMuted,
    Color? onMint,
    Color? onSky,
    Color? onPastel,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? successSurface,
    Color? warningSurface,
    Color? errorSurface,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      ink: ink ?? this.ink,
      mint: mint ?? this.mint,
      sky: sky ?? this.sky,
      pastel: pastel ?? this.pastel,
      textPrimary: textPrimary ?? this.textPrimary,
      muted: muted ?? this.muted,
      disabled: disabled ?? this.disabled,
      onInk: onInk ?? this.onInk,
      onInkMuted: onInkMuted ?? this.onInkMuted,
      onMint: onMint ?? this.onMint,
      onSky: onSky ?? this.onSky,
      onPastel: onPastel ?? this.onPastel,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      successSurface: successSurface ?? this.successSurface,
      warningSurface: warningSurface ?? this.warningSurface,
      errorSurface: errorSurface ?? this.errorSurface,
    );
  }

  @override
  AppPalette lerp(AppPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: l(background, other.background),
      surface: l(surface, other.surface),
      surfaceAlt: l(surfaceAlt, other.surfaceAlt),
      border: l(border, other.border),
      ink: l(ink, other.ink),
      mint: l(mint, other.mint),
      sky: l(sky, other.sky),
      pastel: l(pastel, other.pastel),
      textPrimary: l(textPrimary, other.textPrimary),
      muted: l(muted, other.muted),
      disabled: l(disabled, other.disabled),
      onInk: l(onInk, other.onInk),
      onInkMuted: l(onInkMuted, other.onInkMuted),
      onMint: l(onMint, other.onMint),
      onSky: l(onSky, other.onSky),
      onPastel: l(onPastel, other.onPastel),
      success: l(success, other.success),
      warning: l(warning, other.warning),
      error: l(error, other.error),
      info: l(info, other.info),
      successSurface: l(successSurface, other.successSurface),
      warningSurface: l(warningSurface, other.warningSurface),
      errorSurface: l(errorSurface, other.errorSurface),
    );
  }
}

extension AppPaletteContext on BuildContext {
  /// The palette for the current brightness. Falls back to light when a
  /// widget is built outside an `AppTheme`, such as in a bare test harness.
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
