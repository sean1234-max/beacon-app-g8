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
        // Only fetch clubs where the current user is the leader
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .where('leaderId', isEqualTo: currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final clubs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return ListTile(
                title: Text(club['name']),
                subtitle: Text(club['category']),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _showCreateEventSheet(context, club.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateClubSheet(context),
        label: const Text("Create Club"),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }
}

void _showCreateClubSheet(BuildContext context) {
  final nameController = TextEditingController();
  final categoryController = TextEditingController();
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
          Text("Register New Club", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          TextField(controller: nameController, decoration: const InputDecoration(labelText: "Club Name")),
          TextField(controller: categoryController, decoration: const InputDecoration(labelText: "Category (e.g. Sports)")),
          TextField(controller: descController, decoration: const InputDecoration(labelText: "Description")),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('clubs').add({
                'name': nameController.text,
                'category': categoryController.text,
                'description': descController.text,
                'leaderId': FirebaseAuth.instance.currentUser?.uid,
              });
              Navigator.pop(context);
            },
            child: const Text("Create Club"),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
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
          Text("Create Club Event", 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          TextField(controller: titleController, decoration: const InputDecoration(labelText: "Event Title")),
          TextField(controller: descController, decoration: const InputDecoration(labelText: "Event Description")),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('events').add({
                'title': titleController.text,
                'description': descController.text,
                'clubId': clubId, // This links the event to the club!
                'dateTime': DateTime.now(), // We can add a proper picker later
                'createdBy': FirebaseAuth.instance.currentUser?.uid,
              });
              Navigator.pop(context);
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