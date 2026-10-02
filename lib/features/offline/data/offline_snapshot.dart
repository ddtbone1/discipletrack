import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../membership/domain/church_membership.dart';
import '../../ministry/domain/ministry_context.dart';
import '../../profile/domain/profile.dart';

/// What the person last saw, saved on the device for offline viewing
/// (Slice 4 plan, "What is saved on the device").
///
/// It holds only data the person was already allowed to read: their own
/// profile, membership, church name and roles, and their group roster with
/// the phone numbers `get_my_d_group_roster()` chose to return.
///
/// Display only. Nothing here ever authorizes anything; every action still
/// goes to the database, and while offline every action is disabled.
///
/// Stored in the same row shapes the repositories read, so the existing
/// `fromMap` parsers decode it and there is one definition of each row.
@immutable
class OfflineSnapshot {
  const OfflineSnapshot({
    required this.userId,
    required this.savedAt,
    required this.profile,
    required this.membership,
    required this.church,
    required this.roles,
    required this.ministry,
  });

  /// Bump when the stored shape changes; an older snapshot is then ignored
  /// rather than misread.
  static const version = 1;

  final String userId;
  final DateTime savedAt;
  final Profile? profile;
  final ChurchMembership? membership;
  final ChurchSummary? church;
  final Set<ChurchRole> roles;
  final MinistryContext? ministry;

  static String? _at(DateTime? t) => t?.toUtc().toIso8601String();

  Map<String, dynamic> toJson() => {
    'version': version,
    'user_id': userId,
    'saved_at': _at(savedAt),
    'profile': profile == null
        ? null
        : {
            'id': profile!.id,
            'full_name': profile!.fullName,
            'phone': profile!.phone,
            'avatar_url': profile!.avatarUrl,
            'created_at': _at(profile!.createdAt),
            'updated_at': _at(profile!.updatedAt),
          },
    'membership': membership == null
        ? null
        : {
            'id': membership!.id,
            'church_id': membership!.churchId,
            'user_id': membership!.userId,
            'status': membership!.status.name.toUpperCase(),
            'joined_at': _at(membership!.joinedAt),
            'created_at': _at(membership!.requestedAt),
            'approved_at': _at(membership!.approvedAt),
            'onboarding_completed_at': _at(membership!.onboardingCompletedAt),
          },
    'church': church == null ? null : {'id': church!.id, 'name': church!.name},
    'roles': [for (final r in roles) r.name.toUpperCase()],
    'roster': ministry == null
        ? const <Map<String, dynamic>>[]
        : [
            for (final e in ministry!.roster)
              {
                'd_group_id': ministry!.dGroupId,
                'd_group_name': ministry!.dGroupName,
                'd_group_membership_id': e.dGroupMembershipId,
                'church_membership_id': e.churchMembershipId,
                'full_name': e.fullName,
                'responsibility': e.responsibility.name.toUpperCase(),
                'phone': e.phone,
                'is_me': e.isMe,
                'is_my_leader': e.isMyLeader,
                'is_my_discipler': e.isMyDiscipler,
                'is_my_disciple': e.isMyDisciple,
              },
          ],
  };

  /// Null for a snapshot of another version, or one that cannot be read.
  static OfflineSnapshot? fromJson(Map<String, dynamic> json) {
    try {
      if (json['version'] != version) return null;
      Map<String, dynamic>? obj(String key) =>
          (json[key] as Map?)?.cast<String, dynamic>();
      final profile = obj('profile');
      final membership = obj('membership');
      final church = obj('church');
      return OfflineSnapshot(
        userId: json['user_id'] as String,
        savedAt: DateTime.parse(json['saved_at'] as String),
        profile: profile == null ? null : Profile.fromMap(profile),
        membership: membership == null
            ? null
            : ChurchMembership.fromMap(membership),
        church: church == null ? null : ChurchSummary.fromMap(church),
        roles: {
          for (final r in json['roles'] as List<dynamic>)
            ChurchRole.fromDb(r as String),
        },
        ministry: MinistryContext.fromRosterRows([
          for (final r in json['roster'] as List<dynamic>)
            (r as Map).cast<String, dynamic>(),
        ]),
      );
    } on Object {
      return null;
    }
  }
}

/// One snapshot per signed-in user, in `shared_preferences`.
///
/// Disabled on the web, which is a development tool only and needs no
/// offline support (Slice 4 plan, "Platforms"); not writing there also keeps
/// phone numbers out of browser storage.
class OfflineSnapshotStore {
  OfflineSnapshotStore({bool? enabled}) : enabled = enabled ?? !kIsWeb;

  final bool enabled;

  static const _prefix = 'offline_snapshot.';

  Future<OfflineSnapshot?> read(String userId) async {
    if (!enabled) return null;
    final raw = (await SharedPreferences.getInstance()).getString(
      '$_prefix$userId',
    );
    if (raw == null) return null;
    try {
      final snapshot = OfflineSnapshot.fromJson(
        (jsonDecode(raw) as Map).cast<String, dynamic>(),
      );
      return snapshot?.userId == userId ? snapshot : null;
    } on FormatException {
      return null;
    }
  }

  Future<void> write(OfflineSnapshot snapshot) async {
    if (!enabled) return;
    await (await SharedPreferences.getInstance()).setString(
      '$_prefix${snapshot.userId}',
      jsonEncode(snapshot.toJson()),
    );
  }

  /// Every saved snapshot, whoever it belongs to. Called on sign-out.
  Future<void> clearAll() async {
    if (!enabled) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((k) => k.startsWith(_prefix))) {
      await prefs.remove(key);
    }
  }
}

final offlineSnapshotStoreProvider = Provider<OfflineSnapshotStore>(
  (ref) => OfflineSnapshotStore(),
);
