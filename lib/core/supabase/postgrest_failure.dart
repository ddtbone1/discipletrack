import 'package:supabase_flutter/supabase_flutter.dart';

/// Why a database call failed, decided from the PostgREST/SQLSTATE code rather
/// than message text. The controlled operations raise the PTxxx SQLSTATEs,
/// which PostgREST turns into the matching HTTP status.
enum DbFailureCode {
  /// `PT429`: a rate limit, such as the per-user join-code limit.
  rateLimited,

  /// `PT401`: no session.
  unauthenticated,

  /// `PT403` or `42501`: the caller may not do that.
  forbidden,

  /// `PT404`.
  notFound,

  /// `PT409`: the record is not in a state that allows the operation.
  conflict,
  network,
  unknown,
}

/// The mapping every repository shares. Feature failures keep their own
/// messages; only the code and the generic wording live here.
abstract final class PostgrestFailure {
  static const networkMessage =
      'Could not reach DiscipleTrack. Check your connection and try again.';

  static DbFailureCode codeOf(PostgrestException e) => switch (e.code) {
    'PT429' => DbFailureCode.rateLimited,
    'PT401' => DbFailureCode.unauthenticated,
    'PT403' || '42501' => DbFailureCode.forbidden,
    'PT404' => DbFailureCode.notFound,
    'PT409' => DbFailureCode.conflict,
    _ => DbFailureCode.unknown,
  };

  /// A message for the codes whose meaning does not depend on the operation,
  /// otherwise [fallback].
  static String friendlyMessage(PostgrestException e, String fallback) =>
      switch (codeOf(e)) {
        DbFailureCode.rateLimited =>
          'Too many attempts. Try again in a few minutes.',
        DbFailureCode.unauthenticated => 'Please sign in again to continue.',
        DbFailureCode.forbidden => 'You are not allowed to do that.',
        _ => fallback,
      };
}
