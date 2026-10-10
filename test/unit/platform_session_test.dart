// Slice 8 (ADR-022, ADR-023): the platform and church-status session states,
// their routing, the platform models, and the per-context device copy.
import 'package:discipletrack/app/dock_shell.dart';
import 'package:discipletrack/app/router.dart';
import 'package:discipletrack/app/routes.dart';
import 'package:discipletrack/features/curriculum/domain/lesson_content.dart';
import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/membership/presentation/church_unavailable_page.dart';
import 'package:discipletrack/features/platform/domain/platform_models.dart';
import 'package:discipletrack/features/session/application/session_state.dart';
import 'package:flutter_test/flutter_test.dart';

SessionState _resolve({
  MembershipStatus? membership,
  bool onboarded = true,
  bool superAdmin = false,
  ChurchStatus church = ChurchStatus.active,
}) => resolveSessionState(
  hasSession: true,
  isLoading: false,
  hasError: false,
  membershipStatus: membership,
  onboardingCompleted: onboarded,
  isSuperAdmin: superAdmin,
  churchStatus: church,
);

LessonAccess _access(int n, {bool disciple = false, bool discipler = false}) =>
    LessonAccess(
      lessonId: 'lesson-$n',
      number: n,
      title: 'Lesson $n',
      discipleTier: disciple,
      disciplerTier: discipler,
    );

ContentBlock _block(String id, int lesson, ContentTier tier, {List? answers}) =>
    ContentBlock(
      blockId: id,
      lessonId: 'lesson-$lesson',
      ordinal: id.hashCode & 0xff,
      type: BlockType.fromDb('FILL_IN'),
      tier: tier,
      body: const {'text': 'God ___ the world.'},
      answers: answers,
    );

void main() {
  group('session state (ADR-022)', () {
    test('a Super Admin with no church membership is platform, never Join '
        'Church', () {
      expect(_resolve(superAdmin: true), SessionState.platform);
      expect(_resolve(), SessionState.noMembership);
    });

    test('a Super Admin who is also a member resolves by their membership', () {
      expect(
        _resolve(membership: MembershipStatus.active, superAdmin: true),
        SessionState.active,
      );
    });

    test('a PENDING or ACTIVE member of a SUSPENDED or ARCHIVED church is '
        'churchUnavailable', () {
      for (final church in [ChurchStatus.suspended, ChurchStatus.archived]) {
        expect(
          _resolve(membership: MembershipStatus.active, church: church),
          SessionState.churchUnavailable,
        );
        expect(
          _resolve(membership: MembershipStatus.pending, church: church),
          SessionState.churchUnavailable,
        );
        expect(
          _resolve(
            membership: MembershipStatus.active,
            onboarded: false,
            church: church,
          ),
          SessionState.churchUnavailable,
          reason: 'no welcome while the church is unavailable',
        );
      }
    });

    test('a membership that is itself INACTIVE stays noAccess, whatever the '
        'church', () {
      expect(
        _resolve(
          membership: MembershipStatus.inactive,
          church: ChurchStatus.suspended,
        ),
        SessionState.noAccess,
      );
    });

    test('still loading is unknown, so nothing flashes', () {
      expect(
        resolveSessionState(
          hasSession: true,
          isLoading: true,
          hasError: false,
          membershipStatus: null,
          isSuperAdmin: true,
        ),
        SessionState.unknown,
      );
    });
  });

  group('routing', () {
    test('platform goes to the Platform area; churchUnavailable to its own '
        'screen', () {
      expect(destinationFor(SessionState.platform), Routes.platform);
      expect(
        destinationFor(SessionState.churchUnavailable),
        Routes.churchUnavailable,
      );
    });

    test('a member of an unavailable church reaches only their profile', () {
      const state = SessionState.churchUnavailable;
      expect(redirectFor(state, Routes.profile), isNull);
      expect(redirectFor(state, Routes.home), Routes.churchUnavailable);
      expect(redirectFor(state, Routes.dGroups), Routes.churchUnavailable);
      expect(redirectFor(state, Routes.lessons), Routes.churchUnavailable);
      expect(redirectFor(state, Routes.churchInfo), Routes.churchUnavailable);
      expect(redirectFor(state, Routes.platform), Routes.churchUnavailable);
    });

    test('the Platform area is for a Super Admin, from any resolved state', () {
      for (final state in [
        SessionState.platform,
        SessionState.active,
        SessionState.pending,
        SessionState.churchUnavailable,
        SessionState.noAccess,
      ]) {
        for (final route in Routes.platformRoutes) {
          expect(
            redirectFor(state, route, isSuperAdmin: true),
            isNull,
            reason: '$state $route',
          );
        }
      }
      expect(
        redirectFor(SessionState.active, Routes.platform),
        Routes.home,
        reason: 'not without the role',
      );
      expect(
        redirectFor(SessionState.unknown, Routes.platform, isSuperAdmin: true),
        Routes.splash,
      );
    });

    test('a Super Admin without a membership never reaches church screens', () {
      expect(
        redirectFor(SessionState.platform, Routes.home, isSuperAdmin: true),
        Routes.platform,
      );
      expect(
        redirectFor(
          SessionState.platform,
          Routes.joinChurch,
          isSuperAdmin: true,
        ),
        Routes.platform,
      );
    });

    test('Church information is an ACTIVE member\'s route', () {
      expect(redirectFor(SessionState.active, Routes.churchInfo), isNull);
    });

    test('the platform dock is Churches and Profile', () {
      expect(platformDockItems.map((i) => i.label), ['Churches', 'Profile']);
      expect(platformDockItems.first.path, Routes.platform);
    });

    test('a lesson opened from the Curriculum carries the oversight view', () {
      expect(Routes.lessonFor('l1'), '/lessons/l1');
      expect(
        Routes.lessonFor('l1', forMembershipId: 'cm'),
        '/lessons/l1?for=cm',
      );
      expect(
        Routes.lessonFor('l1', oversight: true),
        '/lessons/l1?view=curriculum',
      );
      expect(Routes.curriculum, '/lessons?view=curriculum');
    });
  });

  group('church summary and join code', () {
    test('reads the status, and a row without one (a lookup) is ACTIVE', () {
      final s = ChurchSummary.fromMap({
        'id': 'c1',
        'name': 'Church',
        'status': 'SUSPENDED',
      });
      expect(s.status, ChurchStatus.suspended);
      expect(s.isAvailable, isFalse);
      expect(
        ChurchSummary.fromMap({'church_id': 'c1', 'church_name': 'Church'})
            .status,
        ChurchStatus.active,
      );
    });

    test('the code reads in two groups of five', () {
      expect(const ChurchJoinCode(code: '7QK4MZP2XR').grouped, '7QK4M ZP2XR');
    });

    test('the unavailable message follows the church and the membership', () {
      expect(
        churchUnavailableMessage(
          churchName: 'Grace',
          status: ChurchStatus.suspended,
          membership: MembershipStatus.active,
        ),
        contains(
          "isn't available on DiscipleTrack right now. Nothing has "
          'been deleted.',
        ),
      );
      expect(
        churchUnavailableMessage(
          churchName: 'Grace',
          status: ChurchStatus.suspended,
          membership: MembershipStatus.pending,
        ),
        contains('Your request to join is kept.'),
      );
      expect(
        churchUnavailableMessage(
          churchName: 'Grace',
          status: ChurchStatus.archived,
          membership: MembershipStatus.active,
        ),
        'Grace has been closed on DiscipleTrack. Its records are kept.',
      );
    });
  });

  group('platform models', () {
    test('a church row: counts, Coordinators and their one-line forms', () {
      final c = PlatformChurch.fromMap({
        'church_id': 'c1',
        'name': 'Grace Church',
        'status': 'ACTIVE',
        'join_code': '7QK4MZP2XR',
        'join_code_updated_at': '2026-10-08T00:00:00Z',
        'created_at': '2026-10-01T00:00:00Z',
        'members_active': 24,
        'members_pending': 2,
        'members_other': 1,
        'd_groups': 3,
        'coordinators': [
          {
            'membership_id': 'm1',
            'full_name': 'Ana Reyes',
            'email': 'a@x.test',
          },
        ],
      });
      expect(c.countsLine, '24 members · 3 D Groups');
      expect(c.coordinatorLine, 'Ana Reyes');
      expect(c.coordinators.single.email, 'a@x.test');
      expect(c.isArchived, isFalse);
    });

    test('the confirm step says why an account cannot be chosen', () {
      AccountPreview p(Map<String, dynamic> m) => AccountPreview.fromMap(m);
      expect(
        p({'account_found': false}).problem,
        contains('No DiscipleTrack account uses that email'),
      );
      expect(
        p({'account_found': true, 'email_confirmed': false}).problem,
        "That account hasn't confirmed its email yet.",
      );
      expect(
        p({
          'account_found': true,
          'email_confirmed': true,
          'membership': 'OTHER_CHURCH',
        }).problem,
        'That person already belongs to another church.',
      );
      expect(
        p({
          'account_found': true,
          'email_confirmed': true,
          'full_name': 'Ana Reyes',
          'membership': 'NONE',
        }).problem,
        isNull,
      );
    });

    test('every refusal the platform operations raise has its sentence', () {
      for (final reason in [
        'account_not_found',
        'email_not_confirmed',
        'member_of_another_church',
        'cannot_assign_self',
        'already_coordinator',
        'last_coordinator',
        'church_archived',
        'coordinator_required',
        'status_unchanged',
        'church_name_required',
        'church_not_found',
        'coordinator_not_found',
        'not_authorized',
      ]) {
        expect(PlatformFailure.messageFor(reason), isNotNull, reason: reason);
      }
      expect(PlatformFailure.messageFor('anything else'), isNull);
    });

    test('platform events read in plain words', () {
      PlatformEvent e(String action, [Map<String, dynamic>? m]) =>
          PlatformEvent.fromMap({
            'event_id': 'e',
            'created_at': '2026-10-08T00:00:00Z',
            'action': action,
            'metadata': m,
          });
      expect(e('CHURCH_CREATED').label, 'Church created');
      expect(
        e('CHURCH_STATUS_CHANGED', {'to': 'SUSPENDED'}).label,
        'Church suspended',
      );
      expect(e('JOIN_CODE_REGENERATED').label, 'Join code changed');
    });
  });

  group('the device copy reads through the opened context (ADR-023)', () {
    final copy = ReadableContent(
      userId: 'u1',
      savedAt: DateTime.utc(2026, 10, 8),
      lessons: [_access(1, disciple: true), _access(5)],
      contexts: {
        'cm-d': [
          _access(1, disciple: true, discipler: true),
          _access(5, disciple: true, discipler: true),
        ],
        'cm-led': [_access(1, disciple: true), _access(5)],
      },
      blocks: [
        _block(
          'd1',
          1,
          ContentTier.disciple,
          answers: const [
            ['loves'],
          ],
        ),
        _block('r1', 1, ContentTier.discipler),
        _block(
          'd5',
          5,
          ContentTier.disciple,
          answers: const [
            ['loves'],
          ],
        ),
        _block('r5', 5, ContentTier.discipler),
      ],
    );

    test('own context: only the own journey, never the Discipler tier or '
        'answers', () {
      final own = copy.lessonIn('lesson-1', null)!;
      expect(own.blocks.map((b) => b.blockId), ['d1']);
      expect(own.blocks.single.answers, isNull);
      expect(copy.lessonIn('lesson-5', null), isNull);
    });

    test('an assigned Disciple\'s context: both tiers with answers', () {
      final ctx = copy.lessonIn('lesson-5', 'cm-d')!;
      expect(ctx.blocks.map((b) => b.blockId).toSet(), {'d5', 'r5'});
      expect(
        ctx.blocks.firstWhere((b) => b.blockId == 'd5').answers,
        isNotNull,
      );
    });

    test('another Disciple of the group led: the Disciple tier of reached '
        'lessons, no answers', () {
      final led = copy.lessonIn('lesson-1', 'cm-led')!;
      expect(led.blocks.map((b) => b.blockId), ['d1']);
      expect(led.blocks.single.answers, isNull);
      expect(copy.lessonIn('lesson-5', 'cm-led'), isNull);
    });

    test('a context that was not saved opens nothing', () {
      expect(copy.accessFor('cm-unknown'), isNull);
      expect(copy.lessonIn('lesson-1', 'cm-unknown'), isNull);
    });

    test('round-trips, and a copy of the old version is ignored', () {
      final back = ReadableContent.fromJson(copy.toJson())!;
      expect(back.contexts.keys.toSet(), {'cm-d', 'cm-led'});
      expect(back.lessonIn('lesson-5', 'cm-d'), isNotNull);
      expect(ReadableContent.fromJson(copy.toJson()..['version'] = 1), isNull);
    });
  });
}
