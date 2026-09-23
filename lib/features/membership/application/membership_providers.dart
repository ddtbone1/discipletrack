import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../data/membership_repository.dart';
import '../domain/church_membership.dart';

/// The signed-in user's church membership, or null when they have not joined.
///
/// Null is expected for every user in this milestone: joining a church needs
/// `request_join_church()`, which arrives in a later slice.
final myMembershipProvider = FutureProvider<ChurchMembership?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;
  return ref.watch(membershipRepositoryProvider).fetchMyMembership(userId);
});
