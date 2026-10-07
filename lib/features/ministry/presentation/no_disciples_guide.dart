import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/ministry_providers.dart';

/// A Discipler with nobody paired yet (Home and My D Group). Only a Leader
/// or the Coordinator pairs, so a Discipler gets no action here, only who
/// pairs them and what comes next (user, 2026-10-07). A Leader, who pairs
/// Disciples themselves, gets the way to do it.
class NoDisciplesGuide extends ConsumerWidget {
  const NoDisciplesGuide({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(myMinistryContextProvider).value;
    final leaderFirst = c?.leader?.fullName.split(' ').first;
    final isLeader = c?.isLeader ?? false;

    final message = isLeader
        ? 'As the Leader, you pair Disciples yourself, from Manage members.'
        : leaderFirst != null
        ? '$leaderFirst, your Leader, pairs Disciples with you. Once paired, '
              'they show here and you record your meetings with them.'
        : "Your church's Coordinator pairs Disciples with you. Once paired, "
              'they show here and you record your meetings with them.';

    return AppCard(
      child: EmptyState(
        illustration: Illustration.join,
        title: 'No Disciples yet',
        message: message,
        action: isLeader && c != null
            ? AppButton(
                label: 'Pair a Disciple',
                icon: Icons.link_rounded,
                dense: true,
                expand: false,
                onPressed: () =>
                    context.push(Routes.dGroupDetailFor(c.dGroupId)),
              )
            : null,
      ),
    );
  }
}
