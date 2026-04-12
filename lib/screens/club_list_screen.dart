import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import 'club_leader_dashboard.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  String _userRole = 'student';

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  void _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (mounted && doc.exists) {
        setState(() => _userRole = doc.data()?['role'] ?? 'student');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // Modern off-white
      appBar: AppBar(
        title: const Text("APU Clubs", 
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final clubs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.8,
            ),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final club = clubs[index];
              return _buildModernCard(club);
            },
          );
        },
      ),
      floatingActionButton: (_userRole == 'club_leader' || _userRole == 'admin')
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ClubLeaderDashboard())),
              label: const Text("Manage"),
              icon: const Icon(Icons.edit_note),
              backgroundColor: const Color(0xFF1A237E),
            )
          : null,
    );
  }

  Widget _buildModernCard(DocumentSnapshot club) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Top Section with Icon
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: const Color(0xFFE8EAF6), // Soft blue
                child: const Icon(Icons.rocket_launch, size: 40, color: Color(0xFF3F51B5)),
              ),
            ),
            // Bottom Section with Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      club['name'] ?? 'Club Name',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      club['category'] ?? 'General',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}