import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Implemented by repository failures that know whether the server was
/// unreachable, as opposed to reached and refusing.
///
/// Only an unreachable server makes the app fall back to the saved snapshot.
/// A refusal (RLS, a PTxxx code) is a real answer and is never masked by
/// stale data.
abstract interface class NetworkAwareFailure {
  bool get isNetwork;
}

bool isNetworkFailure(Object error) =>
    error is NetworkAwareFailure && error.isNetwork;

/// Whether DiscipleTrack currently believes it is offline.
///
/// There is no connectivity package: a request that cannot reach the server
/// marks the app offline, and the next request that succeeds marks it online
/// again (Slice 4 plan, "Detecting the connection").
class ConnectionStatus extends Notifier<bool> {
  @override
  bool build() => false;

  void markOffline() {
    if (!state) state = true;
  }

  void markOnline() {
    if (state) state = false;
  }
}

/// True while offline.
final isOfflineProvider = NotifierProvider<ConnectionStatus, bool>(
  ConnectionStatus.new,
);

/// Makes the offline state readable by core widgets without Riverpod, so
/// [AppButton] and [AppScaffold] stay plain widgets and still work in a bare
/// test harness, where the scope is absent and the app counts as online.
class ConnectionScope extends InheritedWidget {
  const ConnectionScope({
    required this.offline,
    required this.onRetry,
    required super.child,
    super.key,
  });

  final bool offline;

  /// Tries the server again now.
  final VoidCallback onRetry;

  static ConnectionScope? _of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ConnectionScope>();

  static bool isOffline(BuildContext context) => _of(context)?.offline ?? false;

  static VoidCallback? retryOf(BuildContext context) => _of(context)?.onRetry;

  @override
  bool updateShouldNotify(ConnectionScope oldWidget) =>
      offline != oldWidget.offline;
}
