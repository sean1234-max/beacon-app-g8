import 'package:assignment/models/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/club_model.dart';
import '../theme/app_theme.dart';

class ClubDetailsScreen extends StatelessWidget {
  final Club club;
  const ClubDetailsScreen({super.key, required this.club});

  Future<void> _joinClub(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // 1. Check if already a member first
    final existing = await FirebaseFirestore.instance
        .collection('registrations')
        .where('clubId', isEqualTo: club.id)
        .where('userId', isEqualTo: user.uid)
        .get();

    if (existing.docs.isNotEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You are already a member!")),
        );
      }
      return;
    }

    // 2. Fetch user data for the registration record
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    
    // 3. Create the registration document
    await FirebaseFirestore.instance.collection('registrations').add({
      'clubId': club.id,
      'userId': user.uid,
      'name': userDoc.data()?['displayName'] ?? "Student",
      'bio': userDoc.data()?['bio'] ?? "APU Student",
      'photoUrl': userDoc.data()?['photoUrl'] ?? "",
      'role': 'member',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // --- NEW NOTIFICATION LOGIC START ---

    // 4. Update the User document with the club ID (for broadcast targeting)
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'joinedClubs': FieldValue.arrayUnion([club.id])
    });

    // 5. Send the welcome notification
    await NotificationService.sendNotification(
      userId: user.uid,
      title: "Welcome to ${club.name}! 🌟",
      message: "You've successfully joined the club. Check your notifications for new updates and events!",
      type: "approval", // Green checkmark icon
    );

    // --- NEW NOTIFICATION LOGIC END ---

    if (context.mounted) {
      // Navigator.pop(context); // Optional: keep this if you want to close the details screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Welcome to ${club.name}!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(club.name)),
      body: Column(
        children: [
          // Hero Header
          Container(
            height: 200,
            width: double.infinity,
            color: AppTheme.primaryBlue,
            child: const Icon(Icons.groups, size: 80, color: Colors.white),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(club.category,
                    style: const TextStyle(
                        color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("About the Club",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(club.description,
                    style: const TextStyle(fontSize: 16, color: Colors.black87)),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: SizedBox(
              width: double.infinity,
              // Use StreamBuilder to listen to the registration status live
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('registrations')
                    .where('clubId', isEqualTo: club.id)
                    .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Check if the user is already registered in this club
                  final bool isMember = snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: isMember ? Colors.grey : AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    // If they are a member, the button is disabled (onPressed is null)
                    onPressed: isMember ? null : () => _joinClub(context),
                    child: Text(
                      isMember ? "Already a Member" : "Join Club",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                },
              ),
            ),
          )
        ],
      ),
    );
  }
}