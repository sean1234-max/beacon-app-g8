import 'dart:convert';
import 'package:assignment/screens/event_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'add_event_screen.dart';
import 'my_tickets_screen.dart';
import 'login_screen.dart';
import 'edit_profile_screen.dart';
import 'club_management_screen.dart';
import 'club_list_screen.dart';
import 'event_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isUploading = false;

  Future<void> _pickAndUploadPhoto() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final bytes = await picked.readAsBytes();
      final base64Image = base64Encode(bytes);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'photoUrl': base64Image});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // Supports both Base64 strings (Firestore) and http URLs (future Storage)
  ImageProvider? _getImageProvider(String photoUrl) {
    if (photoUrl.isEmpty) return null;
    if (photoUrl.startsWith('http')) return NetworkImage(photoUrl);
    try {
      return MemoryImage(base64Decode(photoUrl));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildStatsRow(),
            _buildQuickActions(context),
            _buildMenuItems(),
            _buildLogout(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HEADER
  // ─────────────────────────────────────────────

  Widget _buildHeader() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Text("No user logged in",
          style: TextStyle(color: Colors.red));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        String name = 'Loading...';
        String email = 'Loading...';
        String studentId = 'Loading...';
        String photoUrl = '';
        String bio = '';

        if (snapshot.hasData && snapshot.data!.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['displayName'] ?? 'No Name';
          email = data['email'] ?? 'No Email';
          studentId = data['studentId'] ?? 'No TP';
          photoUrl = data['photoUrl'] ?? '';
          bio = data['bio'] ?? '';
        }

        return Container(
          width: double.infinity,
          color: const Color(0xFF0A1628),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row: greeting (left) + photo (right)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hello',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 16)),
                        Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined,
                                color: Colors.white54, size: 13),
                            const SizedBox(width: 4),
                            Text(email,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (bio.isNotEmpty)
                          Row(children: [
                            const Icon(Icons.edit_note,
                                color: Colors.white54, size: 13),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(bio,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white54, fontSize: 12)),
                            ),
                          ]),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),

                  // Right: profile photo + camera button
                  GestureDetector(
                    onTap: _isUploading ? null : _pickAndUploadPhoto,
                    child: Stack(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: Colors.white24,
                          backgroundImage: _getImageProvider(photoUrl),
                          child: _getImageProvider(photoUrl) == null
                              ? const Icon(Icons.person,
                                  size: 48, color: Colors.white54)
                              : null,
                        ),

                        // Loading overlay
                        if (_isUploading)
                          Positioned.fill(
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black45,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Camera icon badge
                        if (!_isUploading)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // University + Student ID cards
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildInfoCard(Icons.school_rounded, 'UNIVERSITY',
                          'Asia Pacific University'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildInfoCard(
                          Icons.badge_rounded, 'STUDENT ID', studentId),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────
  //  STATS ROW
  // ─────────────────────────────────────────────

  Widget _buildStatsRow() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // EVENTS — count events the user has registered for
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('participants', arrayContains: uid)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return _buildStatCard(
                  Icons.calendar_today_rounded,
                  '$count',
                  'EVENTS',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MyTicketsScreen())),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // CLUBS — count clubs the user has joined
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('registrations')
                  .where('userId', isEqualTo: uid)
                  .snapshots(),
              builder: (context, snap) {
                final count = snap.data?.docs.length ?? 0;
                return _buildStatCard(
                  Icons.people_rounded,
                  '$count',
                  'CLUBS',
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const ClubsScreen())),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  // ─────────────────────────────────────────────
  //  QUICK ACTIONS
  // ─────────────────────────────────────────────

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      {
        'icon': Icons.qr_code_scanner_rounded,
        'label': 'Scan QR',
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const EventSelectionScreen())),
      },
      {
        'icon': Icons.confirmation_num_outlined,
        'label': 'My Tickets',
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MyTicketsScreen())),
      },
      {
        'icon': Icons.event_available_rounded,
        'label': 'Create Events',
        'onTap': () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AddEventScreen())),
      },
      {
        'icon': Icons.edit_outlined,
        'label': 'Manage Events',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClubManagementScreen()),
          );
        },
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quick Actions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.55,
            children: actions.map((a) {
              return Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: a['onTap'] as VoidCallback,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Icon(Icons.north_east_rounded,
                              color: Colors.grey[350], size: 16),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(a['icon'] as IconData,
                                  color: const Color(0xFF003366), size: 22),
                            ),
                            const SizedBox(height: 8),
                            Text(a['label'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  MENU ITEMS
  // ─────────────────────────────────────────────

  Widget _buildMenuItems() {
    final items = [
      {
        'icon': Icons.edit_outlined,
        'title': 'Edit Profile',
        'sub': 'Update your personal details',
        'onTap': () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => const EditProfileScreen()));
        }
      },
      {
        'icon': Icons.history_rounded,
        'title': 'Event History',
        'sub': 'View your past events',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EventHistoryScreen()),
          );
        }
      },
      {
        'icon': Icons.people_outline,
        'title': 'Club Management',
        'sub': 'Roles & memberships',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ClubManagementScreen()),
          );
        },
      },
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final i = entry.key;
            final item = entry.value;
            return Column(
              children: [
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item['icon'] as IconData,
                        color: const Color(0xFF003366), size: 20),
                  ),
                  title: Text(item['title'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text(item['sub'] as String,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Colors.grey),
                  onTap: item['onTap'] as VoidCallback,
                ),
                if (i < items.length - 1) const Divider(height: 1, indent: 60),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  LOGOUT
  // ─────────────────────────────────────────────

  Widget _buildLogout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                try {
                  // 1. Sign out from Firebase Auth
                  await FirebaseAuth.instance.signOut();

                  // 2. Clear the screen stack and instantly jump to Login Screen
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error logging out: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.logout_rounded, color: Colors.red),
              label: const Text('Log Out',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Colors.red),
                backgroundColor: Colors.red.withValues(alpha: 0.05),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0DC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.orange[700], size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String count, String label,
      {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF003366), size: 26),
            const SizedBox(height: 8),
            Text(count,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
