import 'package:discipletrack/core/supabase/postgrest_failure.dart';
import 'package:discipletrack/features/ministry/data/ministry_repository.dart';
import 'package:discipletrack/features/ministry/domain/d_group.dart';
import 'package:discipletrack/features/ministry/domain/d_group_detail.dart';
import 'package:discipletrack/features/ministry/domain/d_group_invitation.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/member_option.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('DGroupInvitation expiry', () {
    final inv = DGroupInvitation(
      id: 'i',
      dGroupId: 'g',
      responsibility: DGroupResponsibility.disciple,
      status: DGroupInvitationStatus.pending,
      createdAt: DateTime.utc(2026, 9, 1),
      expiresAt: DateTime.utc(2026, 9, 15, 12),
    );

    test('a PENDING row before expires_at is open', () {
      final t = DateTime.utc(2026, 9, 10);
      expect(inv.statusAt(t), DGroupInvitationStatus.pending);
      expect(inv.isOpenAt(t), isTrue);
      expect(inv.daysLeftAt(t), 5);
    });

    test('a PENDING row at or after expires_at is EXPIRED in meaning', () {
      final at = DateTime.utc(2026, 9, 15, 12);
      expect(inv.statusAt(at), DGroupInvitationStatus.expired);
      expect(inv.isOpenAt(at), isFalse);
      expect(inv.daysLeftAt(at.add(const Duration(days: 2))), 0);
    });

    test('a closed status is never reinterpreted', () {
      final declined = DGroupInvitation(
        id: 'i',
        dGroupId: 'g',
        responsibility: DGroupResponsibility.disciple,
        status: DGroupInvitationStatus.declined,
        createdAt: DateTime.utc(2026, 9, 1),
        expiresAt: DateTime.utc(2026, 9, 15),
      );
      expect(
        declined.statusAt(DateTime.utc(2026, 12, 1)),
        DGroupInvitationStatus.declined,
      );
    });
  });

  group('fromMap', () {
    test('DGroupSummary counts active responsibilities and finds the '
        'Leader', () {
      final s = DGroupSummary.fromMap({
        'id': 'g',
        'name': 'Young Adults A',
        'description': null,
        'status': 'ACTIVE',
        'members': [
          {
            'responsibility': 'LEADER',
            'member': {
              'profile': {'full_name': 'Ana'},
            },
          },
          {'responsibility': 'DISCIPLER', 'member': null},
          {'responsibility': 'DISCIPLE', 'member': null},
          {'responsibility': 'DISCIPLE', 'member': null},
        ],
      });
      expect(s.group.status, DGroupStatus.active);
      expect(s.leaderName, 'Ana');
      expect(s.disciplerCount, 1);
      expect(s.discipleCount, 2);
    });

    test('DGroupMember reads the embedded name and phone, with a visible '
        'fallback', () {
      final m = DGroupMember.fromMap({
        'id': 'dgm',
        'church_membership_id': 'cm',
        'responsibility': 'DISCIPLER',
        'started_at': '2026-09-01T00:00:00Z',
        'member': {
          'profile': {'full_name': 'Ben', 'phone': '+63 1'},
        },
      });
      expect(m.fullName, 'Ben');
      expect(m.phone, '+63 1');
      expect(m.responsibility, DGroupResponsibility.discipler);

      final hidden = DGroupMember.fromMap({
        'id': 'dgm',
        'church_membership_id': 'cm',
        'responsibility': 'DISCIPLE',
        'started_at': '2026-09-01T00:00:00Z',
        'member': null,
      });
      expect(hidden.fullName, 'Unnamed member');
    });

    test('MemberOption reads placement and the pending flag', () {
      final o = MemberOption.fromMap({
        'church_membership_id': 'cm',
        'full_name': 'Ana',
        'current_d_group_id': 'g',
        'current_d_group_name': 'Young Adults A',
        'current_responsibilities': ['DISCIPLER', 'LEADER'],
        'has_pending_invitation': false,
      });
      expect(o.isPlaced, isTrue);
      expect(o.placementLabel, 'Leader and Discipler in Young Adults A');
    });

    test('get_my_pending_invitation() rows', () {
      final i = DGroupInvitation.fromPendingMap({
        'invitation_id': 'i',
        'd_group_id': 'g',
        'd_group_name': 'Young Adults A',
        'responsibility': 'DISCIPLE',
        'invited_by_name': 'Ana',
        'created_at': '2026-09-28T00:00:00Z',
        'expires_at': '2026-10-12T00:00:00Z',
      });
      expect(i.status, DGroupInvitationStatus.pending);
      expect(i.dGroupName, 'Young Adults A');
      expect(i.invitedByName, 'Ana');
    });

    test('MinistryContext from roster rows; empty means unplaced', () {
      expect(MinistryContext.fromRosterRows(const []), isNull);

      Map<String, dynamic> row(
        String id,
        String r, {
        bool me = false,
        bool leader = false,
        bool discipler = false,
      }) => {
        'd_group_id': 'g',
        'd_group_name': 'Young Adults A',
        'd_group_membership_id': 'dgm-$id',
        'church_membership_id': 'cm-$id',
        'full_name': id,
        'responsibility': r,
        'phone': null,
        'is_me': me,
        'is_my_leader': leader,
        'is_my_discipler': discipler,
        'is_my_disciple': false,
      };

      final c = MinistryContext.fromRosterRows([
        row('ana', 'LEADER', leader: true),
        row('ben', 'DISCIPLER', discipler: true),
        row('cara', 'DISCIPLE', me: true),
        row('dan', 'DISCIPLE'),
      ])!;
      expect(c.isDisciple, isTrue);
      expect(c.isLeader, isFalse);
      expect(c.leader!.fullName, 'ana');
      expect(c.myDiscipler!.fullName, 'ben');
      expect(c.groupMates.map((e) => e.fullName), ['ana', 'ben', 'dan']);
    });

    test('groupMates lists a person with two responsibilities once', () {
      final c = MinistryContext(
        dGroupId: 'g',
        dGroupName: 'G',
        roster: const [
          RosterEntry(
            dGroupMembershipId: '1',
            churchMembershipId: 'ana',
            fullName: 'Ana',
            responsibility: DGroupResponsibility.leader,
          ),
          RosterEntry(
            dGroupMembershipId: '2',
            churchMembershipId: 'ana',
            fullName: 'Ana',
            responsibility: DGroupResponsibility.discipler,
          ),
          RosterEntry(
            dGroupMembershipId: '3',
            churchMembershipId: 'me',
            fullName: 'Me',
            responsibility: DGroupResponsibility.disciple,
            isMe: true,
          ),
        ],
      );
      expect(c.groupMates, hasLength(1));
    });
  });

  group('MemberOption.ineligibilityReason', () {
    const free = MemberOption(
      churchMembershipId: 'a',
      fullName: 'Free',
      hasPendingInvitation: false,
    );
    const pending = MemberOption(
      churchMembershipId: 'b',
      fullName: 'Pending',
      hasPendingInvitation: true,
    );
    const disciplerHere = MemberOption(
      churchMembershipId: 'c',
      fullName: 'Discipler',
      hasPendingInvitation: false,
      currentDGroupId: 'g',
      currentDGroupName: 'G',
      currentResponsibilities: {DGroupResponsibility.discipler},
    );
    const leaderHere = MemberOption(
      churchMembershipId: 'd',
      fullName: 'Leader',
      hasPendingInvitation: false,
      currentDGroupId: 'g',
      currentDGroupName: 'G',
      currentResponsibilities: {
        DGroupResponsibility.leader,
        DGroupResponsibility.discipler,
      },
    );
    const discipleElsewhere = MemberOption(
      churchMembershipId: 'e',
      fullName: 'Elsewhere',
      hasPendingInvitation: false,
      currentDGroupId: 'h',
      currentDGroupName: 'H',
      currentResponsibilities: {DGroupResponsibility.disciple},
    );

    test('invite: unplaced with no pending invitation only', () {
      expect(free.ineligibilityReason(MemberPickPurpose.invite), isNull);
      expect(
        pending.ineligibilityReason(MemberPickPurpose.invite),
        'Has a pending invitation',
      );
      expect(
        discipleElsewhere.ineligibilityReason(MemberPickPurpose.invite),
        'Already Disciple in H',
      );
    });

    test('appoint Leader: a pending invitation does not block', () {
      expect(
        pending.ineligibilityReason(MemberPickPurpose.appointLeader),
        isNull,
      );
    });

    test('appoint Leader: a Discipler of this group may lead it', () {
      expect(
        disciplerHere.ineligibilityReason(
          MemberPickPurpose.appointLeader,
          dGroupId: 'g',
        ),
        isNull,
      );
      expect(
        disciplerHere.ineligibilityReason(MemberPickPurpose.appointLeader),
        'Already Discipler in G',
        reason: 'a new group needs an unplaced Leader',
      );
    });

    test('appoint Leader: the current Leader and people placed elsewhere '
        'are refused', () {
      expect(
        leaderHere.ineligibilityReason(
          MemberPickPurpose.appointLeader,
          dGroupId: 'g',
        ),
        'Already leads this group',
      );
      expect(
        discipleElsewhere.ineligibilityReason(
          MemberPickPurpose.appointLeader,
          dGroupId: 'g',
        ),
        'Already Disciple in H',
      );
    });
  });

  group('DGroupDetail invitations', () {
    final now = DateTime.utc(2026, 10, 1);
    DGroupInvitation inv(
      String id,
      String member,
      DGroupInvitationStatus status, {
      required DateTime created,
      DateTime? responded,
    }) => DGroupInvitation(
      id: id,
      dGroupId: 'g',
      churchMembershipId: member,
      inviteeName: member,
      responsibility: DGroupResponsibility.disciple,
      status: status,
      createdAt: created,
      expiresAt: created.add(const Duration(days: 14)),
      respondedAt: responded,
    );

    DGroupDetail detail(List<DGroupInvitation> invitations) => DGroupDetail(
      group: const DGroup(id: 'g', name: 'G', status: DGroupStatus.active),
      members: [
        DGroupMember(
          dGroupMembershipId: 'dgm-placed',
          churchMembershipId: 'placed',
          fullName: 'Placed',
          responsibility: DGroupResponsibility.disciple,
          startedAt: DateTime.utc(2026, 9, 1),
        ),
      ],
      assignments: const [],
      invitations: invitations,
    );

    test('open invitations exclude lapsed PENDING rows', () {
      final d = detail([
        inv(
          'live',
          'a',
          DGroupInvitationStatus.pending,
          created: DateTime.utc(2026, 9, 25),
        ),
        inv(
          'lapsed',
          'b',
          DGroupInvitationStatus.pending,
          created: DateTime.utc(2026, 9, 10),
        ),
      ]);
      expect(d.openInvitationsAt(now).map((i) => i.id), ['live']);
    });

    test('closed invitations: newest per person, recent, declined or '
        'expired, and not since placed', () {
      final d = detail([
        // Newest first, as the repository orders them.
        inv(
          'reinvited',
          'a',
          DGroupInvitationStatus.pending,
          created: DateTime.utc(2026, 9, 29),
        ),
        inv(
          'declined-old-for-a',
          'a',
          DGroupInvitationStatus.declined,
          created: DateTime.utc(2026, 9, 20),
          responded: DateTime.utc(2026, 9, 21),
        ),
        inv(
          'declined',
          'c',
          DGroupInvitationStatus.declined,
          created: DateTime.utc(2026, 9, 26),
          responded: DateTime.utc(2026, 9, 27),
        ),
        inv(
          'lapsed',
          'd',
          DGroupInvitationStatus.pending,
          created: DateTime.utc(2026, 9, 10),
        ),
        inv(
          'placed-since',
          'placed',
          DGroupInvitationStatus.declined,
          created: DateTime.utc(2026, 9, 22),
          responded: DateTime.utc(2026, 9, 23),
        ),
        inv(
          'withdrawn',
          'e',
          DGroupInvitationStatus.withdrawn,
          created: DateTime.utc(2026, 9, 22),
          responded: DateTime.utc(2026, 9, 23),
        ),
        inv(
          'too-old',
          'f',
          DGroupInvitationStatus.declined,
          created: DateTime.utc(2026, 8, 1),
          responded: DateTime.utc(2026, 8, 2),
        ),
      ]);
      expect(d.closedInvitationsAt(now).map((i) => i.id), [
        'declined',
        'lapsed',
      ]);
    });
  });

  group('MinistryRepository.failureFrom', () {
    MinistryFailure of(String message, String code) =>
        MinistryRepository.failureFrom(
          PostgrestException(message: message, code: code),
          'Fallback.',
        );

    test('a known reason gets its wording and keeps code and reason', () {
      final f = of('member_already_placed', 'PT409');
      expect(f.message, 'That person is already in a D Group.');
      expect(f.code, DbFailureCode.conflict);
      expect(f.reason, 'member_already_placed');
    });

    test('authority failures use the shared wording', () {
      expect(
        of('not_authorized', 'PT403').message,
        'You are not allowed to do that.',
      );
      expect(of('anything', '42501').code, DbFailureCode.forbidden);
    });

    test('an unknown reason falls back', () {
      expect(of('something_new', 'XX000').message, 'Fallback.');
    });
  });
}
