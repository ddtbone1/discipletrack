import 'package:flutter/material.dart';

import '../domain/discipler_candidate.dart';
import 'ministry_ui.dart';

/// Confirms a Discipler appointment (Coordinator only). Appointment is a
/// structural change the app offers no way to undo, so it is confirmed, and
/// the dialog says what does not change: the person stays a Disciple and
/// continues their own lessons.
Future<bool> confirmAppointment(
  BuildContext context,
  DisciplerCandidate candidate,
) {
  return showConfirmDialog(
    context,
    title: 'Appoint ${candidate.fullName} as a Discipler?',
    message:
        '${candidate.fullName} has been eligible since '
        '${MinistryFormat.shortDate(candidate.eligibleSince)}. They stay a '
        'Disciple and continue their own lessons with their Discipler; once '
        'appointed, Disciples in ${candidate.dGroupName} can be paired with '
        'them. The app cannot undo an appointment.',
    confirmLabel: 'Appoint',
  );
}
