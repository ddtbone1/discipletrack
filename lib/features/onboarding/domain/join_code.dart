/// The church join-code format fixed by Migration 004 and
/// DATABASE_CONSTRAINTS section 1: ten characters from an alphabet that
/// excludes I, O, 0 and 1, so a code can be read aloud and typed without
/// ambiguity. The database enforces the same pattern; this file only lets the
/// client normalise input and avoid spending a rate-limited lookup on a code
/// that cannot possibly match.
library;

const joinCodeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const joinCodeLength = 10;

final _wellFormed = RegExp(r'^[A-HJ-NP-Z2-9]{10}$');
final _separators = RegExp(r'[\s-]');

/// Uppercases and strips whitespace and hyphens, mirroring
/// `private.normalize_join_code()`. No other substitution is made.
String normalizeJoinCode(String raw) =>
    raw.toUpperCase().replaceAll(_separators, '');

/// Whether a normalised code has the right shape. A well-formed code is not
/// necessarily a real one; only `lookup_church_by_join_code()` knows that.
bool isWellFormedJoinCode(String normalized) =>
    _wellFormed.hasMatch(normalized);

/// Whether one typed character may appear in a code, after uppercasing.
bool isJoinCodeCharacter(String char) =>
    char.length == 1 && joinCodeAlphabet.contains(char.toUpperCase());
