import 'package:flutter/foundation.dart';

import '../../ministry/domain/ministry_context.dart';

/// Which Journey views a person has, derived from their relationships
/// (plan decision 20, N8). There is no mode switch: each view exists because
/// the relationship exists.
///
/// - own journey: an active DISCIPLE row
/// - Disciples: active assignments to the person's DISCIPLER row
/// - appointed: an active DISCIPLER row
///
/// Presentation only. Every read behind a view is authorized by the
/// database for the pair (caller, person viewed).
@immutable
class JourneyViews {
  const JourneyViews({
    required this.hasOwnJourney,
    required this.hasDisciples,
    required this.isAppointed,
  });

  factory JourneyViews.of(MinistryContext? ministry) => JourneyViews(
    hasOwnJourney: ministry?.isDisciple ?? false,
    hasDisciples: ministry?.myDisciples.isNotEmpty ?? false,
    isAppointed: ministry?.isDiscipler ?? false,
  );

  final bool hasOwnJourney;
  final bool hasDisciples;
  final bool isAppointed;

  /// Journey is offered in the dock.
  bool get isOffered => hasOwnJourney || isAppointed;

  /// Two tabs, My Journey and My Disciples, only when both are non-empty.
  bool get showsTabs => hasOwnJourney && hasDisciples;

  /// My Journey alone (no tab bar).
  bool get showsMyJourneyOnly => hasOwnJourney && !hasDisciples;

  /// My Disciples alone, including its empty state for an appointed
  /// Discipler with nobody paired yet.
  bool get showsMyDisciplesOnly => !hasOwnJourney && isAppointed;

  /// "You're also a Discipler" under My Journey, instead of an empty tab.
  /// Reachable once a Disciple can also be appointed (Slice 6).
  bool get showsAppointedNote => hasOwnJourney && isAppointed && !hasDisciples;
}
