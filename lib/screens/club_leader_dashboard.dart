import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart'; // Adjust path to your theme file

class ClubLeaderDashboard extends StatelessWidget {
  const ClubLeaderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text("My Managed Clubs")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .where('leaderId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final clubs = snapshot.data!.docs;

          if (clubs.isEmpty) {
            return const Center(child: Text("You haven't registered any clubs yet."));
          }

          return ListView.builder(
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              final String status = club['status'] ?? 'pending';

              // 1. LOCK: If pending, show ONLY the pending card and STOP here
              if (status == 'pending') {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.orange.shade50,
                  child: const ListTile(
                    leading: Icon(Icons.hourglass_top, color: Colors.orange),
                    title: Text("Club Pending Approval", style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("The admin is currently reviewing your request."),
                  ),
                );
              }

              if (status == 'rejected') {
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.error_outline, color: Colors.red),
                    title: Text(club['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Rejected: ${club['rejectionReason'] ?? 'Please check details.'}"),
                    trailing: ElevatedButton(
                      onPressed: () => _showEditClubSheet(context, club),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Edit", style: TextStyle(color: Colors.white)),
                    ),
                  ),
                );
              }

              // 3. ACCESS GRANTED: Only shows if status is 'approved'
              // (Because the previous if-statements would have returned a widget already)
              return ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue,
                  child: Icon(Icons.groups, color: Colors.white),
                ),
                title: Text(club['name']),
                subtitle: const Text("Status: Active • Tap to manage events"),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCreateEventSheet(context, club.id),
              );
            },
          );
        },
      ),
    );
  }
}



void _showCreateEventSheet(BuildContext context, String clubId) {
  final titleController = TextEditingController();
  final descController = TextEditingController();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Create Club Event", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          TextField(controller: titleController, decoration: const InputDecoration(labelText: "Event Title")),
          TextField(controller: descController, decoration: const InputDecoration(labelText: "Event Description")),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              String eventTitle = titleController.text.trim();
              if (eventTitle.isEmpty) return;

              try {
                // 1. Save the event to Firestore
                await FirebaseFirestore.instance.collection('events').add({
                  'title': eventTitle,
                  'description': descController.text,
                  'clubId': clubId, 
                  'creatorId': FirebaseAuth.instance.currentUser?.uid,
                  'dateTime': DateTime.now(), 
                  'participants': [], // Initialize empty participants list
                });

                // 2. FETCH CLUB MEMBERS AND NOTIFY
                // This assumes your users have an array field called 'joinedClubs'
                final membersSnapshot = await FirebaseFirestore.instance
                    .collection('users')
                    .where('joinedClubs', arrayContains: clubId)
                    .get();

                if (membersSnapshot.docs.isNotEmpty) {
                  WriteBatch batch = FirebaseFirestore.instance.batch();
                  
                  for (var userDoc in membersSnapshot.docs) {
                    DocumentReference notifRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(userDoc.id)
                        .collection('notifications')
                        .doc();

                    batch.set(notifRef, {
                      'title': "New Club Event! 🎊",
                      'message': "A new event '$eventTitle' has been posted. Check it out!",
                      'type': 'event',
                      'isRead': false,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  }
                  await batch.commit();
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Event posted and members notified!")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Error: $e")),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text("Post Event", style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

void _showEditClubSheet(BuildContext context, DocumentSnapshot clubDoc) {
  // Pre-fill the controllers with the existing (rejected) data
  final nameController = TextEditingController(text: clubDoc['name']);
  final categoryController = TextEditingController(text: clubDoc['category']);
  final descController = TextEditingController(text: clubDoc['description']);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Edit & Resubmit Club", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          const SizedBox(height: 10),
          const Text("Update your details based on the admin's feedback.",
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: "Club Name")),
          TextField(controller: categoryController, decoration: const InputDecoration(labelText: "Category")),
          TextField(controller: descController, decoration: const InputDecoration(labelText: "Description"), maxLines: 3),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  // Update the document and RESET status to pending
                  await FirebaseFirestore.instance.collection('clubs').doc(clubDoc.id).update({
                    'name': nameController.text.trim(),
                    'category': categoryController.text.trim(),
                    'description': descController.text.trim(),
                    'status': 'pending', // Resetting triggers the Admin review flow again
                    'updatedAt': FieldValue.serverTimestamp(),
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Club details updated and resubmitted for approval!")),
                    );
                  }
                } catch (e) {
                  debugPrint("Error updating club: $e");
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: const Text("Resubmit for Approval", style: TextStyle(color: Colors.white)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}