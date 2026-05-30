import 'package:flutter_test/flutter_test.dart';

String? validateRegistrationEmail({required String email, required String authProvider}) {
  final trimmedEmail = email.trim().toLowerCase();
  
  if (trimmedEmail.isEmpty) {
    return 'Error: Email field cannot be empty';
  }
  
  if (authProvider == 'google') {
    if (trimmedEmail.endsWith('@gmail.com') || trimmedEmail.endsWith('@mail.apu.edu.my')) {
      return null;
    }
    return 'Error: Invalid Google Account target domain';
  }

  if (authProvider == 'password') {
    if (trimmedEmail.endsWith('@mail.apu.edu.my')) {
      return null;
    }
    return 'Error: Standard registration is restricted to @mail.apu.edu.my accounts';
  }

  return 'Error: Unsupported authentication method';
}

void main() {
  group('Account Registration Email Domain Validation Tests', () {
    test('should approve standard password registration when official APU student email is used', () {
      String? result = validateRegistrationEmail(
        email: 'TP012345@mail.apu.edu.my',
        authProvider: 'password',
      );

      expect(result, isNull);
    });

    test('should reject standard password registration when a non-APU personal email is used', () {
      String? result = validateRegistrationEmail(
        email: 'student_test@yahoo.com',
        authProvider: 'password',
      );

      expect(result, 'Error: Standard registration is restricted to @mail.apu.edu.my accounts');
    });

    test('should reject standard password registration when a generic gmail account is used instead of Google Sign-In', () {
      String? result = validateRegistrationEmail(
        email: 'apu_student@gmail.com',
        authProvider: 'password',
      );

      expect(result, 'Error: Standard registration is restricted to @mail.apu.edu.my accounts');
    });

    test('should approve registration when using Google provider with a personal gmail account', () {
      String? result = validateRegistrationEmail(
        email: 'external_user@gmail.com',
        authProvider: 'google',
      );

      expect(result, isNull);
    });

    test('should approve registration when using Google provider with an institutional APU email account', () {
      String? result = validateRegistrationEmail(
        email: 'TP099999@mail.apu.edu.my',
        authProvider: 'google',
      );

      expect(result, isNull);
    });

    test('should return empty field error string when input length is zero', () {
      String? result = validateRegistrationEmail(
        email: '',
        authProvider: 'password',
      );

      expect(result, 'Error: Email field cannot be empty');
    });
  });
}