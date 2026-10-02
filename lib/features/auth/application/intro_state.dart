import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the launch animation on the splash has played.
///
/// Until it has, the router keeps every state on the splash, so the
/// animation is seen once per launch even when the session resolves at once.
/// It plays only once: later visits to the splash (a slow reload) show the
/// finished frame without replaying it.
class IntroState extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() {
    if (!state) state = true;
  }
}

final introCompleteProvider = NotifierProvider<IntroState, bool>(
  IntroState.new,
);
