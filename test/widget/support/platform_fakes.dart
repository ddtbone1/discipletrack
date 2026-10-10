/// A fake of the platform operations (Migration 024): configured answers and
/// a record of every call, so a test can prove that cancelling a
/// confirmation changes nothing.
library;

import 'package:discipletrack/features/membership/domain/church_membership.dart';
import 'package:discipletrack/features/platform/data/platform_repository.dart';
import 'package:discipletrack/features/platform/domain/platform_models.dart';

PlatformChurch samplePlatformChurch({
  String id = 'church-1',
  String name = 'Grace Church',
  ChurchStatus status = ChurchStatus.active,
  List<CoordinatorRef> coordinators = const [
    CoordinatorRef(
      membershipId: 'cm-ana',
      fullName: 'Ana Reyes',
      email: 'ana@example.test',
    ),
  ],
}) => PlatformChurch(
  id: id,
  name: name,
  status: status,
  joinCode: '7QK4MZP2XR',
  joinCodeSetAt: DateTime.utc(2026, 10, 1),
  createdAt: DateTime.utc(2026, 10, 1),
  membersActive: 24,
  membersPending: 2,
  membersOther: 1,
  dGroups: 3,
  coordinators: coordinators,
);

class FakePlatformRepository implements PlatformRepository {
  List<PlatformChurch> churches = [];

  /// The confirm step's answer per email; an unknown email is not found.
  Map<String, AccountPreview> previews = {};

  PlatformFailure? failure;

  final calls = <String>[];

  void _call(String name) {
    calls.add(name);
    if (failure != null) throw failure!;
  }

  @override
  Future<Set<PlatformRole>> fetchMyRoles(String userId) async => const {};

  @override
  Future<List<PlatformChurch>> listChurches() async => churches;

  @override
  Future<AccountPreview> previewAccount(String? churchId, String email) async {
    calls.add('preview:$email');
    return previews[email] ??
        const AccountPreview(
          found: false,
          emailConfirmed: false,
          membership: AccountMembership.none,
          isCoordinator: false,
        );
  }

  @override
  Future<({String churchId, String joinCode})> createChurch({
    required String name,
    required String coordinatorEmail,
  }) async {
    _call('create:$name:$coordinatorEmail');
    return (churchId: 'church-new', joinCode: 'ABCDE23456');
  }

  @override
  Future<void> assignCoordinator(String churchId, String email) async =>
      _call('assign:$email');

  @override
  Future<void> replaceCoordinator(
    String churchId, {
    required String currentMembershipId,
    required String email,
  }) async => _call('replace:$currentMembershipId:$email');

  @override
  Future<void> endCoordinator(String churchId, String membershipId) async =>
      _call('end:$membershipId');

  @override
  Future<String> regenerateJoinCode(String churchId) async {
    _call('regenerate');
    return 'NEWC0DE234';
  }

  @override
  Future<void> setStatus(String churchId, ChurchStatus status) async =>
      _call('status:${status.toDb}');

  @override
  Future<List<PlatformEvent>> listEvents({String? churchId}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

const foundAccount = AccountPreview(
  found: true,
  emailConfirmed: true,
  fullName: 'Ana Reyes',
  membership: AccountMembership.none,
  isCoordinator: false,
);
