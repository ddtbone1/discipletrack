import 'package:discipletrack/features/membership/data/membership_repository.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/membership_review/domain/membership_request.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('ChurchMembership', () {
    final row = <String, dynamic>{
      'id': 'm1',
      'church_id': 'c1',
      'user_id': 'u1',
      'status': 'ACTIVE',
      'joined_at': '2026-09-25T10:00:00+00:00',
      'approved_at': '2026-09-25T10:00:00+00:00',
      'created_at': '2026-09-24T08:00:00+00:00',
      'onboarding_completed_at': null,
    };

    test('parses every column the repository selects', () {
      final m = ChurchMembership.fromMap(row);
      expect(m.status, MembershipStatus.active);
      expect(m.joinedAt, DateTime.utc(2026, 9, 25, 10));
      expect(m.approvedAt, DateTime.utc(2026, 9, 25, 10));
      expect(m.requestedAt, DateTime.utc(2026, 9, 24, 8));
      expect(m.onboardingCompletedAt, isNull);
      expect(m.needsFirstEntry, isTrue);
    });

    test(
      'completing onboarding changes equality, so the router re-resolves',
      () {
        final before = ChurchMembership.fromMap(row);
        final after = ChurchMembership.fromMap({
          ...row,
          'onboarding_completed_at': '2026-09-25T10:05:00+00:00',
        });
        expect(before, isNot(equals(after)));
        expect(after.needsFirstEntry, isFalse);
      },
    );

    test('a PENDING membership never needs first entry', () {
      final m = ChurchMembership.fromMap({...row, 'status': 'PENDING'});
      expect(m.needsFirstEntry, isFalse);
    });
  });

  group('ChurchSummary', () {
    test('reads both the RPC shape and the table shape', () {
      expect(
        ChurchSummary.fromMap({'church_id': 'c1', 'church_name': 'Bankal'}),
        const ChurchSummary(id: 'c1', name: 'Bankal'),
      );
      expect(
        ChurchSummary.fromMap({'id': 'c1', 'name': 'Bankal'}),
        const ChurchSummary(id: 'c1', name: 'Bankal'),
      );
    });
  });

  group('MembershipRequest', () {
    test('reads the embedded profile name and request date', () {
      final r = MembershipRequest.fromMap({
        'id': 'm1',
        'created_at': '2026-09-25T09:00:00+00:00',
        'status': 'PENDING',
        'profiles': {'full_name': 'Juan Dela Cruz'},
      });
      expect(r.fullName, 'Juan Dela Cruz');
      expect(r.requestedAt, DateTime.utc(2026, 9, 25, 9));
    });

    test('a missing profile is visible rather than blank', () {
      final r = MembershipRequest.fromMap({
        'id': 'm1',
        'created_at': '2026-09-25T09:00:00+00:00',
        'profiles': null,
      });
      expect(r.fullName, 'Unnamed member');
    });
  });

  group('JoinRequestOutcome', () {
    test('maps every database outcome', () {
      expect(
        JoinRequestOutcome.fromDb('REQUESTED'),
        JoinRequestOutcome.requested,
      );
      expect(
        JoinRequestOutcome.fromDb('ALREADY_PENDING'),
        JoinRequestOutcome.alreadyPending,
      );
      expect(
        JoinRequestOutcome.fromDb('ALREADY_ACTIVE'),
        JoinRequestOutcome.alreadyActive,
      );
      expect(
        JoinRequestOutcome.fromDb('NOT_REQUESTABLE'),
        JoinRequestOutcome.notRequestable,
      );
      expect(
        JoinRequestOutcome.fromDb('INVALID_CODE'),
        JoinRequestOutcome.invalidCode,
      );
    });
  });

  group('MembershipRepository error mapping', () {
    test('maps PostgREST status SQLSTATEs to failure codes', () {
      MembershipFailureCode of(String code) => MembershipRepository.codeOf(
        PostgrestException(message: 'x', code: code),
      );
      expect(of('PT429'), MembershipFailureCode.rateLimited);
      expect(of('PT401'), MembershipFailureCode.unauthenticated);
      expect(of('PT403'), MembershipFailureCode.forbidden);
      expect(of('42501'), MembershipFailureCode.forbidden);
      expect(of('PT404'), MembershipFailureCode.notFound);
      expect(of('PT409'), MembershipFailureCode.conflict);
      expect(of('XX000'), MembershipFailureCode.unknown);
    });

    test('a rate limit gets its own message', () {
      expect(
        MembershipRepository.friendlyMessage(
          const PostgrestException(message: 'rate_limited', code: 'PT429'),
          'fallback',
        ),
        'Too many attempts. Try again in a few minutes.',
      );
      expect(
        MembershipRepository.friendlyMessage(
          const PostgrestException(message: 'boom', code: 'XX000'),
          'fallback',
        ),
        'fallback',
      );
    });
  });
}
