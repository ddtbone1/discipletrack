import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../domain/church_membership.dart';

/// A join code in large, spaced characters with Copy. Used by the Platform
/// area and by the Coordinator's Church information.
class JoinCodeCard extends StatelessWidget {
  const JoinCodeCard({required this.code, this.footnote, super.key});

  final ChurchJoinCode code;
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      fill: AppCardFill.pastel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Join code', style: context.captionStyle),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            code.grouped,
            style: AppTypography.pageTitle.copyWith(
              letterSpacing: 4,
              color: AppCardFill.pastel.foreground(p),
            ),
          ),
          if (footnote != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(footnote!, style: context.captionStyle),
          ],
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AppButton(
              label: 'Copy',
              icon: Icons.copy_rounded,
              variant: AppButtonVariant.secondary,
              expand: false,
              dense: true,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code.code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Join code copied')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
