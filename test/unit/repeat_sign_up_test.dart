import 'package:discipletrack/features/auth/data/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthRepository.isRepeatSignUp', () {
    test('a new account has its code sent within milliseconds', () {
      expect(
        AuthRepository.isRepeatSignUp(
          createdAt: '2026-09-24T08:00:00.120000Z',
          confirmationSentAt: '2026-09-24T08:00:00.480000Z',
        ),
        isFalse,
      );
    });

    test('an older unverified account is re-sent a code later', () {
      expect(
        AuthRepository.isRepeatSignUp(
          createdAt: '2026-09-23T08:00:00Z',
          confirmationSentAt: '2026-09-24T08:00:00Z',
        ),
        isTrue,
      );
    });

    test('the gap must exceed ten seconds', () {
      expect(
        AuthRepository.isRepeatSignUp(
          createdAt: '2026-09-24T08:00:00Z',
          confirmationSentAt: '2026-09-24T08:00:10Z',
        ),
        isFalse,
      );
      expect(
        AuthRepository.isRepeatSignUp(
          createdAt: '2026-09-24T08:00:00Z',
          confirmationSentAt: '2026-09-24T08:00:11Z',
        ),
        isTrue,
      );
    });

    test('timezone offsets are compared as instants', () {
      expect(
        AuthRepository.isRepeatSignUp(
          createdAt: '2026-09-24T16:00:00+08:00',
          confirmationSentAt: '2026-09-24T08:00:00.300Z',
        ),
        isFalse,
      );
    });

    test('a missing or unparseable timestamp is treated as new', () {
      expect(
        AuthRepository.isRepeatSignUp(
          createdAt: '2026-09-23T08:00:00Z',
          confirmationSentAt: null,
        ),
        isFalse,
      );
      expect(
        AuthRepository.isRepeatSignUp(
          createdAt: 'not a date',
          confirmationSentAt: '2026-09-24T08:00:00Z',
        ),
        isFalse,
      );
    });
  });
}
