import 'package:discipletrack/features/auth/domain/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a strong password meets every rule', () {
    expect(isStrongPassword('Walk-with-3'), isTrue);
    expect(passwordProblem('Walk-with-3'), isNull);
  });

  test('each missing rule is named', () {
    expect(passwordProblem('Ab-1'), contains('8 characters'));
    expect(passwordProblem('walk-with-3'), contains('uppercase'));
    expect(passwordProblem('WALK-WITH-3'), contains('lowercase'));
    expect(passwordProblem('Walk-with-me'), contains('number'));
    expect(passwordProblem('Walkwith3x'), contains('symbol'));
  });

  test('not the email name, and not the current password', () {
    expect(
      passwordProblem('Rosa.dom-123', email: 'rosa.dom@church.test'),
      contains('email'),
    );
    expect(
      passwordProblem('Walk-with-3', current: 'Walk-with-3'),
      contains('different'),
    );
  });
}
