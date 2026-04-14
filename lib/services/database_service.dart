import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/event_model.dart';
import '../models/club_model.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // GET CLUBS
  Stream<List<Club>> getClubs() {
    return _db.collection('clubs').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList());
  }

  // GET CLUBS BY CATEGORY
  Stream<List<Club>> getClubsByCategory(String category) {
    return _db
        .collection('clubs')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Club.fromFirestore(doc)).toList());
  }

  // GET ALL EVENTS
  Stream<List<Event>> getEvents() {
    return _db.collection('events').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList());
  }

  // GET USER REGISTERED EVENTS (For the Dashboard)
  Stream<List<Event>> getUserRegisteredEvents(String userId) {
    return _db
        .collection('events')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Event.fromFirestore(doc)).toList());
  }

  // JOIN EVENT LOGIC
  Future<void> joinEvent(String eventId, String userId) async {
    await _db.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> joinClub(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Fetch current student's profile data
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    // 2. Create the registration
    await FirebaseFirestore.instance.collection('registrations').add({
      'clubId': clubId,
      'userId': user.uid,
      'name': userData['displayName'] ?? "APU Student",
      'bio': userData['bio'] ?? "No bio yet.",
      'photoUrl': userData['photoUrl'] ?? "", // Using the field from your Profile logic
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }
}