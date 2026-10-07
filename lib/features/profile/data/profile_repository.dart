import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../domain/profile.dart';

class ProfileFailure implements Exception, NetworkAwareFailure {
  const ProfileFailure(this.message, {this.isNetwork = false});
  final String message;

  /// The server could not be reached. An exception (not an [Error]) other
  /// than a PostgREST response is a transport failure.
  @override
  final bool isNetwork;

  @override
  String toString() => message;
}

/// The only place the app reads or writes `public.profiles`.
///
/// There is deliberately no `create`. Profiles are created by the
/// `handle_new_user` trigger; Migration 003 grants clients no INSERT.
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, full_name, phone, avatar_url, created_at, updated_at';

  /// The signed-in user's own profile, or null if RLS returns nothing.
  ///
  /// `profiles_select_own` restricts this to the caller's row, so no filter on
  /// the user id is required for correctness. It is passed anyway so the intent
  /// is readable and the query stays indexed on the primary key.
  Future<Profile?> fetchMyProfile(String userId) async {
    try {
      final row = await _client
          .from('profiles')
          .select(_columns)
          .eq('id', userId)
          .maybeSingle();
      return row == null ? null : Profile.fromMap(row);
    } on PostgrestException catch (e) {
      throw ProfileFailure(_friendly(e));
    } on Exception {
      throw const ProfileFailure(
        'Could not load your profile.',
        isNetwork: true,
      );
    } catch (_) {
      throw const ProfileFailure('Could not load your profile.');
    }
  }

  /// Updates only the columns Migration 003 grants.
  ///
  /// A blank name is rejected by `profiles_full_name_not_blank_check` in
  /// Migration 001 even if it reaches here.
  Future<Profile> updateMyProfile({
    required String userId,
    required String fullName,
    String? phone,
  }) async {
    try {
      final row = await _client
          .from('profiles')
          .update({
            'full_name': fullName.trim(),
            'phone': (phone == null || phone.trim().isEmpty)
                ? null
                : phone.trim(),
          })
          .eq('id', userId)
          .select(_columns)
          .single();
      return Profile.fromMap(row);
    } on PostgrestException catch (e) {
      throw ProfileFailure(_friendly(e));
    } on Exception {
      throw const ProfileFailure(
        'Could not save your changes.',
        isNetwork: true,
      );
    } catch (_) {
      throw const ProfileFailure('Could not save your changes.');
    }
  }

  /// Sets the person's avatar to a bundled preset, or back to initials
  /// with null (Migration 021 accepts preset keys only).
  Future<Profile> updateAvatar({
    required String userId,
    required String? avatar,
  }) async {
    try {
      final row = await _client
          .from('profiles')
          .update({'avatar_url': avatar})
          .eq('id', userId)
          .select(_columns)
          .single();
      return Profile.fromMap(row);
    } on PostgrestException catch (e) {
      throw ProfileFailure(_friendly(e));
    } on Exception {
      throw const ProfileFailure(
        'Could not save your avatar.',
        isNetwork: true,
      );
    }
  }

  /// The avatars of the person's church, by church membership id.
  Future<Map<String, String>> fetchChurchAvatars() async {
    try {
      final rows = await _client.rpc<List<dynamic>>('get_church_avatars');
      return {
        for (final r in rows.cast<Map<String, dynamic>>())
          r['church_membership_id'] as String: r['avatar'] as String,
      };
    } on PostgrestException catch (e) {
      throw ProfileFailure(_friendly(e));
    } on Exception {
      throw const ProfileFailure('Could not load avatars.', isNetwork: true);
    }
  }

  String _friendly(PostgrestException e) {
    final raw = '${e.message} ${e.details ?? ''}'.toLowerCase();
    if (raw.contains('profiles_full_name_not_blank_check')) {
      return 'Your name cannot be empty.';
    }
    if (e.code == '42501' || raw.contains('permission denied')) {
      return 'You are not allowed to change that.';
    }
    return 'Could not save your changes.';
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});
