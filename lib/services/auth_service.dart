import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Sign In
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Sign in error: ${e.toString()}");
      return null;
    }
  }

  // Register with Role
  // Default role is 'student', can be passed as 'club_leader' or 'admin'
  Future<User?> register(String email, String password, {String role = 'student'}) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // --- CREATE FIRESTORE DOCUMENT ---
      if (result.user != null) {
        await _db.collection('users').doc(result.user!.uid).set({
          'email': email,
          'role': role, // Saves 'student', 'club_leader', or 'admin'
          'displayName': email.split('@')[0], // Uses email prefix as default name
          'studentId': 'TPXXXXXX', 
          'isPrivate': false, 
          'bio': 'New APU Student',
          'createdAt': FieldValue.serverTimestamp(), // Good for tracking new users
        });
      }
      
      return result.user;
    } catch (e) {
      print("Registration error: ${e.toString()}");
      return null;
    }
  }

  // Sign Out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}