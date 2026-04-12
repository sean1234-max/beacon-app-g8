import 'package:cloud_firestore/cloud_firestore.dart';

class Club {
  final String id; // The document ID (e.g., mScvRyg...)
  final String name;
  final String category;
  final String description;
  final String leaderId;

  Club({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.leaderId,
  });

  // Factory method to safely extract data from Firestore
  factory Club.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return Club(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      leaderId: data['leaderId'] ?? '',
    );
  }

  // Optional: Method to convert the object back to a map for saving to Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'leaderId': leaderId,
    };
  }
}