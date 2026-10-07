/// The password rules, the same as the auth server's
/// (`minimum_password_length = 8`,
/// `password_requirements = "lower_upper_letters_digits_symbols"` in
/// supabase/config.toml). The server decides; this list shows the rules as
/// the person types, so a refusal never comes as a surprise.
class PasswordRule {
  const PasswordRule(this.label, this.passes);

  final String label;
  final bool Function(String password) passes;
}

const minPasswordLength = 8;

final passwordRules = <PasswordRule>[
  PasswordRule(
    'At least $minPasswordLength characters',
    (p) => p.length >= minPasswordLength,
  ),
  PasswordRule('An uppercase letter', (p) => RegExp('[A-Z]').hasMatch(p)),
  PasswordRule('A lowercase letter', (p) => RegExp('[a-z]').hasMatch(p)),
  PasswordRule('A number', (p) => RegExp('[0-9]').hasMatch(p)),
  PasswordRule(
    'A symbol, such as ! @ # -',
    (p) => RegExp(r'[^A-Za-z0-9\s]').hasMatch(p),
  ),
];

/// Whether [password] meets every rule.
bool isStrongPassword(String password) =>
    passwordRules.every((r) => r.passes(password));

/// Why [password] cannot be used, or null. [email] keeps the person's own
/// address out of it; [current] keeps it from being the same as before.
String? passwordProblem(String password, {String? email, String? current}) {
  for (final r in passwordRules) {
    if (!r.passes(password)) {
      return 'Your password needs: ${r.label.toLowerCase()}.';
    }
  }
  final name = email?.split('@').first.toLowerCase();
  if (name != null &&
      name.length >= 3 &&
      password.toLowerCase().contains(name)) {
    return 'Do not use your email address in your password.';
  }
  if (current != null && current.isNotEmpty && password == current) {
    return 'Choose a password different from your current one.';
  }
  return null;
}
