import 'package:discipletrack/features/onboarding/domain/join_code.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeJoinCode', () {
    test('uppercases and strips spaces and hyphens', () {
      expect(normalizeJoinCode('7qk4 mzp2-xr'), '7QK4MZP2XR');
      expect(normalizeJoinCode('  7QK4-MZP2-XR\n'), '7QK4MZP2XR');
    });

    test('makes no other substitution', () {
      // O and 0 are outside the alphabet; they are not swapped for each other.
      expect(normalizeJoinCode('o0'), 'O0');
    });
  });

  group('isWellFormedJoinCode', () {
    test('accepts exactly ten characters from the alphabet', () {
      expect(isWellFormedJoinCode('7QK4MZP2XR'), isTrue);
      expect(isWellFormedJoinCode('ABCDEFGHJK'), isTrue);
      expect(isWellFormedJoinCode('Z9Z9Z9Z9Z9'), isTrue);
    });

    test('rejects the wrong length', () {
      expect(isWellFormedJoinCode('7QK4MZP2X'), isFalse);
      expect(isWellFormedJoinCode('7QK4MZP2XR2'), isFalse);
      expect(isWellFormedJoinCode(''), isFalse);
    });

    test('rejects I, O, 0 and 1 and lowercase', () {
      expect(isWellFormedJoinCode('IQK4MZP2XR'), isFalse);
      expect(isWellFormedJoinCode('OQK4MZP2XR'), isFalse);
      expect(isWellFormedJoinCode('0QK4MZP2XR'), isFalse);
      expect(isWellFormedJoinCode('1QK4MZP2XR'), isFalse);
      expect(isWellFormedJoinCode('7qk4mzp2xr'), isFalse);
    });

    test('the alphabet has 32 symbols and matches the pattern', () {
      expect(joinCodeAlphabet.length, 32);
      expect(joinCodeLength, 10);
      for (final c in joinCodeAlphabet.split('')) {
        expect(isJoinCodeCharacter(c), isTrue, reason: c);
        expect(isJoinCodeCharacter(c.toLowerCase()), isTrue, reason: c);
      }
      for (final c in ['I', 'O', '0', '1', '-', ' ']) {
        expect(isJoinCodeCharacter(c), isFalse, reason: c);
      }
    });
  });
}
