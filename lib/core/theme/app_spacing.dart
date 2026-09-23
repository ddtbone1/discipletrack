/// The single spacing scale. UI_DESIGN_SYSTEM section 9 requires a shared scale
/// rather than arbitrary values, so no widget should write a raw number.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Outer page gutter, matching the reference.
  static const page = md;

  /// Gap between cards in a stack or grid.
  static const cardGap = sm;

  /// Padding inside a card.
  static const cardPadding = 20.0;

  /// Reserved height for a field's validation message, so showing or hiding
  /// it never reflows the form.
  static const errorSlot = 20.0;
}
