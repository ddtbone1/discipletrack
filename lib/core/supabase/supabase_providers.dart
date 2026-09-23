import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase client, initialised in `main()` before `runApp`.
///
/// Exposed as a provider so repositories depend on an injectable value rather
/// than reaching for the global singleton, which keeps them testable.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Auth state as a stream.
///
/// `Supabase.initialize()` has already restored any persisted session by the
/// time this is first read, so the initial value reflects reality rather than
/// a momentary signed-out state. That is what prevents a sign-in screen flash
/// on launch.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

/// The current session, or null. Synchronous and safe to read at any time.
final currentSessionProvider = Provider<Session?>((ref) {
  // Depend on the stream so this recomputes on sign-in and sign-out, but read
  // the client directly so there is never an intermediate loading state.
  ref.watch(authStateChangesProvider);
  return ref.watch(supabaseClientProvider).auth.currentSession;
});

/// The signed-in user's id, or null.
final currentUserIdProvider = Provider<String?>((ref) {
  return ref.watch(currentSessionProvider)?.user.id;
});
