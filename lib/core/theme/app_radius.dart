import 'package:flutter/widgets.dart';

/// Shared corner radii.
///
/// The reference's most distinctive move is its generous card rounding, so the
/// card radius sits high (24) while controls stay moderate (14). Icon chips
/// inside cards use the small value.
///
/// UI_DESIGN_SYSTEM section 12 allows different component categories to carry
/// different standardized radii, but requires shared tokens rather than
/// arbitrary values.
abstract final class AppRadius {
  static const xs = 10.0; // icon chips
  static const sm = 14.0; // buttons, fields
  static const md = 18.0; // small cards, chips
  static const lg = 24.0; // cards
  static const xl = 32.0; // hero surfaces

  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));

  /// Buttons and text fields.
  static const control = smAll;

  /// Cards.
  static const card = lgAll;

  /// The icon chip that sits in a card corner.
  static const chip = xsAll;

  /// Fully rounded, for day pills and status chips.
  static const pill = BorderRadius.all(Radius.circular(999));
}
