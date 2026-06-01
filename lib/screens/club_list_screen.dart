// ignore_for_file: deprecated_member_use, use_build_context_synchronously

import 'package:assignment/screens/club_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/club_model.dart';
import '../widgets/club_card.dart';
import 'club_details_screen.dart';
import 'add_event_screen.dart';

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _userRole = 'student';
  String _currentUserName = 'Student';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    if (_currentUserId.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();
      if (mounted && doc.exists) {
        setState(() {
          _userRole = doc.data()?['role'] ?? 'student';
          _currentUserName = doc.data()?['name'] ?? 'Member';
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _sendNotification({
    required String userId,
    required String title,
    required String body,
  }) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'message': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'removal',
    });
  }

  // ─────────────────────────────────────────────
  //  TOP-LEVEL BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_userRole != 'club_leader') {
      return _buildExploreLayout();
    }

    // Club Leader: tabbed dashboard
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Club Leader Dashboard"),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryBlue,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryBlue,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_rounded), text: "My Club"),
              Tab(icon: Icon(Icons.search), text: "Explore"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1 – leader's own club management
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clubs')
                  .where('leaderId', isEqualTo: _currentUserId)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildCreateClubPrompt();
                }
                final clubDoc = snapshot.data!.docs.first;
                final String status = clubDoc['status'] ?? 'pending';
                if (status == 'pending') {
                  return _buildPendingApprovalScreen(clubDoc);
                }
                if (status == 'rejected') return _buildRejectedScreen(clubDoc);
                return _buildClubManagementInterface(clubDoc);
              },
            ),

            // TAB 2 – explore all clubs
            _buildExploreContent(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EXPLORE LAYOUT (student view)
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  //  EXPLORE LAYOUT (With Create Club Floating Button)
  // ─────────────────────────────────────────────
  // 🚀 Add this variable to your State class if it's not already there:
  // String _selectedFilter = 'All';

  // ─────────────────────────────────────────────
  //  EXPLORE LAYOUT
  // ─────────────────────────────────────────────
  Widget _buildExploreLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text(
          "Explore Clubs",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildFilterChips(), // 🚀 Added horizontal filter bar
          Expanded(child: _buildExploreContent()),
        ],
      ),
      floatingActionButton: _userRole == 'club_leader'
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryBlue,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Create Club",
                style:
                    TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showCreateClubSheet(context),
            ),
    );
  }

  // ─────────────────────────────────────────────
  //  FILTER CHIPS WIDGET
  // ─────────────────────────────────────────────
  Widget _buildFilterChips() {
    final categories = ['All', 'Sports', 'Academic', 'Arts', 'Tech'];

    return Container(
      height: 60,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = _selectedFilter == category;

          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              selectedColor: AppTheme.primaryBlue,
              backgroundColor: const Color(0xFFF0F2F5),
              checkmarkColor: Colors.white,
              // 🚀 FIX: Correctly styling the chip text via labelStyle
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (bool selected) {
                if (selected) {
                  setState(() {
                    _selectedFilter = category;
                  });
                }
              },
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EXPLORE CONTENT (Dynamically Filtered & Hides Owned Club)
  // ─────────────────────────────────────────────
  Widget _buildExploreContent() {
    Query query = FirebaseFirestore.instance
        .collection('clubs')
        .where('status', isEqualTo: 'approved');

    if (_selectedFilter != 'All') {
      query = query.where('category', isEqualTo: _selectedFilter);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(), 
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // 🚀 FIX: Filter out any club that belongs to the current logged-in leader
        final allClubs = snapshot.data!.docs;
        final clubs = allClubs.where((doc) {
          final Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
          final String leaderId = data?['leaderId'] ?? '';
          return leaderId != _currentUserId; // Only keep clubs NOT owned by the user
        }).toList();

        if (clubs.isEmpty) {
          return Center(
            child: Text(
              _selectedFilter == 'All'
                  ? "No clubs available yet."
                  : "No clubs found under '$_selectedFilter'.",
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: clubs.length,
          itemBuilder: (context, index) {
            final clubDoc = clubs[index];
            final club = Club.fromFirestore(clubDoc);

            Future<void> handlePostJoinNavigation() async {
              final freshClubDoc = await FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(club.id)
                  .get();

              if (!mounted) return;
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      _buildClubManagementInterface(freshClubDoc),
                ),
              );
            }

            return ClubCard(
              club: club,
              onJoin: () async {
                final membership = await FirebaseFirestore.instance
                    .collection('registrations')
                    .where('clubId', isEqualTo: club.id)
                    .where('userId', isEqualTo: _currentUserId)
                    .get();

                if (!mounted) return;

                if (membership.docs.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          _buildClubManagementInterface(clubDoc),
                    ),
                  );
                } else {
                  final joined = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ClubDetailsScreen(club: club),
                    ),
                  );

                  if (joined == true && mounted) {
                    await handlePostJoinNavigation();
                  }
                }
              },
              onDetails: () async {
                final joined = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClubDetailsScreen(club: club),
                  ),
                );

                if (joined == true && mounted) {
                  await handlePostJoinNavigation();
                }
              },
            );
          },
        );
      },
    );
  }

  void _showCreateClubSheet(BuildContext context) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String selectedCategory = 'Sports';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Register Your Club",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                  labelText: "Club Name", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value:
                  selectedCategory, // 🚀 FIX: Changed 'initialValue' to 'value' for DropdownButtonFormField
              items: ['Sports', 'Academic', 'Arts', 'Tech']
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) => selectedCategory = val!,
              decoration: const InputDecoration(
                  labelText: "Category", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: "Description", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.all(15)),
                onPressed: () async {
                  final String clubName = nameController.text.trim();
                  if (clubName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a club name")),
                    );
                    return;
                  }

                  // Dismiss the bottom sheet panel before async writes
                  Navigator.pop(context);

                  try {
                    // 1. Add the new record to your Firestore database collection
                    DocumentReference newClubRef = await FirebaseFirestore
                        .instance
                        .collection('clubs')
                        .add({
                      'name': clubName,
                      'description': descController.text.trim(),
                      'category': selectedCategory,
                      'leaderId': _currentUserId,
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                    // 2. Fetch the fresh cloud snapshot representation for the approval UI
                    DocumentSnapshot freshClubDoc = await newClubRef.get();

                    // 3. Update the user role field in Firestore database
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(_currentUserId)
                        .update({
                      'role': 'club_leader',
                    });

                    if (mounted) {
                      // 4. Update local state to hide the Create Club button instantly
                      setState(() {
                        _userRole = 'club_leader';
                      });

                      // 5. Notify the user and immediately view the pending display interface
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              "Club request sent! Awaiting Admin approval."),
                          backgroundColor: Colors.orange,
                        ),
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              _buildPendingApprovalScreen(freshClubDoc),
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint("Error launching registration pipeline: $e");
                  }
                },
                child: const Text("Launch Club",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  // ─────────────────────────────────────────────
  //  CLUB MANAGEMENT INTERFACE (leader / member)
  // ─────────────────────────────────────────────

  Widget _buildClubManagementInterface(DocumentSnapshot clubDoc) {
    final data = clubDoc.data() as Map<String, dynamic>;
    final String category = data['category'] ?? '';
    final String name = data['name'] ?? '';
    final String description = data['description'] ?? '';
    final int maxMembers = (data['maxMembers'] as num?)?.toInt() ?? 200;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      body: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('registrations')
              .where('clubId', isEqualTo: clubDoc.id)
              .snapshots(),
          builder: (context, regSnapshot) {
            final int memberCount = regSnapshot.data?.docs.length ?? 0;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubDoc.id)
                  .collection('events')
                  .snapshots(),
              builder: (context, eventSnapshot) {
                final int eventCount = eventSnapshot.data?.docs.length ?? 0;

                // 🚀 Step 1: Safely extract the club leader's user ID from the document data
                final Map<String, dynamic>? clubData =
                    clubDoc.data() as Map<String, dynamic>?;
                final String clubLeaderId = clubData?['leaderId'] ?? '';

                // 🚀 Step 2: Compare with the logged-in user ID to see if they own THIS specific club
                final bool isClubOwner = _currentUserId == clubLeaderId;

                return ListView(
                  children: [
                    // ── Hero Card ──────────────────────────────────────
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0A1628), Color(0xFF122140)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🚀 Step 3: Show the return button if the user is NOT the owner of this specific club
                            if (!isClubOwner) ...[
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Icon(
                                  Icons.arrow_back_ios_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Icon(_categoryIcon(category),
                                      color: Colors.white, size: 32),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (category.isNotEmpty)
                                        _heroPill(
                                          category.toUpperCase(),
                                          Colors.white70,
                                          Colors.white.withValues(alpha: 0.12),
                                        ),
                                      const SizedBox(height: 8),
                                      Text(name,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold)),
                                      if (description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(description,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                                color: Colors.white
                                                    .withValues(alpha: 0.65),
                                                fontSize: 12,
                                                height: 1.4)),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _heroStat('MEMBERS',
                                        '$memberCount / $maxMembers'),
                                  ),
                                  Container(
                                      width: 1,
                                      height: 32,
                                      color:
                                          Colors.white.withValues(alpha: 0.2)),
                                  Expanded(
                                    child: _heroStat('EVENTS', '$eventCount'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Management Tools",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.3,
                            children: [
                              _buildToolCard(
                                "Post Update",
                                Icons.campaign,
                                Colors.orange,
                                () => _showPostUpdateSheet(context, clubDoc.id),
                              ),
                              _buildToolCard(
                                "Manage Members",
                                Icons.manage_accounts,
                                Colors.teal,
                                () {
                                  final String leaderId =
                                      data['leaderId'] ?? '';
                                  final bool isMeOwner =
                                      (leaderId == _currentUserId);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => Scaffold(
                                        backgroundColor: Colors.grey[50],
                                        appBar: AppBar(
                                          title: const Text("Club Members",
                                              style: TextStyle(
                                                  color: Colors.black)),
                                          backgroundColor: Colors.white,
                                          elevation: 0.5,
                                          iconTheme: const IconThemeData(
                                              color: Colors.black),
                                        ),
                                        body: _buildMemberTab(
                                            clubDoc, leaderId, isMeOwner),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              _buildToolCard(
                                "Event Planner",
                                Icons.calendar_today,
                                Colors.indigo,
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) => AddEventScreen(
                                            clubId: clubDoc.id))),
                              ),
                              _buildToolCard(
                                "Club Chat",
                                Icons.chat_bubble_outline,
                                Colors.pink,
                                () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ClubChatScreen(club: clubDoc),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Text("Upcoming Events",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('clubs')
                                .doc(clubDoc.id)
                                .collection('events')
                                .orderBy('date', descending: false)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              final events = snapshot.data!.docs;
                              if (events.isEmpty) {
                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                      child: Text("No events planned yet.")),
                                );
                              }
                              return SizedBox(
                                height: 160,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: events.length,
                                  itemBuilder: (context, index) {
                                    return _buildEventCard(events[index],
                                        clubDoc.id, data['leaderId']);
                                  },
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 24),
                          const Text("Recent Updates",
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('clubs')
                                .doc(clubDoc.id)
                                .collection('updates')
                                .orderBy('timestamp', descending: true)
                                .limit(5)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              final updates = snapshot.data!.docs;
                              return Column(
                                children: updates.map((doc) {
                                  final updateData =
                                      doc.data() as Map<String, dynamic>;
                                  final bool isWelcome = updateData['content']
                                      .toString()
                                      .contains("Welcome");
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      side:
                                          BorderSide(color: Colors.grey[200]!),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isWelcome
                                            ? Colors.blueAccent
                                            : Colors.orangeAccent,
                                        child: Icon(
                                          isWelcome
                                              ? Icons.person_add
                                              : Icons.campaign,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        updateData['content'] ?? "",
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Text(
                                        "${updateData['authorName']} • ${_formatTimestamp(updateData['timestamp'])}",
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[600]),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                          const SizedBox(height: 36),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          }),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'technology':
      case 'tech':
        return Icons.computer_rounded;
      case 'sports':
        return Icons.sports_rounded;
      case 'arts':
        return Icons.palette_rounded;
      case 'music':
        return Icons.music_note_rounded;
      case 'academic':
        return Icons.school_rounded;
      case 'cultural':
        return Icons.diversity_3_rounded;
      case 'environment':
        return Icons.eco_rounded;
      default:
        return Icons.groups_rounded;
    }
  }

  Widget _heroPill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _heroStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8)),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  HELPER WIDGETS
  // ─────────────────────────────────────────────

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "Just now";
    final DateTime date = (timestamp as Timestamp).toDate();
    return "${date.day}/${date.month}/${date.year}";
  }

  Widget _buildToolCard(
      String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildEventCard(
      DocumentSnapshot eventDoc, String clubId, String leaderId) {
    final event = eventDoc.data() as Map<String, dynamic>;
    final DateTime date = (event['date'] as Timestamp).toDate();
    final String creatorId = event['creatorId'] ?? '';
    final bool isCreator = (creatorId == _currentUserId);
    final bool isLeader = (leaderId == _currentUserId);
    final bool canManage = isCreator || isLeader;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${date.day}/${date.month} @ ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(
                      color: Colors.indigo,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (canManage)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon:
                      const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'edit' && isCreator) {
                      _showEditEventSheet(eventDoc);
                    }
                    if (value == 'delete') {
                      _confirmDeleteEvent(clubId, eventDoc.id);
                    }
                  },
                  itemBuilder: (context) => [
                    if (isCreator)
                      const PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit, size: 20),
                          title: Text("Edit"),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline,
                            color: Colors.red, size: 20),
                        title:
                            Text("Delete", style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(event['title'] ?? "Untitled",
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            event['description'] ?? "",
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  MEMBER MANAGEMENT
  // ─────────────────────────────────────────────

  Widget _buildMemberTab(
      DocumentSnapshot clubDoc, String leaderId, bool isMeOwner) {
    final String clubName = clubDoc['name'] ?? "Club";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('clubId', isEqualTo: clubDoc.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading members"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final members = snapshot.data!.docs;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.groups, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    "${members.length} Total Members",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  return _buildMemberTile(
                    members[index],
                    leaderId,
                    clubDoc.id,
                    clubName,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemberTile(DocumentSnapshot member, String leaderId,
      String clubId, String clubName) {
    final bool isTargetOwner = member['userId'] == leaderId;
    final bool isMeOwner = _currentUserId == leaderId;
    // Check if this specific tile belongs to the logged-in student
    final bool isMe = member['userId'] == _currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border:
            isTargetOwner ? Border.all(color: Colors.orange, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage:
              (member['photoUrl'] != null && member['photoUrl'] != "")
                  ? NetworkImage(member['photoUrl'])
                  : null,
          child: (member['photoUrl'] == null || member['photoUrl'] == "")
              ? const Icon(Icons.person)
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member['name'] ?? "Unknown",
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isTargetOwner) ...[
              const SizedBox(width: 8),
              _buildBadge("OWNER", Colors.orange),
            ] else if (isMe) ...[
              const SizedBox(width: 8),
              _buildBadge(
                  "YOU", AppTheme.primaryBlue), // Tag to make it obvious
            ],
          ],
        ),
        subtitle: Text(member['bio'] ?? "No bio available", maxLines: 1),
        trailing: () {
          // Case A: You are the Owner, manage other members
          if (isMeOwner && !isTargetOwner) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: "Transfer Leadership",
                  icon: const Icon(Icons.swap_horiz,
                      color: AppTheme.primaryBlue, size: 22),
                  onPressed: () => _confirmTransfer(
                    member['userId'],
                    member['name'],
                    clubId,
                    clubName,
                  ),
                ),
                IconButton(
                  tooltip: "Remove Member",
                  icon: const Icon(Icons.person_remove_outlined,
                      color: Colors.redAccent, size: 22),
                  onPressed: () => _confirmRemoveMember(
                    member.id,
                    member['name'],
                    member['userId'],
                    clubName,
                    clubId,
                  ),
                ),
              ],
            );
          }

          if (isMe && !isTargetOwner) {
            return TextButton.icon(
              label: const Text("Leave", style: TextStyle(color: Colors.red)),
              icon: const Icon(Icons.logout, color: Colors.red, size: 18),
              onPressed: () => _leaveClub(member.id, clubId, clubName),
            );
          }

          return null; // Return nothing for other regular members
        }(),
      ),
    );
  }

  Future<void> _leaveClub(
      String registrationId, String clubId, String clubName) async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text("Leave $clubName?"),
            content: const Text(
                "Are you sure you want to leave this club? Your activity and roles will be removed."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child:
                      const Text("Leave", style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      // 1. Delete membership entry from registrations collection
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(registrationId)
          .delete();

      // 2. Remove user ID out of the club's 'members' field tracker array
      await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
        'members': FieldValue.arrayRemove([_currentUserId])
      });

      // 3. Remove club ID out of the user's personal 'joinedClubs' tracking array
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .update({
        'joinedClubs': FieldValue.arrayRemove([clubId])
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("You left $clubName"),
            backgroundColor: Colors.redAccent,
          ),
        );

        // ✅ FIXED: Pops past the current dialog and dashboard widgets,
        // stopping exactly when it hits the main interface shell (the very first route).
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      debugPrint("Error leaving club: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to leave club: $e")),
        );
      }
    }
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _confirmRemoveMember(String memberDocId, String name,
      String targetUserId, String clubName, String clubDocId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Member?"),
        content: Text("Are you sure you want to remove $name from $clubName?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Remove", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _sendNotification(
          userId: targetUserId,
          title: "Membership Update",
          body: "You have been removed from $clubName.",
        );
        await FirebaseFirestore.instance
            .collection('registrations')
            .doc(memberDocId)
            .delete();
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubDocId)
            .update({
          'members': FieldValue.arrayRemove([targetUserId])
        });
        await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUserId)
            .update({
          'joinedClubs': FieldValue.arrayRemove([clubDocId])
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text("$name removed.")));
        }
      } catch (e) {
        debugPrint("Error removing member: $e");
      }
    }
  }

  Future<void> _confirmTransfer(
      String newId, String newName, String clubId, String clubName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Transfer Ownership?"),
        content: Text(
            "Make $newName the new owner of $clubName? You will become a regular student."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeTransfer(newId, clubId, clubName);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTransfer(
      String newId, String clubId, String clubName) async {
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .update({'leaderId': newId});
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .update({'role': 'student'});
      await FirebaseFirestore.instance
          .collection('users')
          .doc(newId)
          .update({'role': 'club_leader'});

      final newLeaderReg = await FirebaseFirestore.instance
          .collection('registrations')
          .where('clubId', isEqualTo: clubId)
          .where('userId', isEqualTo: newId)
          .get();
      if (newLeaderReg.docs.isNotEmpty) {
        await newLeaderReg.docs.first.reference.update({'role': 'leader'});
      }

      final oldLeaderReg = await FirebaseFirestore.instance
          .collection('registrations')
          .where('clubId', isEqualTo: clubId)
          .where('userId', isEqualTo: _currentUserId)
          .get();
      if (oldLeaderReg.docs.isNotEmpty) {
        await oldLeaderReg.docs.first.reference.update({'role': 'member'});
      }

      await _sendNotification(
        userId: newId,
        title: "New Responsibility! 👑",
        body: "You have been promoted to the Club Administrator of $clubName.",
      );
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('updates')
          .add({
        'content':
            'Leadership has been transferred. Please welcome your new Administrator! 🎊',
        'authorName': 'System',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _fetchUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Leadership transferred successfully!")),
        );
      }
    } catch (e) {
      debugPrint("Transfer failed: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ─────────────────────────────────────────────
  //  STATUS SCREENS
  // ─────────────────────────────────────────────

  Widget _buildPendingApprovalScreen(DocumentSnapshot clubDoc) {
    // 🚀 Step 1: Safely extract data and provide fallbacks to prevent Null subtype crashes
    final Map<String, dynamic>? data = clubDoc.data() as Map<String, dynamic>?;
    final String clubName = data?['name'] ?? "Your Club";

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty_rounded,
                  size: 100, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                "$clubName is Under Review", // 🚀 Step 2: Use the safe, non-null variable here
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Your club registration has been submitted successfully. "
                "Please wait for an Admin to approve your request before "
                "you can manage events and chat with members.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              const CircularProgressIndicator(color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedScreen(DocumentSnapshot clubDoc) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.report_problem_rounded,
                  size: 100, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                "Club Registration Rejected",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.red),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Reason: ${clubDoc['rejectionReason'] ?? 'No specific reason provided. Please update your details and resubmit.'}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _showEditClubSheet(context, clubDoc),
                icon: const Icon(Icons.edit_note, color: Colors.white),
                label: const Text("Edit & Resubmit",
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCreateClubPrompt() {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_business, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text(
              "You haven't created a club yet!",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue),
              onPressed: () => _showCreateClubSheet(context),
              child: const Text("Create My Club Now",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  FORM SHEETS
  // ─────────────────────────────────────────────

  void _showEditClubSheet(BuildContext context, DocumentSnapshot clubDoc) {
    final nameController = TextEditingController(text: clubDoc['name']);
    final categoryController = TextEditingController(text: clubDoc['category']);
    final descController = TextEditingController(text: clubDoc['description']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Edit Club Details",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text(
                "Please resolve the issues mentioned in the rejection reason.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: "Club Name", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                    labelText: "Category", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: "Description", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await FirebaseFirestore.instance
                          .collection('clubs')
                          .doc(clubDoc.id)
                          .update({
                        'name': nameController.text.trim(),
                        'category': categoryController.text.trim(),
                        'description': descController.text.trim(),
                        'status': 'pending',
                        'updatedAt': FieldValue.serverTimestamp(),
                      });
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text("Resubmitted! Waiting for Admin review."),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    } catch (e) {
                      debugPrint("Error resubmitting club: $e");
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text("Resubmit for Approval",
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showPostUpdateSheet(BuildContext context, String clubId) {
    final updateController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Post Announcement",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: updateController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "What's happening in the club?",
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () =>
                    _submitUpdate(context, clubId, updateController.text),
                child: const Text("Post to Feed",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showEditEventSheet(DocumentSnapshot eventDoc) {
    final event = eventDoc.data() as Map<String, dynamic>;
    final titleController = TextEditingController(text: event['title']);
    final descController = TextEditingController(text: event['description']);
    DateTime selectedDate = (event['date'] as Timestamp).toDate();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Edit Event",
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                      labelText: "Event Title", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                      labelText: "Description", border: OutlineInputBorder()),
                ),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text("Date"),
                        subtitle: Text(
                            "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 30)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setModalState(() => selectedDate = date);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text("Time"),
                        subtitle: Text(selectedTime.format(context)),
                        onTap: () async {
                          final time = await showTimePicker(
                              context: context, initialTime: selectedTime);
                          if (time != null) {
                            setModalState(() => selectedTime = time);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange),
                    onPressed: () {
                      final finalDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      );
                      _updateEvent(eventDoc.reference, titleController.text,
                          descController.text, finalDateTime);
                    },
                    child: const Text("Save Changes",
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteEvent(String clubId, String eventId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Event?"),
        content:
            const Text("This action cannot be undone and will notify members."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('clubs')
                  .doc(clubId)
                  .collection('events')
                  .doc(eventId)
                  .delete();
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEvent(
      DocumentReference ref, String title, String desc, DateTime date) async {
    try {
      await ref.update({
        'title': title.trim(),
        'description': desc.trim(),
        'date': Timestamp.fromDate(date),
        'lastEditedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Event updated!"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  Future<void> _submitUpdate(
      BuildContext context, String clubId, String content) async {
    if (content.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('updates')
          .add({
        'content': content.trim(),
        'authorName': _currentUserName,
        'authorId': _currentUserId,
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text("Announcement posted!"),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }
}
