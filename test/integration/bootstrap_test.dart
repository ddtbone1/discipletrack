/// Verifies the DC section 0 postconditions against the church provisioned by
/// supabase/seed.sql, and that bootstrap is unreachable through the API.
///
/// Requires `npx supabase db reset` to have run against the local stack.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  group('bootstrap postconditions (DC section 0)', () {
    test(
      'exactly one ACTIVE church with the seeded id and a valid code',
      () async {
        final churches = await service
            .from('churches')
            .select('id, name, join_code, status')
            .eq('id', seededChurchId);
        expect(churches, hasLength(1));
        expect(churches.single['status'], 'ACTIVE');
        expect(churches.single['name'], seededChurchName);
        expect(
          churches.single['join_code'],
          matches(RegExp(r'^[A-HJ-NP-Z2-9]{10}$')),
        );
      },
    );

    test(
      'church_settings hold both thresholds at 3 and due days at 7',
      () async {
        final settings = await service
            .from('church_settings')
            .select(
              'consecutive_absence_threshold, '
              'consecutive_missed_meeting_threshold, follow_up_due_days',
            )
            .eq('church_id', seededChurchId)
            .single();
        expect(settings['consecutive_absence_threshold'], 3);
        expect(settings['consecutive_missed_meeting_threshold'], 3);
        expect(settings['follow_up_due_days'], 7);
      },
    );

    test('the initial user holds an ACTIVE membership with ADMIN and '
        'COORDINATOR, and no approver of their own', () async {
      final membership = await service
          .from('church_memberships')
          .select('id, status, joined_at, approved_by, approved_at')
          .eq('church_id', seededChurchId)
          .eq('user_id', seededAdminUserId)
          .single();
      expect(membership['status'], 'ACTIVE');
      expect(membership['joined_at'], isNotNull);
      expect(membership['approved_by'], isNull);
      expect(membership['approved_at'], isNull);

      final roles = await service
          .from('church_role_assignments')
          .select('role, ended_at')
          .eq('church_membership_id', membership['id'] as String);
      expect(roles.map((r) => r['role']).toSet(), {'ADMIN', 'COORDINATOR'});
      expect(roles.every((r) => r['ended_at'] == null), isTrue);
    });

    test(
      'one ACTIVE curriculum with twelve lessons of four meetings',
      () async {
        final curricula = await service
            .from('curricula')
            .select('id, status')
            .eq('church_id', seededChurchId);
        expect(curricula.where((c) => c['status'] == 'ACTIVE'), hasLength(1));

        final lessons = await service
            .from('curriculum_lessons')
            .select('lesson_number, required_meetings')
            .eq('curriculum_id', curricula.single['id'] as String)
            .order('lesson_number', ascending: true);
        expect(lessons, hasLength(12));
        expect(
          lessons.map((l) => l['lesson_number']),
          List.generate(12, (i) => i + 1),
        );
        expect(lessons.every((l) => l['required_meetings'] == 4), isTrue);
      },
    );

    test('a CHURCH_BOOTSTRAPPED audit event exists', () async {
      final events = await service
          .from('audit_events')
          .select('action, entity_type, entity_id')
          .eq('church_id', seededChurchId)
          .eq('action', 'CHURCH_BOOTSTRAPPED');
      expect(events, hasLength(1));
      expect(events.single['entity_type'], 'churches');
      expect(events.single['entity_id'], seededChurchId);
    });

    test('the seeded admin can sign in', () async {
      final client = anonClient();
      final res = await client.auth.signInWithPassword(
        email: seededAdminEmail,
        password: seededAdminPassword,
      );
      expect(res.session, isNotNull);
      expect(res.user!.id, seededAdminUserId);
    });
  });

  group('bootstrap is not an API operation', () {
    test('bootstrap_church has no PostgREST endpoint for any role', () async {
      // The function lives in the `private` schema, which is not exposed.
      for (final client in [anonClient(), service]) {
        await expectLater(
          client.rpc<dynamic>('bootstrap_church'),
          throwsA(isA<PostgrestException>()),
        );
      }
    });

    test('nor does generate_join_code', () async {
      await expectLater(
        service.rpc<dynamic>('generate_join_code'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
