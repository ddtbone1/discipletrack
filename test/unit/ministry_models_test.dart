import 'package:discipletrack/core/supabase/postgrest_failure.dart';
import 'package:discipletrack/features/ministry/data/ministry_repository.dart';
import 'package:discipletrack/features/ministry/domain/d_group.dart';
import 'package:discipletrack/features/ministry/domain/d_group_detail.dart';
import 'package:discipletrack/features/ministry/domain/d_group_member.dart';
import 'package:discipletrack/features/ministry/domain/d_group_placement.dart';
import 'package:discipletrack/features/ministry/domain/discipler_assignment.dart';
import 'package:discipletrack/features/ministry/domain/discipler_candidate.dart';
import 'package:discipletrack/features/ministry/domain/member_option.dart';
import 'package:discipletrack/features/ministry/domain/ministry_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

DGroupPlacement _placement(String id) => DGroupPlacement(
  placementId: 'pl-$id',
  churchMembershipId: id,
  fullName: id,
  startedAt: DateTime.utc(2026, 9, 1),
);

DGroupMember _row(String id, DGroupResponsibility r) => DGroupMember(
  dGroupMembershipId: '${r.toDb}-$id',
  churchMembershipId: id,
  fullName: id,
  responsibility: r,
  startedAt: DateTime.utc(2026, 9, 1),
  disciplerBasis: r == DGroupResponsibility.discipler
      ? DisciplerBasis.initialRollout
      : null,
);

DisciplerAssignment _pair(String discipler, String disciple) =>
    DisciplerAssignment(
      id: 'a-$discipler-$disciple',
      disciplerDGroupMembershipId: 'DISCIPLER-$discipler',
      discipleDGroupMembershipId: 'DISCIPLE-$disciple',
      startedAt: DateTime.utc(2026, 9, 2),
    );

void main() {
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

    test('DGroupMember reads the embedded name, phone and basis, with a '
        'visible fallback', () {
      final m = DGroupMember.fromMap({
        'id': 'dgm',
        'church_membership_id': 'cm',
        'responsibility': 'DISCIPLER',
        'started_at': '2026-09-01T00:00:00Z',
        'discipler_basis': 'APPOINTMENT',
        'member': {
          'profile': {'full_name': 'Ben', 'phone': '+63 1'},
        },
      });
      expect(m.fullName, 'Ben');
      expect(m.phone, '+63 1');
      expect(m.responsibility, DGroupResponsibility.discipler);
      expect(m.disciplerBasis, DisciplerBasis.appointment);

      final hidden = DGroupMember.fromMap({
        'id': 'dgm',
        'church_membership_id': 'cm',
        'responsibility': 'DISCIPLE',
        'started_at': '2026-09-01T00:00:00Z',
        'member': null,
      });
      expect(hidden.fullName, 'Unnamed member');
      expect(hidden.disciplerBasis, isNull);
    });

    test('DisciplerCandidate reads eligible-since', () {
      final c = DisciplerCandidate.fromMap({
        'church_membership_id': 'cm',
        'full_name': 'Ana',
        'd_group_id': 'g',
        'd_group_name': 'Young Adults A',
        'eligible_since': '2026-09-30T12:00:00+00:00',
      });
      expect(c.eligibleSince, DateTime.utc(2026, 9, 30, 12));
      expect(c.dGroupName, 'Young Adults A');
    });

    test('DGroupPlacement and AddableMember', () {
      final p = DGroupPlacement.fromMap({
        'id': 'pl',
        'church_membership_id': 'cm',
        'started_at': '2026-10-01T00:00:00Z',
        'member': {
          'profile': {'full_name': 'Cara', 'phone': null},
        },
      });
      expect(p.placementId, 'pl');
      expect(p.fullName, 'Cara');

      final a = AddableMember.fromMap({
        'church_membership_id': 'cm',
        'full_name': 'Dan',
        'joined_at': null,
      });
      expect(a.fullName, 'Dan');
      expect(a.joinedAt, isNull);
    });

    test('MemberOption reads placement; an empty list means not set up', () {
      final o = MemberOption.fromMap({
        'church_membership_id': 'cm',
        'full_name': 'Ana',
        'current_d_group_id': 'g',
        'current_d_group_name': 'Young Adults A',
        'current_responsibilities': ['DISCIPLER', 'LEADER'],
      });
      expect(o.isPlaced, isTrue);
      expect(o.placementLabel, 'Leader and Discipler in Young Adults A');

      final waiting = MemberOption.fromMap({
        'church_membership_id': 'cm2',
        'full_name': 'Ben',
        'current_d_group_id': 'g',
        'current_d_group_name': 'Young Adults A',
        'current_responsibilities': <String>[],
      });
      expect(waiting.placementLabel, 'In Young Adults A, not set up yet');
    });

    Map<String, dynamic> rosterRow(
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

    test('MinistryContext from roster rows; empty means in no group', () {
      expect(MinistryContext.fromRosterRows(const []), isNull);

      final c = MinistryContext.fromRosterRows([
        rosterRow('ana', 'LEADER', leader: true),
        rosterRow('ben', 'DISCIPLER', discipler: true),
        rosterRow('cara', 'DISCIPLE', me: true),
        rosterRow('dan', 'DISCIPLE'),
      ])!;
      expect(c.isDisciple, isTrue);
      expect(c.isLeader, isFalse);
      expect(c.needsSetup, isFalse);
      expect(c.leader!.fullName, 'ana');
      expect(c.myDiscipler!.fullName, 'ben');
      expect(c.groupMates.map((e) => e.fullName), ['ana', 'ben', 'dan']);
    });

    test('MinistryContext with only the Leader\'s row needs setup', () {
      final c = MinistryContext.fromRosterRows([
        rosterRow('ana', 'LEADER', leader: true),
      ])!;
      expect(c.needsSetup, isTrue);
      expect(c.leader!.fullName, 'ana');
      expect(c.dGroupName, 'Young Adults A');
    });

    test('the group size counts everyone placed, set up or not', () {
      final withCount = MinistryContext.fromRosterRows([
        {
          ...rosterRow('ana', 'LEADER', leader: true),
          'd_group_member_count': 12,
        },
      ])!;
      expect(withCount.memberCount, 12);
      expect(withCount.groupSize, 12);

      // An older snapshot without the count falls back to the roster.
      final without = MinistryContext.fromRosterRows([
        rosterRow('ana', 'LEADER', leader: true),
        rosterRow('ben', 'DISCIPLE', me: true),
      ])!;
      expect(without.memberCount, isNull);
      expect(without.groupSize, 2);
    });

    test(
      'DGroupSummary counts placements separately from responsibilities',
      () {
        final s = DGroupSummary.fromMap({
          'id': 'g',
          'name': 'G',
          'description': null,
          'status': 'ACTIVE',
          'members': [
            {'responsibility': 'LEADER', 'member': null},
            {'responsibility': 'DISCIPLE', 'member': null},
          ],
          'placements': [
            {'id': 'p1', 'ended_at': null},
            {'id': 'p2', 'ended_at': null},
            {'id': 'p3', 'ended_at': null},
          ],
        });
        expect(s.memberCount, 3, reason: 'includes someone not set up yet');
        expect(s.discipleCount, 1);
      },
    );

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

  group('MemberOption.ineligibilityReason (choosing a Leader)', () {
    const free = MemberOption(churchMembershipId: 'a', fullName: 'Free');
    const disciplerHere = MemberOption(
      churchMembershipId: 'c',
      fullName: 'Discipler',
      currentDGroupId: 'g',
      currentDGroupName: 'G',
      currentResponsibilities: {DGroupResponsibility.discipler},
    );
    const waitingHere = MemberOption(
      churchMembershipId: 'w',
      fullName: 'Waiting',
      currentDGroupId: 'g',
      currentDGroupName: 'G',
    );
    const discipleHere = MemberOption(
      churchMembershipId: 'dd',
      fullName: 'Disciple',
      currentDGroupId: 'g',
      currentDGroupName: 'G',
      currentResponsibilities: {DGroupResponsibility.disciple},
    );
    const leaderHere = MemberOption(
      churchMembershipId: 'd',
      fullName: 'Leader',
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
      currentDGroupId: 'h',
      currentDGroupName: 'H',
      currentResponsibilities: {DGroupResponsibility.disciple},
    );

    const purpose = MemberPickPurpose.appointLeader;

    test('someone in no group may lead', () {
      expect(free.ineligibilityReason(purpose), isNull);
    });

    test(
      'a Discipler or a not-yet-set-up member of this group may lead it',
      () {
        expect(
          disciplerHere.ineligibilityReason(purpose, dGroupId: 'g'),
          isNull,
        );
        expect(waitingHere.ineligibilityReason(purpose, dGroupId: 'g'), isNull);
        expect(
          disciplerHere.ineligibilityReason(purpose),
          'Already Discipler in G',
          reason: 'a new group needs a Leader in no group',
        );
      },
    );

    test(
      'the current Leader, a Disciple, and people elsewhere are refused',
      () {
        expect(
          leaderHere.ineligibilityReason(purpose, dGroupId: 'g'),
          'Already leads this group',
        );
        expect(
          discipleHere.ineligibilityReason(purpose, dGroupId: 'g'),
          'A Disciple cannot also lead the group',
        );
        expect(
          discipleElsewhere.ineligibilityReason(purpose, dGroupId: 'g'),
          'Already Disciple in H',
        );
      },
    );
  });

  group('DGroupDetail people and filters', () {
    // lea leads; dino disciples diana; ella is both Disciple (paired with
    // dino) and Discipler of felix; gus still needs setup.
    final detail = DGroupDetail(
      group: const DGroup(id: 'g', name: 'G', status: DGroupStatus.active),
      placements: [
        for (final id in ['lea', 'dino', 'diana', 'ella', 'felix', 'gus'])
          _placement(id),
      ],
      members: [
        _row('lea', DGroupResponsibility.leader),
        _row('dino', DGroupResponsibility.discipler),
        _row('diana', DGroupResponsibility.disciple),
        _row('ella', DGroupResponsibility.disciple),
        _row('ella', DGroupResponsibility.discipler),
        _row('felix', DGroupResponsibility.disciple),
      ],
      assignments: [
        _pair('dino', 'diana'),
        _pair('dino', 'ella'),
        _pair('ella', 'felix'),
      ],
    );

    test('the Leader holding nothing else is left to the Leader card', () {
      expect(detail.people.map((p) => p.fullName), [
        'diana',
        'dino',
        'ella',
        'felix',
        'gus',
      ]);
    });

    test('Needs setup is a placement with no responsibility', () {
      final gus = detail.people.singleWhere((p) => p.fullName == 'gus');
      expect(gus.needsSetup, isTrue);
      final ella = detail.people.singleWhere((p) => p.fullName == 'ella');
      expect(ella.needsSetup, isFalse);
      expect(ella.isDisciple && ella.isDiscipler, isTrue);
    });

    test('filter counts count a Disciple-Discipler under both', () {
      expect(detail.filterCounts, {
        GroupFilter.all: 5,
        GroupFilter.disciples: 3,
        GroupFilter.disciplers: 2,
        GroupFilter.needsSetup: 1,
      });
    });

    test('pairable Disciplers exclude the person themselves and anyone they '
        'disciple (D7)', () {
      final felix = detail.disciples.singleWhere((d) => d.fullName == 'felix');
      expect(detail.pairableDisciplersFor(felix).map((d) => d.fullName), [
        'dino',
        'ella',
      ]);

      final ella = detail.disciples.singleWhere((d) => d.fullName == 'ella');
      expect(detail.pairableDisciplersFor(ella).map((d) => d.fullName), [
        'dino',
      ], reason: 'not herself');

      // dino is discipled by nobody here; if felix were a Discipler, ella
      // could not be paired with him while she disciples him.
      final withFelix = DGroupDetail(
        group: detail.group,
        placements: detail.placements,
        members: [
          ...detail.members,
          _row('felix', DGroupResponsibility.discipler),
        ],
        assignments: detail.assignments,
      );
      final ella2 = withFelix.disciples.singleWhere(
        (d) => d.fullName == 'ella',
      );
      expect(withFelix.pairableDisciplersFor(ella2).map((d) => d.fullName), [
        'dino',
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
      expect(f.message, contains('just added to another D Group'));
      expect(f.code, DbFailureCode.conflict);
      expect(f.reason, 'member_already_placed');
    });

    test('Slice 6 reasons have wording', () {
      for (final reason in [
        'initial_setup_closed',
        'cannot_pair_with_self',
        'reciprocal_pairing',
        'leader_cannot_be_disciple',
        'leader_cannot_be_removed',
        'already_disciple',
      ]) {
        expect(of(reason, 'PT409').message, isNot('Fallback.'), reason: reason);
      }
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
