import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/postgrest_failure.dart';
import '../data/ministry_repository.dart';
import 'ministry_providers.dart';

@immutable
class InvitationResponseState {
  const InvitationResponseState({this.answering, this.error});

  /// True while accepting, false while declining, null when idle.
  final bool? answering;
  final MinistryFailure? error;

  bool get isBusy => answering != null;
}

/// The invitee's accept or decline. On success, or when the invitation turns
/// out to be stale (expired, withdrawn, or the person was placed meanwhile),
/// the invitation and the person's ministry context are re-read so Home shows
/// where they now stand.
class InvitationResponseController extends Notifier<InvitationResponseState> {
  @override
  InvitationResponseState build() => const InvitationResponseState();

  Future<bool> accept(String invitationId) => _answer(invitationId, true);
  Future<bool> decline(String invitationId) => _answer(invitationId, false);

  Future<bool> _answer(String invitationId, bool accept) async {
    if (state.isBusy) return false;
    state = InvitationResponseState(answering: accept);
    try {
      await ref
          .read(ministryRepositoryProvider)
          .respondToInvitation(invitationId, accept: accept);
      _refresh();
      state = const InvitationResponseState();
      return true;
    } on MinistryFailure catch (e) {
      if (e.code == DbFailureCode.conflict) _refresh();
      state = InvitationResponseState(error: e);
      return false;
    }
  }

  void _refresh() {
    ref
      ..invalidate(myPendingInvitationProvider)
      ..invalidate(myMinistryContextProvider);
  }
}

final invitationResponseControllerProvider =
    NotifierProvider<InvitationResponseController, InvitationResponseState>(
      InvitationResponseController.new,
    );
