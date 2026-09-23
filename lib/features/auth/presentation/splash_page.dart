import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/brand_mark.dart';

/// Shown while the session, profile and membership resolve.
///
/// The router sends [SessionState.unknown] here and never to sign-in, which is
/// what stops a signed-in person seeing the login screen for a frame on launch.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 64, showWordmark: false),
            const SizedBox(height: AppSpacing.md),
            Text('DiscipleTrack', style: AppTypography.pageTitle),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: p.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
