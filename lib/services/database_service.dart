import 'package:cloud_firestore/cloud_firestore.dart';
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
}