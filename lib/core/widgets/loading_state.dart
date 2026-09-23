import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Full-page loading indicator.
///
/// UI_DESIGN_SYSTEM section 43. Used for genuine page-level waits such as
/// session restoration. In-place waits use [AppButton]'s inline spinner
/// instead, so the surrounding content is never torn down and rebuilt.
class LoadingState extends StatelessWidget {
  const LoadingState({this.message, super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: context.palette.textPrimary,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(message!, style: context.supportingStyle),
          ],
        ],
      ),
    );
  }
}
