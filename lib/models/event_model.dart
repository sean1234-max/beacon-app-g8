import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class Event {
  final String id;
  final String title;
  final String description;
  final String location;
  final DateTime dateTime;
  final List<String> participants;

  Event({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.dateTime,
    required this.participants,
  });

  // This helper makes the date look nice on the Dashboard (e.g., "12 Apr")
  String get date => DateFormat('dd MMM').format(dateTime);

  // This is the "instruction manual" Firestore was looking for
  factory Event.fromFirestore(DocumentSnapshot doc) {
  // Use a Safe Map cast
    final Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Event(
      id: doc.id,
      title: data['title'] ?? 'No Title',
      description: data['description'] ?? '',
      location: data['location'] ?? 'No Location',
      // Ensure we handle the Timestamp safely
      dateTime: data['dateTime'] != null 
          ? (data['dateTime'] as Timestamp).toDate() 
          : DateTime.now(),
      // CRITICAL: This is likely where the error happens. 
      // We must cast the list properly.
      participants: data['participants'] != null 
          ? List<String>.from(data['participants']) 
          : [],
    );
  }
}