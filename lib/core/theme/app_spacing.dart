/// The single spacing scale. UI_DESIGN_SYSTEM section 9 requires a shared scale
/// rather than arbitrary values, so no widget should write a raw number.
abstract final class AppSpacing {
  /// Tighter spacing between pieces of content (user request of
  /// 2026-10-06): each gap below is 4 less than its original value. Set to 0
  /// to return to the original spacing.
  static const _tighten = 4.0;

  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;

  /// Space between sections.
  static const lg = 24.0 - _tighten * 2;
  static const xl = 32.0;
  static const xxl = 48.0;

  /// Outer page gutter, matching the reference.
  static const page = md;

  /// Gap between cards in a stack or grid.
  static const cardGap = sm - _tighten;

  /// Gap between items in a list of separate cards, kept roomy so each
  /// card stands on its own (user request of 2026-10-06).
  static const itemGap = 12.0;

  /// Padding inside a card.
  static const cardPadding = 20.0 - _tighten;

  /// Reserved height for a field's validation message, so showing or hiding
  /// it never reflows the form.
  static const errorSlot = 20.0;
}
