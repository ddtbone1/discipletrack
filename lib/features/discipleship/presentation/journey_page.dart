import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../ministry/application/ministry_providers.dart';
import '../domain/journey_views.dart';
import 'my_disciples_page.dart';
import 'progress_page.dart';

/// Journey: one destination whose views come from the person's
/// relationships (plan decision 20, N8). My Journey when they are a
/// Disciple, My Disciples when they are a Discipler, and two tabs only when
/// both exist and neither would be empty. No mode switch.
class JourneyPage extends ConsumerStatefulWidget {
  const JourneyPage({this.initialView, super.key});

  /// `disciples` selects the My Disciples tab, only in the two-tab state.
  final String? initialView;

  @override
  ConsumerState<JourneyPage> createState() => _JourneyPageState();
}

class _JourneyPageState extends ConsumerState<JourneyPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(
    length: 2,
    vsync: this,
    // D11 proposed default: My Journey first.
    initialIndex: widget.initialView == 'disciples' ? 1 : 0,
  )..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ministry = ref.watch(myMinistryContextProvider);

    final Widget body;
    if (ministry.hasError && !ministry.hasValue) {
      body = SizedBox(
        height: 320,
        child: ErrorState.load(
          subject: 'your journey',
          error: ministry.error!,
          onRetry: () => ref.invalidate(myMinistryContextProvider),
        ),
      );
    } else if (!ministry.hasValue) {
      body = const SizedBox(height: 320, child: LoadingState());
    } else {
      final views = JourneyViews.of(ministry.value);
      if (views.showsTabs) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: _tabs,
              // The active line spans the whole tab; no rule under the bar.
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'My Journey'),
                Tab(text: 'My Disciples'),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_tabs.index == 0)
              const MyJourneyBody()
            else
              const MyDisciplesBody(),
          ],
        );
      } else if (views.showsMyJourneyOnly) {
        body = MyJourneyBody(showAppointedNote: views.showsAppointedNote);
      } else if (views.showsMyDisciplesOnly) {
        body = const MyDisciplesBody();
      } else {
        body = const EmptyState.restricted(
          title: 'Journey is for Disciples and Disciplers',
          message:
              'Your journey appears here once you are placed in a D Group as '
              'a Disciple or a Discipler.',
        );
      }
    }

    return AppScaffold(
      title: 'Journey',
      showBackButton: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xs),
          body,
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
