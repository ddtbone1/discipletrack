/// Email verification against the real local GoTrue with
/// `enable_confirmations = true` and Mailpit capturing the mail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/test_env.dart';

void main() {
  setUpAll(ensureTestEnvironment);

  Future<void> cleanUpByEmail(String email) async {
    final users = await service.auth.admin.listUsers();
    for (final u in users.where((u) => u.email == email)) {
      await deleteUser(u.id);
    }
  }

  test('sign-up issues no session and creates the profile; the code from the '
      'email verifies and then signs in', () async {
    final client = anonClient();
    final email = uniqueEmail('verify');
    addTearDown(() => cleanUpByEmail(email));

    final res = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': 'Verify Me'},
    );
    expect(res.session, isNull, reason: 'confirmation is required first');
    expect(res.user, isNotNull);
    expect(res.user!.identities, isNotEmpty);

    // The trigger still ran inside the sign-up transaction.
    final profile = await service
        .from('profiles')
        .select('full_name')
        .eq('id', res.user!.id)
        .single();
    expect(profile['full_name'], 'Verify Me');

    // No session yet, and the protected tables give nothing to anon.
    expect(await client.from('profiles').select('id'), isEmpty);

    // Sign-in before verification is refused with a code the app can act on.
    await expectLater(
      anonClient().auth.signInWithPassword(email: email, password: password),
      throwsAuthCode('email_not_confirmed'),
    );

    final code = await fetchVerificationCode(email);
    final verified = await client.auth.verifyOTP(
      email: email,
      token: code,
      type: OtpType.signup,
    );
    expect(verified.session, isNotNull);

    // Sign-in works from now on.
    final again = await anonClient().auth.signInWithPassword(
      email: email,
      password: password,
    );
    expect(again.session, isNotNull);
  });

  test('a wrong code is refused with otp_expired', () async {
    final client = anonClient();
    final email = uniqueEmail('wrongcode');
    addTearDown(() => cleanUpByEmail(email));

    await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': 'Wrong Code'},
    );
    final real = await fetchVerificationCode(email);
    final wrong = real == '000000' ? '111111' : '000000';

    await expectLater(
      client.auth.verifyOTP(email: email, token: wrong, type: OtpType.signup),
      throwsAuthCode('otp_expired'),
    );
  });

  test('resend delivers a second code that also verifies', () async {
    final client = anonClient();
    final email = uniqueEmail('resend');
    addTearDown(() => cleanUpByEmail(email));

    await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': 'Resend Me'},
    );
    await fetchVerificationCode(email);

    // Local max_frequency is 1s; hosted projects use a longer window.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    await client.auth.resend(type: OtpType.signup, email: email);

    final deadline = DateTime.now().add(const Duration(seconds: 15));
    while (await countEmails(email) < 2 && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    expect(await countEmails(email), 2);

    final latest = await fetchVerificationCode(email);
    final verified = await client.auth.verifyOTP(
      email: email,
      token: latest,
      type: OtpType.signup,
    );
    expect(verified.session, isNotNull);
  });

  test('registering an already-confirmed email is refused, and an unconfirmed '
      'one is re-sent its code', () async {
    final confirmed = await createUser(fullName: 'Confirmed', tag: 'dupc');
    addTearDown(() => deleteUser(confirmed.userId));

    await expectLater(
      anonClient().auth.signUp(
        email: confirmed.email,
        password: 'another-password',
        data: {'full_name': 'Second'},
      ),
      throwsAuthCode('user_already_exists'),
    );

    final unconfirmedEmail = uniqueEmail('dupu');
    addTearDown(() => cleanUpByEmail(unconfirmedEmail));
    await anonClient().auth.signUp(
      email: unconfirmedEmail,
      password: password,
      data: {'full_name': 'Unconfirmed'},
    );
    await fetchVerificationCode(unconfirmedEmail);
    await Future<void>.delayed(const Duration(milliseconds: 1500));

    final repeat = await anonClient().auth.signUp(
      email: unconfirmedEmail,
      password: password,
      data: {'full_name': 'Unconfirmed'},
    );
    expect(repeat.session, isNull);
    expect(
      repeat.user?.identities,
      isNotEmpty,
      reason: 'GoTrue returns the existing unconfirmed user and resends',
    );

    final users = await service.auth.admin.listUsers();
    expect(users.where((u) => u.email == unconfirmedEmail), hasLength(1));
  });
}
