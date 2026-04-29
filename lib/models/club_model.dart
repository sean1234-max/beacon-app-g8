import 'package:cloud_firestore/cloud_firestore.dart';

class Club {
  final String id;
  final String name;
  final String category;
  final String description;
  final String leaderId;
  final String imageUrl;
  final int memberCount;
  final int maxMembers;
  final bool recruitmentOpen;

  Club({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.leaderId,
    this.imageUrl = '',
    this.memberCount = 0,
    this.maxMembers = 200,
    this.recruitmentOpen = true,
  });

  factory Club.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    List members = data['members'] ?? [];

    return Club(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      leaderId: data['leaderId'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      memberCount: members.length,
      maxMembers: (data['maxMembers'] as num?)?.toInt() ?? 200,
      recruitmentOpen: data['recruitmentOpen'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'category': category,
      'description': description,
      'leaderId': leaderId,
    };
  }
}
