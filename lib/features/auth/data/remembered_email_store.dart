import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The email of the person who last signed in on this device, so the
/// device's owner does not type it every time (user decision 2026-10-06).
///
/// Only the address is kept, never the password: the password manager is
/// offered the credentials through the sign-in form's autofill group. The
/// session itself already survives restarts (supabase_flutter storage).
/// Sign-out keeps the email: this is the device owner's phone. Another
/// person simply types over it.
class RememberedEmailStore {
  RememberedEmailStore({this.enabled = true});

  final bool enabled;

  // Deliberately outside the offline-snapshot and curriculum prefixes,
  // which sign-out clears.
  static const _key = 'auth.last_email';

  Future<String?> read() async {
    if (!enabled) return null;
    final value = (await SharedPreferences.getInstance()).getString(_key);
    return value == null || value.trim().isEmpty ? null : value;
  }

  Future<void> write(String email) async {
    if (!enabled) return;
    await (await SharedPreferences.getInstance()).setString(_key, email.trim());
  }
}

final rememberedEmailStoreProvider = Provider<RememberedEmailStore>(
  (ref) => RememberedEmailStore(),
);
