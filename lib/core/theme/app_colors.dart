import 'package:flutter/material.dart';

/// Raw colour tokens. Nothing outside `core/theme` reads these directly;
/// widgets read the active [AppPalette] through `context.palette`, so every
/// screen follows the system light or dark setting.
///
/// 60-30-10 (UI_DESIGN_SYSTEM section 7): about 60% cool off-white neutral,
/// 30% desaturated mint on major elements, 10% desaturated sky for the call
/// to action. Neither mode uses pure white or pure black.
///
/// Light palette:
///
///   #F5F7F8  background  page
///   #FBFCFC  surface     cards
///   #CFE4D2  mint        major elements, the 30%
///   #7DBFD9  sky         primary action, the 10%
///   #201F1F  ink         near-black text
///
/// Both accents are light, so they always carry dark text.
abstract final class AppColors {
  static const background = Color(0xFFF5F7F8);
  static const surface = Color(0xFFFBFCFC);
  static const surfaceAlt = Color(0xFFEDF1F2); // fields, quiet panels
  static const border = Color(0xFFDFE5E7); // soft, low contrast

  /// Near-black. High-emphasis fills such as the snackbar.
  static const ink = Color(0xFF201F1F);

  /// The 30%: desaturated mint for major elements.
  static const mint = Color(0xFFCFE4D2);

  /// The 10%: desaturated sky. Primary buttons and highlights.
  static const sky = Color(0xFF7DBFD9);

  /// [sky] one step darker, for the pressed state.
  static const skyPressed = Color(0xFF68ABC6);

  /// Quiet fill for notices and list rows, a paler mint.
  static const pastel = Color(0xFFE9F1EA);

  static const textPrimary = Color(0xFF201F1F);
  static const muted = Color(0xFF6B706B);
  static const disabled = Color(0xFFA6ADA6);

  static const onInk = Color(0xFFFBFCFC);
  static const onInkMuted = Color(0xB3FBFCFC); // off-white at 70%

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

/// Dark scheme: a cool near-black page with raised charcoal cards and
/// off-white text. The accents are desaturated a step further than in light
/// mode and still carry dark text, so the product reads as one system.
abstract final class AppColorsDark {
  static const background = Color(0xFF121517);
  static const surface = Color(0xFF1C2023); // raised card
  static const surfaceAlt = Color(0xFF252A2D); // fields, quiet panels
  static const border = Color(0xFF30363A);

  /// The high-emphasis fill inverts to near-white so a primary button still
  /// stands out most against a dark page.
  static const ink = Color(0xFFE8ECEE);

  static const mint = Color(0xFFAFCBB4);
  static const sky = Color(0xFF6FAFC8);
  static const skyPressed = Color(0xFF5C9BB4);
  static const pastel = Color(0xFF212A25);

  static const textPrimary = Color(0xFFE8ECEE);
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
    required this.skyPressed,
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
    skyPressed: AppColors.skyPressed,
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
    skyPressed: AppColorsDark.skyPressed,
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
  final Color skyPressed;
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
    Color? skyPressed,
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
      skyPressed: skyPressed ?? this.skyPressed,
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
      skyPressed: l(skyPressed, other.skyPressed),
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
