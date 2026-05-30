import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/cupertino.dart';
import 'dart:math';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  bool _isGoogleInitialized = false;

  String _generateRandomStudentId() {
    final random = Random();
    int randomNumber = 10000 + random.nextInt(90000);
    return 'TP0$randomNumber';
  }

  // Sign In with Email and Password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      debugPrint("Sign in error: ${e.toString()}");
      return null;
    }
  }

  // Register with Email, Password, and Role
  Future<User?> register(
    String email,
    String password, {
    String role = 'student',
    required String name,
    required String phone,
  }) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        String studentId = _generateRandomStudentId();
        final emailPrefix = email.split('@')[0];

        final tpRegex = RegExp(r'^tp\d+$', caseSensitive: false);
        if (tpRegex.hasMatch(emailPrefix)) {
          studentId = emailPrefix.toUpperCase();
        }

        await _db.collection('users').doc(result.user!.uid).set({
          'uid': result.user!.uid,
          'email': email,
          'username': name,
          'phone': phone,
          'role': role,
          'displayName': name,
          'studentId': studentId,
          'isPrivate': false,
          'bio': 'New APU Student',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return result.user;
    } catch (e) {
      debugPrint("Registration error: ${e.toString()}");
      return null;
    }
  }

  // 🟢 FULLY INTEGRATED: Google Sign-In with your JSON Client ID
  Future<User?> signInWithGoogle() async {
    try {
      // 1. Only initialize if it hasn't been called yet during this app session
      if (!_isGoogleInitialized) {
        await GoogleSignIn.instance.initialize(
          // 🟢 Injected Client Type 3 ID from your google-services.json
          clientId:
              '851476540070-c4a8bao7qspb2lmrjcl1a98ltvaq850d.apps.googleusercontent.com',
        );
        _isGoogleInitialized = true;
      }

      // 2. Check if the active platform natively supports the overlay workflow
      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        debugPrint(
            "Platform doesn't support immediate direct authentication workflows.");
        return null;
      }

      // 3. STEP 1: Authentication (Identity Verification)
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // 4. STEP 2: Authorization (Explicitly requesting scopes for the Access Token)
      final List<String> scopes = ['email'];
      final GoogleSignInClientAuthorization authorizedUser =
          await googleUser.authorizationClient.authorizeScopes(scopes);

      // 5. Construct structural credentials for the Firebase handshake
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken:
            authorizedUser.accessToken, // Obtained securely from Authorization
        idToken: googleUser
            .authentication.idToken, // Obtained securely from Identity
      );

      // 6. Complete authentication inside Firebase Auth
      UserCredential result = await _auth.signInWithCredential(credential);
      User? user = result.user;

      // 7. Sync payload attributes smoothly over to Firestore document records
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName':
              user.displayName ?? user.email?.split('@')[0] ?? 'APU Student',
          'profilePic': user.photoURL ?? '',
          'lastLogin': FieldValue.serverTimestamp(),
          'studentId': 'TPXXXXXX',
          'isPrivate': false,
          'bio': 'New APU Student',
        }, SetOptions(merge: true));
      }

      return user;
    } catch (e) {
      debugPrint("Google Sign-In error: ${e.toString()}");
      return null;
    }
  }

  // Sign Out for v7.x Singleton
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Sign out error: ${e.toString()}");
    }
  }
}
