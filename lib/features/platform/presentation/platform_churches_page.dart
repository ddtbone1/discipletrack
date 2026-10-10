import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/loading_state.dart';
import '../../appearance/presentation/theme_mode_toggle.dart';
import '../application/platform_providers.dart';
import '../domain/platform_models.dart';
import 'platform_ui.dart';

/// The Platform area's first page (UI_DESIGN_SYSTEM section 70): every church
/// with its status, counts and Coordinator. Nothing of any member beyond
/// that, and no ministry data (ADR-022 decision 5).
class PlatformChurchesPage extends ConsumerWidget {
  const PlatformChurchesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final churches = ref.watch(platformChurchesProvider);

    return AppScaffold(
      title: 'Churches',
      // The toggle is a page-header control; in the app bar it keeps the
      // page margin so it is not clipped at the screen edge.
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: AppSpacing.page),
          child: ThemeModeToggle(),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () => ref.refresh(platformChurchesProvider.future),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The churches on DiscipleTrack.',
              style: context.supportingStyle,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'New church',
              icon: Icons.add_rounded,
              requiresConnection: true,
              offlineAction: 'create a church',
              onPressed: () => context.push(Routes.platformNewChurch),
            ),
            const SizedBox(height: AppSpacing.lg),
            churches.when(
              loading: () => const SizedBox(height: 240, child: LoadingState()),
              error: (e, _) => SizedBox(
                height: 320,
                child: ErrorState.load(
                  subject: 'the churches',
                  error: e,
                  onRetry: () => ref.invalidate(platformChurchesProvider),
                ),
              ),
              data: (all) {
                if (all.isEmpty) {
                  return const EmptyState(
                    illustration: Illustration.empty,
                    title: 'No churches yet',
                    message: 'Create the first one and choose its Coordinator.',
                  );
                }
                final open = [
                  for (final c in all)
                    if (!c.isArchived) c,
                ];
                final archived = [
                  for (final c in all)
                    if (c.isArchived) c,
                ];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final c in open) ...[
                      _ChurchCard(church: c),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    if (archived.isNotEmpty)
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: Text(
                            'Archived (${archived.length})',
                            style: AppTypography.sectionTitle,
                          ),
                          children: [
                            for (final c in archived) ...[
                              _ChurchCard(church: c),
                              const SizedBox(height: AppSpacing.sm),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

class _ChurchCard extends StatelessWidget {
  const _ChurchCard({required this.church});

  final PlatformChurch church;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: () => context.push(Routes.platformChurchFor(church.id)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  church.name,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(church.countsLine, style: context.supportingStyle),
                Text(church.coordinatorLine, style: context.captionStyle),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          ChurchStatusPill(status: church.status),
          Icon(Icons.chevron_right_rounded, color: p.muted),
        ],
      ),
    );
  }
}
