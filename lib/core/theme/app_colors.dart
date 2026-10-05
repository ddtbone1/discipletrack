import 'package:flutter/material.dart';

/// Raw colour tokens. Nothing outside `core/theme` reads these directly;
/// widgets read the active [AppPalette] through `context.palette`, so every
/// screen follows the system light or dark setting.
///
/// The palette is lime, white, black and greys, and nothing else
/// (UI_DESIGN_SYSTEM section 6). The only exceptions are the semantic
/// warning and error colours, which carry meaning (section 7). The logo's
/// forest green belongs to the launcher icon and store listing only.
///
/// Light mode: pages (including the welcome page and the splash) are
/// #F2F3F4 and every component on them (cards, fields, the dock, buttons,
/// icon buttons) is #FFFFFF. Icons, back buttons and text are black; sub
/// text is grey. Dark mode is pure black with charcoal cards, after the
/// reference colourway. Lime is the primary in both.
///
/// 60-30-10: about 60% white (or black), 30% greys on major elements, 10%
/// lime for the primary action and active states.
///
/// There is exactly one lime, #9BFC28, the icon logo's own, in both modes;
/// no other green shade appears anywhere in the app. [brandPressed] is that
/// lime one step darker, shown only while a button is held down.
abstract final class AppColors {
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFFFFFF); // fields, quiet panels
  static const border = Color(0xFFE5E7EB); // separates white on white

  /// Black. Text and the highest-emphasis neutral fills.
  static const ink = Color(0xFF0A0A0A);

  /// Neutral fill for major positive elements (a placed member's group
  /// card). Grey, not a lime tint: the app has one lime only.
  static const mint = Color(0xFFFFFFFF);

  /// Neutral grey for informational accents (a "waiting" pill).
  static const sky = Color(0xFFFFFFFF);
  static const skyPressed = Color(0xFFF2F3F4);

  /// The 10%: lime. Primary buttons, the active dock item, highlights.
  /// Always carries black text.
  static const brand = Color(0xFF9BFC28);
  static const brandPressed = Color(0xFF8BE324);
  static const onBrand = Color(0xFF0A0A0A);
  static const lime = Color(0xFF9BFC28);
  static const onLime = Color(0xFF0A0A0A);

  /// The splash and welcome page background: the page itself, so they
  /// follow the theme like every other screen.
  static const brandDeep = Color(0xFFF2F3F4);
  static const onBrandDeep = Color(0xFF0A0A0A);

  /// The dock: a white pill, its active item a soft grey pill with black
  /// text, natural rather than loud.
  static const dock = Color(0xFFFFFFFF);
  static const dockIcon = Color(0xFF8E8E93);
  static const dockActive = Color(0xFFEEEFF1);
  static const dockActiveForeground = Color(0xFF0A0A0A);

  /// Quiet grey fill for notices and list rows.
  static const pastel = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF0A0A0A);
  static const muted = Color(0xFF6B7178);
  static const disabled = Color(0xFFA9AEB3);

  static const onInk = Color(0xFFFFFFFF);
  static const onInkMuted = Color(0xB3FFFFFF); // white at 70%

  static const onMint = Color(0xFF0A0A0A);
  static const onSky = Color(0xFF0A0A0A);
  static const onPastel = Color(0xFF0A0A0A);

  // Section 7: these communicate meaning and are never decoration. Success
  // is the one lime.
  static const success = Color(0xFF9BFC28);
  static const warning = Color(0xFFB57A18);
  static const error = Color(0xFFCE3B3B);
  static const info = Color(0xFF6B7178);

  static const successSurface = Color(0xFFFFFFFF);
  static const warningSurface = Color(0xFFFBF2E1);
  static const errorSurface = Color(0xFFFBEBEB);
}

/// Dark scheme, after the reference colourway: a pure black page, charcoal
/// cards, white text and a bright lime with black text.
abstract final class AppColorsDark {
  static const background = Color(0xFF000000);
  static const surface = Color(0xFF1C1C1E); // raised card
  static const surfaceAlt = Color(0xFF2A2A2C); // fields, quiet panels
  static const border = Color(0xFF2C2C2E);

  /// The high-emphasis neutral inverts to white.
  static const ink = Color(0xFFFFFFFF);

  static const mint = Color(0xFF1C1C1E);
  static const sky = Color(0xFF2C2C2E);
  static const skyPressed = Color(0xFF3A3A3C);

  static const brand = Color(0xFF9BFC28);
  static const brandPressed = Color(0xFF8BE324);
  static const onBrand = Color(0xFF0A0A0A);
  static const lime = Color(0xFF9BFC28);
  static const onLime = Color(0xFF0A0A0A);
  static const brandDeep = Color(0xFF000000);
  static const onBrandDeep = Color(0xFFFFFFFF);

  static const dock = Color(0xFF1C1C1E);
  static const dockIcon = Color(0xFF8E8E93);
  static const dockActive = Color(0xFF3A3A3C);
  static const dockActiveForeground = Color(0xFFFFFFFF);

  static const pastel = Color(0xFF1C1C1E);

  static const textPrimary = Color(0xFFFFFFFF);
  static const muted = Color(0xFF8E8E93);
  static const disabled = Color(0xFF5A5A5E);

  static const onInk = Color(0xFF0A0A0A);
  static const onInkMuted = Color(0xB30A0A0A);

  static const onMint = Color(0xFFFFFFFF);
  static const onSky = Color(0xFFFFFFFF);
  static const onPastel = Color(0xFFFFFFFF);

  static const success = Color(0xFF9BFC28);
  static const warning = Color(0xFFE0A93F);
  static const error = Color(0xFFF07070);
  static const info = Color(0xFF8E8E93);

  static const successSurface = Color(0xFF1C1C1E);
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
    required this.brand,
    required this.brandPressed,
    required this.onBrand,
    required this.lime,
    required this.onLime,
    required this.brandDeep,
    required this.onBrandDeep,
    required this.dock,
    required this.dockIcon,
    required this.dockActive,
    required this.dockActiveForeground,
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
    brand: AppColors.brand,
    brandPressed: AppColors.brandPressed,
    onBrand: AppColors.onBrand,
    lime: AppColors.lime,
    onLime: AppColors.onLime,
    brandDeep: AppColors.brandDeep,
    onBrandDeep: AppColors.onBrandDeep,
    dock: AppColors.dock,
    dockIcon: AppColors.dockIcon,
    dockActive: AppColors.dockActive,
    dockActiveForeground: AppColors.dockActiveForeground,
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
    brand: AppColorsDark.brand,
    brandPressed: AppColorsDark.brandPressed,
    onBrand: AppColorsDark.onBrand,
    lime: AppColorsDark.lime,
    onLime: AppColorsDark.onLime,
    brandDeep: AppColorsDark.brandDeep,
    onBrandDeep: AppColorsDark.onBrandDeep,
    dock: AppColorsDark.dock,
    dockIcon: AppColorsDark.dockIcon,
    dockActive: AppColorsDark.dockActive,
    dockActiveForeground: AppColorsDark.dockActiveForeground,
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
  final Color brand;
  final Color brandPressed;
  final Color onBrand;
  final Color lime;
  final Color onLime;
  final Color brandDeep;
  final Color onBrandDeep;
  final Color dock;
  final Color dockIcon;
  final Color dockActive;
  final Color dockActiveForeground;
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
    Color? brand,
    Color? brandPressed,
    Color? onBrand,
    Color? lime,
    Color? onLime,
    Color? brandDeep,
    Color? onBrandDeep,
    Color? dock,
    Color? dockIcon,
    Color? dockActive,
    Color? dockActiveForeground,
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
      brand: brand ?? this.brand,
      brandPressed: brandPressed ?? this.brandPressed,
      onBrand: onBrand ?? this.onBrand,
      lime: lime ?? this.lime,
      onLime: onLime ?? this.onLime,
      brandDeep: brandDeep ?? this.brandDeep,
      onBrandDeep: onBrandDeep ?? this.onBrandDeep,
      dock: dock ?? this.dock,
      dockIcon: dockIcon ?? this.dockIcon,
      dockActive: dockActive ?? this.dockActive,
      dockActiveForeground: dockActiveForeground ?? this.dockActiveForeground,
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
      brand: l(brand, other.brand),
      brandPressed: l(brandPressed, other.brandPressed),
      onBrand: l(onBrand, other.onBrand),
      lime: l(lime, other.lime),
      onLime: l(onLime, other.onLime),
      brandDeep: l(brandDeep, other.brandDeep),
      onBrandDeep: l(onBrandDeep, other.onBrandDeep),
      dock: l(dock, other.dock),
      dockIcon: l(dockIcon, other.dockIcon),
      dockActive: l(dockActive, other.dockActive),
      dockActiveForeground: l(dockActiveForeground, other.dockActiveForeground),
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
