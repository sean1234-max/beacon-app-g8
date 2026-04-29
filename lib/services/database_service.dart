// ignore_for_file: unnecessary_cast

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

  // JOIN EVENT LOGIC — returns the created ticket's Firestore document ID
  Future<String> joinEvent(String eventId, String userId,
      {String eventTitle = ''}) async {
    await _db.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayUnion([userId])
    });

    final userDoc = await _db.collection('users').doc(userId).get();
    final userData = userDoc.data() as Map<String, dynamic>? ?? {};

    final user = FirebaseAuth.instance.currentUser;
    final docRef = await _db.collection('event_registrations').add({
      'eventId': eventId,
      'eventTitle': eventTitle,
      'userId': userId,
      'userName': userData['displayName'] ?? user?.displayName ?? 'APU Student',
      'studentId': userData['studentId'] ?? 'TPXXXXXX',
      'userEmail': user?.email ?? '',
      'paymentStatus': 'confirmed',
      'isCheckedIn': false,
      'registeredAt': FieldValue.serverTimestamp(),
    });

    print('[joinEvent] Ticket saved → ticketId=${docRef.id}');
    return docRef.id;
  }

  // LEAVE EVENT — removes participant, deletes ticket + receipt
  Future<void> leaveEvent(String eventId, String userId) async {
    // 1. Remove from participants array
    await _db.collection('events').doc(eventId).update({
      'participants': FieldValue.arrayRemove([userId]),
    });

    // 2. Delete the event_registrations ticket document
    final tickets = await _db
        .collection('event_registrations')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .get();
    for (final doc in tickets.docs) {
      await doc.reference.delete();
    }

    // 3. Delete the payment receipt (if one was uploaded)
    final receiptRef = _db
        .collection('events')
        .doc(eventId)
        .collection('receipts')
        .doc(userId);
    final receiptSnap = await receiptRef.get();
    if (receiptSnap.exists) await receiptRef.delete();
  }

  // Find the existing ticket document ID for a given user + event
  Future<String?> findTicketId(String eventId, String userId) async {
    final query = await _db
        .collection('event_registrations')
        .where('eventId', isEqualTo: eventId)
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first.id;
  }

  Future<void> joinClub(String clubId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Fetch current student's profile data
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>;

    // 2. Create the registration
    await FirebaseFirestore.instance.collection('registrations').add({
      'clubId': clubId,
      'userId': user.uid,
      'name': userData['displayName'] ?? "APU Student",
      'bio': userData['bio'] ?? "No bio yet.",
      'photoUrl':
          userData['photoUrl'] ?? "", // Using the field from your Profile logic
      'joinedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, dynamic>?> verifyEventTicket(String qrData) async {
    // Handle QR format from event_details_screen: "EVENT:{eventId}|USER:{userId}"
    final eventMatch = RegExp(r'EVENT:([^|]+)').firstMatch(qrData);
    final userMatch = RegExp(r'USER:(.+)').firstMatch(qrData);

    if (eventMatch != null && userMatch != null) {
      final eventId = eventMatch.group(1)!;
      final userId = userMatch.group(1)!;
      final query = await _db
          .collection('event_registrations')
          .where('eventId', isEqualTo: eventId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return {'ticketId': query.docs.first.id, ...query.docs.first.data()};
    }

    // Fallback: treat qrData as a direct Firestore document ID (ticket_screen QR)
    final doc = await _db.collection('event_registrations').doc(qrData).get();
    if (!doc.exists) return null;
    return {'ticketId': doc.id, ...doc.data()!};
  }

  Future<bool> checkInParticipant(String ticketId) async {
    final leaderUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

    return _db.runTransaction<bool>((transaction) async {
      final docRef = _db.collection('event_registrations').doc(ticketId);

      final snapshot = await transaction.get(docRef);

      if (!snapshot.exists) return false;
      if (snapshot.data()?['isCheckedIn'] == true) return false;

      transaction.update(docRef, {
        'isCheckedIn': true,
        'checkedInAt': FieldValue.serverTimestamp(),
        'checkedInBy': leaderUid,
      });

      return true;
    });
  }
}
