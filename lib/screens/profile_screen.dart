import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'privacy_security_screen.dart';
import 'club_leader_dashboard.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool _isUploading = false;
  String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _imageUrl = user?.photoURL;
  }

  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() => _isUploading = true);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child('${user!.uid}.jpg');

      if (kIsWeb) {
        // Use bytes for Web
        await ref.putData(await pickedFile.readAsBytes());
      } else {
        // Use File for Mobile (Android/iOS)
        await ref.putFile(File(pickedFile.path));
      }

      final url = await ref.getDownloadURL();
      await user?.updatePhotoURL(url);

      setState(() {
        _imageUrl = url;
        _isUploading = false;
      });
    } catch (e) {
      setState(() => _isUploading = false);
      print("Upload error: $e");
    }
  }

  @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              // --- HEADER SECTION ---
              Container(
                height: 280, // Increased height slightly to fit the Bio
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(50),
                    bottomRight: Radius.circular(50),
                  ),
                ),
                child: StreamBuilder<DocumentSnapshot>(
                  // Listen to the user's specific document in Firestore
                  stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
                  builder: (context, snapshot) {
                    // Fetch values from Firestore, fallback to Auth if Firestore is loading
                    String name = snapshot.data?.get('displayName') ?? user?.displayName ?? "APU Student";
                    String bio = snapshot.data?.get('bio') ?? "No bio added yet.";

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: Colors.white,
                              backgroundImage: _imageUrl != null ? NetworkImage(_imageUrl!) : null,
                              child: _imageUrl == null 
                                  ? const Icon(Icons.person, size: 60, color: AppTheme.primaryBlue) 
                                  : null,
                            ),
                            if (_isUploading)
                              const Positioned.fill(child: CircularProgressIndicator(color: Colors.white)),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _uploadImage,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        // --- THE BIO SECTION ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                          child: Text(
                            bio,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic),
                          ),
                        ),
                        Text(
                          user?.email ?? "",
                          style: const TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                      ],
                    );
                  }
                ),
              ),

              // --- INFO & SETTINGS SECTION ---
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildProfileTile(Icons.school, "University", "Asia Pacific University"),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
                      builder: (context, snapshot) {
                        // Check if we have data and if the document exists
                        if (!snapshot.hasData || !snapshot.data!.exists) {
                          return const CircularProgressIndicator(); // Or a simple placeholder
                        }

                        // Use the data() map to safely access fields
                        var data = snapshot.data!.data() as Map<String, dynamic>;

                        // If the field doesn't exist in the map, it returns null, and we default to "student"
                        String role = data.containsKey('role') ? data['role'] : "student";
                        String studentId = data.containsKey('studentId') ? data['studentId'] : "TPXXXXXX";
                        
                        bool isClubLeader = role == "club_leader";

                        return Column(
                          children: [
                            _buildProfileTile(Icons.badge, "Student ID", studentId),
                            const Divider(height: 40),
                            
                            _buildMenuTile(Icons.edit, "Edit Profile", () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const EditProfileScreen()));
                            }),
                            
                            _buildMenuTile(Icons.notifications, "Notifications", () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                            }),
                            
                            _buildMenuTile(Icons.security, "Privacy & Security", () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const PrivacySecurityScreen()));
                            }),

                            // --- INSERTED CLUB MANAGEMENT BUTTON ---
                            if (isClubLeader) 
                            _buildMenuTile(Icons.admin_panel_settings, "Club Management", () {
                              Navigator.push(
                                context, 
                                MaterialPageRoute(builder: (context) => const ClubLeaderDashboard())
                              );
                            }),
                          ],
                        );
                      }
                    ),
                    
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => AuthService().signOut(),
                        icon: const Icon(Icons.logout),
                        label: const Text("Logout"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red, 
                          side: const BorderSide(color: Colors.red)
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

  Widget _buildProfileTile(IconData icon, String label, String value) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryBlue),
      title: Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildMenuTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}

