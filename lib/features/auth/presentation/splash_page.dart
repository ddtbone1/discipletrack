import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/connectivity/connection_status.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/error_state.dart';
import '../../membership/application/membership_providers.dart';
import '../../profile/application/profile_providers.dart';
import '../application/auth_providers.dart';
import '../application/intro_state.dart';

/// The launch screen: the lime logo and the "DiscipleTrack" wordmark on the
/// page colour. The logo springs in with a slight overshoot and turn while a
/// soft lime ring ripples out from behind it once; then the wordmark writes
/// itself in, letter by letter, each letter fading up into place. When it
/// finishes, [introCompleteProvider] lets the router move on.
///
/// The router also sends [SessionState.unknown] here and never to sign-in,
/// which is what stops a signed-in person seeing the login screen for a
/// frame on launch. If the profile or membership cannot be loaded, the logo
/// gives way to a retry, so nobody is stuck on a spinner.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  /// The whole intro, including a short hold on the finished frame.
  static const duration = Duration(milliseconds: 1900);

  static const wordmark = 'DiscipleTrack';

  /// Pause between the first frame and the start of the animation.
  static const startDelay = Duration(milliseconds: 300);

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: SplashPage.duration,
  );

  // The logo springs in first, the ring ripples behind it, then the
  // letters arrive one after another.
  late final Animation<double> _logo = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.38, curve: Curves.easeOutBack),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.2, curve: Curves.easeOut),
  );
  late final Animation<double> _ring = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.12, 0.62, curve: Curves.easeOutCubic),
  );

  /// Letter [i] of the wordmark, 0 to 1. The letters share the window
  /// 0.34 to 0.86, each starting a little after the one before.
  double _letter(int i) {
    const start = 0.34;
    const spread = 0.36;
    const each = 0.16;
    final n = SplashPage.wordmark.length;
    final from = start + spread * i / (n - 1);
    final t = ((_intro.value - from) / each).clamp(0.0, 1.0);
    return Curves.easeOutCubic.transform(t);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_intro.isAnimating || _intro.isCompleted) return;

    // Played once per launch, and not at all when the person has asked the
    // system to reduce motion (UI_DESIGN_SYSTEM section 53).
    final played = ref.read(introCompleteProvider);
    if (played || MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      // Not during build: the router listens to this provider.
      Future.microtask(ref.read(introCompleteProvider.notifier).complete);
      return;
    }
    // Starts a moment after the first frame is on screen. Android 12+ keeps
    // its own system splash up until then, and a slow first frame would
    // otherwise use up the animation behind it.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(SplashPage.startDelay);
      if (!mounted) return;
      await _intro.forward();
      if (mounted) ref.read(introCompleteProvider.notifier).complete();
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final profile = ref.watch(myProfileProvider);
    final membership = ref.watch(myMembershipProvider);
    final failed = profile.hasError || membership.hasError;
    final introDone = ref.watch(introCompleteProvider);

    if (failed && introDone) {
      // Unreachable server and nothing saved on this phone yet (a first
      // launch offline, or a new device): the Slice 4 plan's one offline
      // message. Shown on the page background so it reads like any error.
      final offline = isNetworkFailure(
        profile.error ?? membership.error ?? Object(),
      );
      return Scaffold(
        backgroundColor: p.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ErrorState(
                title: offline
                    ? "You're offline"
                    : 'Could not load your account',
                message: offline
                    ? 'Connect to sign in. Once you have signed in with a '
                          'connection, this phone keeps a copy to view '
                          'offline.'
                    : 'DiscipleTrack could not load your account. Try '
                          'again in a moment.',
                onRetry: () {
                  ref.invalidate(myProfileProvider);
                  ref.invalidate(myMembershipProvider);
                },
              ),
              AppButton(
                label: 'Sign out',
                variant: AppButtonVariant.text,
                expand: false,
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).signOut(),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _intro,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 200,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // One soft lime ring, rippling out and fading.
                    Opacity(
                      opacity: (1 - _ring.value) * 0.45 * _logoFade.value,
                      child: Container(
                        width: 90 + 110 * _ring.value,
                        height: 90 + 110 * _ring.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: p.brand, width: 2),
                        ),
                      ),
                    ),
                    Opacity(
                      opacity: _logoFade.value,
                      child: Transform.rotate(
                        angle: (1 - _logo.value) * -0.14,
                        child: Transform.scale(
                          scale: 0.5 + 0.5 * _logo.value,
                          child: Semantics(
                            label: SplashPage.wordmark,
                            child: const SizedBox(
                              width: 120,
                              height: 120,
                              child: BrandLogo(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // The wordmark, written in one letter at a time.
              ExcludeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < SplashPage.wordmark.length; i++)
                      Opacity(
                        opacity: _letter(i),
                        child: Transform.translate(
                          offset: Offset(0, (1 - _letter(i)) * 14),
                          child: Text(
                            SplashPage.wordmark[i],
                            style: AppTypography.display.copyWith(
                              color: p.textPrimary,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // Only once the intro is over and data is still on its way.
              SizedBox(
                height: 22,
                width: 22,
                child: introDone
                    ? CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.textPrimary.withValues(alpha: 0.7),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
