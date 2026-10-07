import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_pill.dart';
import '../application/profile_providers.dart';

/// A member's avatar wherever their initials would show: the avatar they
/// picked (Migration 021), else their initials.
class MemberAvatar extends ConsumerWidget {
  const MemberAvatar({
    required this.name,
    required this.membershipId,
    this.radius = 20,
    this.progress,
    this.tone,
    super.key,
  });

  final String name;

  /// The person's church membership id; null shows initials.
  final String? membershipId;
  final double radius;
  final double? progress;
  final PillTone? tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avatars = ref.watch(churchAvatarsProvider).value ?? const {};
    return InitialsAvatar(
      name: name,
      radius: radius,
      progress: progress,
      tone: tone,
      preset: membershipId == null ? null : avatars[membershipId],
    );
  }
}
