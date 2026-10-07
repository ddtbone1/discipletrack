import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/avatar_art.dart';
import '../application/profile_providers.dart';

Future<void> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        // Above the keyboard when a field is focused.
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(sheet).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(child: child),
      ),
    );

Widget _title(BuildContext context, String title, String subtitle) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 4),
    Text(subtitle, style: context.supportingStyle),
    const SizedBox(height: AppSpacing.md),
  ],
);

/// Picks one of the bundled avatars, or back to initials.
Future<void> showAvatarPicker(BuildContext context, {String? current}) =>
    _sheet(context, _AvatarPicker(current: current));

class _AvatarPicker extends ConsumerWidget {
  const _AvatarPicker({this.current});

  final String? current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final busy = ref.watch(avatarControllerProvider).isLoading;

    Future<void> choose(String? key) async {
      final ok = await ref.read(avatarControllerProvider.notifier).choose(key);
      if (ok && context.mounted) Navigator.of(context).pop();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title(
          context,
          'Choose an avatar',
          'It shows in place of your initials across the app.',
        ),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          children: [
            for (var n = 1; n <= presetAvatarCount; n++)
              Semantics(
                button: true,
                selected: current == presetAvatarKey(n),
                label: 'Avatar $n',
                excludeSemantics: true,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: busy ? null : () => choose(presetAvatarKey(n)),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: current == presetAvatarKey(n)
                            ? p.brand
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (_, c) => PresetAvatar(
                        asset: presetAvatarAsset(presetAvatarKey(n))!,
                        size: c.maxWidth,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (current != null) ...[
          const SizedBox(height: AppSpacing.md),
          Center(
            child: TextButton(
              onPressed: busy ? null : () => choose(null),
              child: const Text('Use my initials instead'),
            ),
          ),
        ],
      ],
    );
  }
}
