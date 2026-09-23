import 'package:flutter/material.dart';

import 'app_colors.dart';

/// The type scale.
///
/// Styles carry no colour: text inherits the theme's primary text colour, so
/// it is correct in light and dark mode. The two muted roles need the palette,
/// so read them as `context.supportingStyle` and `context.captionStyle`.
///
/// Hierarchy comes from a few strong sizes against small quiet labels.
/// [metric] and [metricSmall] carry tight negative tracking for large numerals
/// once real figures (attendance, lesson progress) exist to show.
///
/// UI_DESIGN_SYSTEM section 8 asks for hierarchy from weight, spacing and
/// contrast before size, and section 52 warns against giant headings that waste
/// mobile space.
abstract final class AppTypography {
  static const _family = null; // platform default until a brand face is chosen

  /// Greeting at the top of a page.
  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 27,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
  );

  /// A single large number or state word.
  static const metric = TextStyle(
    fontFamily: _family,
    fontSize: 40,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.4,
  );

  /// The same, sized for a half-width card.
  static const metricSmall = TextStyle(
    fontFamily: _family,
    fontSize: 26,
    height: 1.1,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );

  static const pageTitle = TextStyle(
    fontFamily: _family,
    fontSize: 21,
    height: 1.25,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
  );

  static const sectionTitle = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  /// The small label above a metric, inside a card.
  static const cardLabel = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    height: 1.25,
    fontWeight: FontWeight.w600,
  );

  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    height: 1.45,
    fontWeight: FontWeight.w400,
  );

  static const supporting = TextStyle(
    fontFamily: _family,
    fontSize: 13.5,
    height: 1.4,
    fontWeight: FontWeight.w400,
  );

  /// Metadata under a metric, and field labels.
  static const caption = TextStyle(
    fontFamily: _family,
    fontSize: 11.5,
    height: 1.35,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.3,
  );

  static const button = TextStyle(
    fontFamily: _family,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
  );
}

extension AppTypographyContext on BuildContext {
  /// [AppTypography.supporting] in the palette's muted colour.
  TextStyle get supportingStyle =>
      AppTypography.supporting.copyWith(color: palette.muted);

  /// [AppTypography.caption] in the palette's muted colour.
  TextStyle get captionStyle =>
      AppTypography.caption.copyWith(color: palette.muted);
}
