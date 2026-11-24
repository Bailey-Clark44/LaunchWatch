import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:launchwatch/src/account.dart';
import 'package:launchwatch/src/notifications.dart';

void main() {
  test('passwords need length and a mix of letters and numbers', () {
    expect(passwordProblem('short1'), 'Use at least 8 characters');
    expect(passwordProblem('allletters'), 'Use both letters and numbers');
    expect(passwordProblem('rockets12'), isNull);
  });

  test('strength rises with length and variety', () {
    expect(passwordStrength('rockets12'), lessThan(passwordStrength('Rockets-and-12-moons')));
    expect(passwordStrength('Rockets-and-12-moons'), 4);
  });

  test('auth errors become sentences that do not leak which emails exist', () {
    expect(authErrorMessage(FirebaseAuthException(code: 'user-not-found')), 'Email or password is incorrect.');
    expect(authErrorMessage(FirebaseAuthException(code: 'wrong-password')), 'Email or password is incorrect.');
    expect(authErrorMessage(FirebaseAuthException(code: 'email-already-in-use')), contains('Try signing in'));
    expect(authErrorMessage(const AccountException('Enter your current password.')), 'Enter your current password.');
  });

  test('alert prefs default on and round-trip', () {
    final prefs = AlertPrefs.fromMap({'slips': false});
    expect(prefs.slips, isFalse);
    expect(prefs.reminder24h, isTrue);
    expect(AlertPrefs.fromMap(prefs.toMap()).slips, isFalse);
  });

  test('device ids are stable and differ per token', () {
    expect(tokenId('abc:123'), tokenId('abc:123'));
    expect(tokenId('abc:123'), isNot(tokenId('abc:124')));
    expect(tokenId('abc:123'), hasLength(16));
  });
}
