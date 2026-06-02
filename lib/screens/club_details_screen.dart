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

    try {
      // 2. Fetch user data for personalized updates
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final String userName = userDoc.data()?['displayName'] ?? "Student";

      // 3. Create the registration document (used for Member List)
      await FirebaseFirestore.instance.collection('registrations').add({
        'clubId': club.id,
        'userId': user.uid,
        'name': userName,
        'bio': userDoc.data()?['bio'] ?? "APU Student",
        'photoUrl': userDoc.data()?['photoUrl'] ?? "",
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // --- UPDATE CLUB DOCUMENT ARRAY ---
      await FirebaseFirestore.instance.collection('clubs').doc(club.id).update({
        'members': FieldValue.arrayUnion([user.uid])
      });

      // --- RECENT UPDATES ANNOUNCEMENT ---
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(club.id)
          .collection('updates')
          .add({
        'content': 'Welcome $userName to the club! 🎊',
        'authorName': 'System',
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 4. Update the User document with the club ID
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'joinedClubs': FieldValue.arrayUnion([club.id])
      });

      // 5. Send the welcome notification
      await NotificationService.sendNotification(
        userId: user.uid,
        title: "Welcome to ${club.name}! 🌟",
        message:
            "You've successfully joined the club. Check your notifications for new updates!",
        type: "approval",
      );

      // 6. Notify parent layout and exit details view cleanly
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Welcome to ${club.name}!"),
            backgroundColor: Colors.green,
          ),
        );

        // ✅ PASS RESULT BACK: Closes the details page and signals
        // club_list_screen.dart to transition smoothly to the dashboard route.
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error joining club: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to join club: $e")),
        );
      }
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
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                const Text("About the Club",
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(club.description,
                    style:
                        const TextStyle(fontSize: 16, color: Colors.black87)),
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
                // listens CONTINUOUSLY. Every time Firestore data changes, the UI rebuilds automatically.
                stream: FirebaseFirestore.instance
                    .collection('registrations')
                    .where('clubId', isEqualTo: club.id)
                    .where('userId',
                        isEqualTo: FirebaseAuth.instance.currentUser?.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  // Check if the user is already registered in this club
                  final bool isMember =
                      snapshot.hasData && snapshot.data!.docs.isNotEmpty;

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isMember ? Colors.grey : AppTheme.primaryBlue,
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
