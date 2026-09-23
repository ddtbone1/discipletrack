import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../membership/application/membership_providers.dart';
import '../../membership/data/membership_repository.dart';
import '../../membership/domain/church_membership.dart';
import '../domain/join_code.dart';

enum JoinPhase {
  /// Waiting for a code.
  idle,

  /// `lookup_church_by_join_code()` in flight.
  lookingUp,

  /// The church was found and is shown for confirmation.
  found,

  /// `request_join_church()` in flight.
  submitting,
}

@immutable
class JoinChurchState {
  const JoinChurchState({
    this.phase = JoinPhase.idle,
    this.church,
    this.code,
    this.error,
  });

  final JoinPhase phase;

  /// Set while [phase] is [JoinPhase.found] or [JoinPhase.submitting].
  final ChurchSummary? church;

  /// The normalised code that resolved [church]. Sent again on confirm.
  final String? code;

  /// A message fit to show. Cleared on the next action.
  final String? error;

  bool get isBusy =>
      phase == JoinPhase.lookingUp || phase == JoinPhase.submitting;

  JoinChurchState copyWith({
    JoinPhase? phase,
    ChurchSummary? church,
    String? code,
    String? error,
    bool clearChurch = false,
    bool clearError = true,
  }) {
    return JoinChurchState(
      phase: phase ?? this.phase,
      church: clearChurch ? null : (church ?? this.church),
      code: clearChurch ? null : (code ?? this.code),
      error: clearError ? error : (error ?? this.error),
    );
  }
}

/// The join flow: code → Find Church → confirm → request.
///
/// MVP_SPEC section 11. Both server calls are the controlled operations from
/// Migration 005; nothing here touches a table directly. A malformed code is
/// refused locally so it does not spend one of the rate-limited attempts.
class JoinChurchController extends Notifier<JoinChurchState> {
  @override
  JoinChurchState build() => const JoinChurchState();

  static const malformedMessage =
      'Enter the 10-character code from your church. It uses letters and '
      'numbers only.';
  static const notFoundMessage =
      "We couldn't find a church with that code. Check it and try again.";
  static const notRequestableMessage =
      'Your membership with this church needs to be reactivated by your '
      'church. Please contact them.';

  Future<void> lookup(String rawCode) async {
    final code = normalizeJoinCode(rawCode);
    if (!isWellFormedJoinCode(code)) {
      state = state.copyWith(
        phase: JoinPhase.idle,
        error: malformedMessage,
        clearChurch: true,
      );
      return;
    }

    state = state.copyWith(phase: JoinPhase.lookingUp, clearChurch: true);
    try {
      final church = await ref
          .read(membershipRepositoryProvider)
          .lookupChurchByJoinCode(code);
      if (church == null) {
        state = state.copyWith(phase: JoinPhase.idle, error: notFoundMessage);
        return;
      }
      state = state.copyWith(
        phase: JoinPhase.found,
        church: church,
        code: code,
      );
    } on MembershipFailure catch (e) {
      state = state.copyWith(phase: JoinPhase.idle, error: e.message);
    }
  }

  /// Returns true when a membership now exists (new or pre-existing); the
  /// router moves on once the membership refresh lands.
  Future<bool> confirm() async {
    final church = state.church;
    final code = state.code;
    if (church == null || code == null || state.isBusy) return false;

    state = state.copyWith(phase: JoinPhase.submitting);
    try {
      final outcome = await ref
          .read(membershipRepositoryProvider)
          .requestJoinChurch(churchId: church.id, joinCode: code);

      switch (outcome) {
        case JoinRequestOutcome.requested:
        case JoinRequestOutcome.alreadyPending:
        case JoinRequestOutcome.alreadyActive:
          await ref.read(myMembershipProvider.notifier).refresh();
          state = const JoinChurchState();
          return true;
        case JoinRequestOutcome.notRequestable:
          // A row exists, so the router will show the no-access screen once
          // the membership is re-read.
          await ref.read(myMembershipProvider.notifier).refresh();
          state = state.copyWith(
            phase: JoinPhase.found,
            error: notRequestableMessage,
          );
          return false;
        case JoinRequestOutcome.invalidCode:
          state = state.copyWith(
            phase: JoinPhase.idle,
            error: notFoundMessage,
            clearChurch: true,
          );
          return false;
      }
    } on MembershipFailure catch (e) {
      state = state.copyWith(phase: JoinPhase.found, error: e.message);
      return false;
    }
  }

  /// Back to the code field, for "Not my church".
  void reset() => state = const JoinChurchState();
}

final joinChurchControllerProvider =
    NotifierProvider<JoinChurchController, JoinChurchState>(
      JoinChurchController.new,
    );
