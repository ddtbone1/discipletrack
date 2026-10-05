/// Plain-language formatting shared by every feature.
abstract final class AppFormat {
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const _longMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// "Sep 20", in the person's local calendar.
  static String shortDate(DateTime utc) {
    final d = utc.toLocal();
    return '${_months[d.month - 1]} ${d.day}';
  }

  /// "September 2026".
  static String monthYear(DateTime local) =>
      '${_longMonths[local.month - 1]} ${local.year}';

  /// "1 Discipler", "3 Disciples".
  static String count(int n, String singular) =>
      '$n ${n == 1 ? singular : '${singular}s'}';
}
