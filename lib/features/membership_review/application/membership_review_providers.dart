import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../membership/application/membership_providers.dart';
import '../../membership/data/membership_repository.dart';
import '../data/membership_review_repository.dart';
import '../domain/membership_request.dart';

/// PENDING requests for the approver's own church. Empty without an ACTIVE
/// membership; RLS returns nothing for a non-approver regardless.
final pendingMembershipRequestsProvider =
    FutureProvider<List<MembershipRequest>>((ref) async {
      final membership = ref.watch(myMembershipProvider).value;
      if (membership == null || !membership.status.grantsChurchAccess) {
        return const [];
      }
      return ref
          .watch(membershipReviewRepositoryProvider)
          .fetchPendingRequests(membership.churchId);
    });

/// Which request is being acted on, and the last failure, if any.
@immutable
class MembershipReviewState {
  const MembershipReviewState({this.inFlightId, this.error});

  /// Lets the list disable exactly the row being acted on.
  final String? inFlightId;
  final MembershipFailure? error;

  bool get isBusy => inFlightId != null;
}

/// Approves or declines one request, then refreshes the list.
class MembershipReviewController extends Notifier<MembershipReviewState> {
  @override
  MembershipReviewState build() => const MembershipReviewState();

  Future<bool> approve(String membershipId) => _run(
    membershipId,
    () => ref.read(membershipReviewRepositoryProvider).approve(membershipId),
  );

  Future<bool> reject(String membershipId) => _run(
    membershipId,
    () => ref.read(membershipReviewRepositoryProvider).reject(membershipId),
  );

  void clearError() =>
      state = MembershipReviewState(inFlightId: state.inFlightId);

  Future<bool> _run(String membershipId, Future<void> Function() action) async {
    if (state.isBusy) return false;
    state = MembershipReviewState(inFlightId: membershipId);
    try {
      await action();
      ref.invalidate(pendingMembershipRequestsProvider);
      state = const MembershipReviewState();
      return true;
    } on MembershipFailure catch (e) {
      // A conflict means someone else already handled it; the list is stale.
      if (e.code == MembershipFailureCode.conflict) {
        ref.invalidate(pendingMembershipRequestsProvider);
      }
      state = MembershipReviewState(error: e);
      return false;
    }
  }
}

final membershipReviewControllerProvider =
    NotifierProvider<MembershipReviewController, MembershipReviewState>(
      MembershipReviewController.new,
    );
