import 'package:assignment/screens/club_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../models/club_model.dart'; // Import your model
import '../widgets/club_card.dart'; // Import your widget
import 'club_details_screen.dart'; // Import your details screen

class ClubsScreen extends StatefulWidget {
  const ClubsScreen({super.key});

  @override
  State<ClubsScreen> createState() => _ClubsScreenState();
}

class _ClubsScreenState extends State<ClubsScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  String _userRole = 'student';
  // ADD THIS: Default name to 'Student' while loading
  String _currentUserName = 'Student'; 

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  // Improved to fetch both Role and Name in one go
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
          // DEBUG: Check your console to see if the name is correct
          print("Logged in as: $_currentUserName"); 
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Students or Admins see the Explore Layout
    if (_userRole != 'club_leader') {
      return _buildExploreLayout();
    }

    // 2. Club Leaders check if they own a club
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .where('leaderId', isEqualTo: _currentUserId)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 1. Check if the leader actually has any clubs
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildCreateClubPrompt();
        }

        final clubDoc = snapshot.data!.docs.first;
        final String clubName = clubDoc['name'] ?? "";
        // Get the status from Firestore (default to 'pending' if missing)
        final String status = clubDoc['status'] ?? 'pending';

        // 2. SAFETY CHECK: If the name is empty
        if (clubName.trim().isEmpty) {
          return _buildBrokenClubError(); // Your existing broken club logic
        }

        // --- NEW STATUS GATEKEEPER ---
        
        // 3. If Pending: Show a "Waiting" screen
        if (status == 'pending') {
          return _buildPendingApprovalScreen(clubDoc);
        }

        // 4. If Rejected: Show a "Rejected" screen with an Edit button
        if (status == 'rejected') {
          return _buildRejectedScreen(clubDoc);
        }

        // 5. Only if status is 'approved', proceed to the full interface
        if (status == 'approved') {
          return _buildClubManagementInterface(clubDoc);
        }

        // Fallback in case of unexpected status
        return _buildPendingApprovalScreen(clubDoc);
      },
    );
  }

  Widget _buildBrokenClubError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 60, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              "Incomplete Club Profile",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "We found your club registration, but some details are missing. Please try creating it again or contact APU support.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _showCreateClubSheet(context),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: const Text("Re-create Club", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
  // --- LAYOUT A: EXPLORE GRID (With Smart Navigation) ---
  Widget _buildExploreLayout() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("Explore Clubs",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('clubs')
            .where('status', isEqualTo: 'approved') 
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final clubs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 0.8,
            ),
            itemCount: clubs.length,
            itemBuilder: (context, index) {
              final clubDoc = clubs[index];
              final club = Club(
                id: clubDoc.id,
                name: clubDoc['name'],
                category: clubDoc['category'],
                description: clubDoc['description'],
                leaderId: clubDoc['leaderId'],
              );

              return ClubCard(
                club: club,
                onTap: () async {
                  // Check if this student is already a member
                  final membership = await FirebaseFirestore.instance
                      .collection('registrations')
                      .where('clubId', isEqualTo: club.id)
                      .where('userId', isEqualTo: _currentUserId)
                      .get();

                  if (!mounted) return;
                    if (membership.docs.isNotEmpty) {
                      // Already Joined -> Open the Interface
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                _buildClubManagementInterface(clubDoc),
                          ));
                    } else {
                      // Not Joined -> Open Details/Join Screen
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ClubDetailsScreen(club: club),
                          ));
                    }
                },
              );
            },
          );
        },
      ),
    );
  }

  // --- LAYOUT B: CLUB INTERFACE (Leader & Members View) ---
  Widget _buildClubManagementInterface(DocumentSnapshot clubDoc) {
    final data = clubDoc.data() as Map<String, dynamic>;
    
    return Scaffold(
      backgroundColor: Colors.grey[50], // Light professional background
      body: CustomScrollView(
        slivers: [
          // 1. MODERN HERO HEADER
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(data['name'], 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Replace with a network image if you have a 'coverImage' field
                  Container(color: AppTheme.primaryBlue), 
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 2. QUICK STATS ROW
                  Row(
                    children: [
                      _buildStatCard("Members", "124", Icons.people, Colors.blue),
                      _buildStatCard("Events", "3", Icons.event, Colors.orange),
                      _buildStatCard("Rank", "#4", Icons.emoji_events, Colors.amber),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  const Text("Management Tools", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // 3. FEATURE GRID (Clean & Professional)
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
                        Icons.campaign, // Megaphone icon is great for updates
                        Colors.orange, 
                        () {
                          _showPostUpdateSheet(context, clubDoc.id);
                        },
                      ),
                      _buildToolCard(
                        "Manage Members", 
                        Icons.manage_accounts, 
                        Colors.teal, 
                        () {
                          // We extract the leaderId and check ownership from the clubDoc data
                          final String leaderId = data['leaderId'] ?? '';
                          final bool isMeOwner = (leaderId == _currentUserId);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                backgroundColor: Colors.grey[50],
                                appBar: AppBar(
                                  title: const Text("Club Members", style: TextStyle(color: Colors.black)),
                                  backgroundColor: Colors.white,
                                  elevation: 0.5,
                                  iconTheme: const IconThemeData(color: Colors.black),
                                ),
                                // NOW PASSING ALL 3 ARGUMENTS:
                                body: _buildMemberTab(clubDoc, leaderId, isMeOwner), 
                              ),
                            ),
                          );
                        },
                      ),
                      _buildToolCard(
                        "Event Planner", 
                        Icons.calendar_today, 
                        Colors.indigo, 
                        () {
                          _showCreateEventSheet(context, clubDoc.id);
                        },
                      ),
                      _buildToolCard(
                        "Club Chat", 
                        Icons.chat_bubble_outline, 
                        Colors.pink, 
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ClubChatScreen(club: clubDoc),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Text("Upcoming Events", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  // EVENT LIST STREAM
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('clubs')
                        .doc(clubDoc.id)
                        .collection('events')
                        .orderBy('date', descending: false) // Show soonest events first
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
                          child: const Center(child: Text("No events planned yet.")),
                        );
                      }

                      return SizedBox(
                        height: 160,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: events.length,
                          itemBuilder: (context, index) {
                            // 1. Get the DocumentSnapshot (the whole document)
                            final DocumentSnapshot eventDoc = events[index]; 
                            
                            // 2. Pass the DocumentSnapshot directly
                            // Do NOT call eventDoc.data() here anymore
                            return _buildEventCard(eventDoc, clubDoc.id, data['leaderId']);
                          },
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                  // Place this inside your dashboard's main Column
                  const Text("Recent Updates", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('clubs')
                        .doc(clubDoc.id)
                        .collection('updates')
                        .orderBy('timestamp', descending: true)
                        .limit(5) // Just show the last 5
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      final updates = snapshot.data!.docs;

                      return Column(
                        children: updates.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(color: Colors.grey[200]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: const CircleAvatar(backgroundColor: Colors.orangeAccent, child: Icon(Icons.campaign, color: Colors.white)),
                              title: Text(data['content'] ?? ""),
                              subtitle: Text(
                                "Posted by ${data['authorName']} • ${data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate().toString().substring(0, 10) : 'Just now'}",
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(DocumentSnapshot eventDoc, String clubId, String leaderId) {
    final event = eventDoc.data() as Map<String, dynamic>;
    final DateTime date = (event['date'] as Timestamp).toDate();
    final String creatorId = event['creatorId'] ?? '';
    
    // PERMISSION LOGIC
    // Leader can delete everything; Creator can edit/delete their own
    final bool isCreator = (creatorId == _currentUserId);
    final bool isLeader = (leaderId == _currentUserId);
    final bool canManage = isCreator || isLeader;

    return Container(
      width: 280, // Slightly wider to accommodate time
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // DATE & TIME BADGE
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${date.day}/${date.month} @ ${date.hour}:${date.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(color: Colors.indigo, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              // ACTION MENU (Only if permitted)
              if (canManage)
                PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'edit' && isCreator) _showEditEventSheet(eventDoc);
                    if (value == 'delete') _confirmDeleteEvent(clubId, eventDoc.id);
                  },
                  itemBuilder: (context) => [
                    if (isCreator) // Only creator can edit
                      const PopupMenuItem(value: 'edit', child: ListTile(leading: Icon(Icons.edit, size: 20), title: Text("Edit"), contentPadding: EdgeInsets.zero)),
                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red, size: 20), title: Text("Delete", style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(event['title'] ?? "Untitled", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 4),
          Text(event['description'] ?? "", style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Colors.blue.withValues(alpha: 0.1),
        child: const Icon(Icons.notifications_none, size: 20, color: Colors.blue),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    );
  }
  // HELPER: Stats Card
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
          ),
        ),
      ),
    );
  }

  // HELPER: Tool Card
  Widget _buildToolCard(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTab(DocumentSnapshot clubDoc, String leaderId, bool isMeOwner) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('clubId', isEqualTo: clubDoc.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading members"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final members = snapshot.data!.docs;

        return Column(
          children: [
            // 1. TOP INFO SUMMARY
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  const Icon(Icons.groups, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text(
                    "${members.length} Total Members",
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // 2. MEMBER LIST
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index].data() as Map<String, dynamic>;
                  final String memberDocId = members[index].id;
                  final bool isTargetOwner = member['userId'] == leaderId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: CircleAvatar(
                        backgroundColor: isTargetOwner ? Colors.orange.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                        child: Icon(
                          isTargetOwner ? Icons.stars : Icons.person,
                          color: isTargetOwner ? Colors.orange : Colors.blue,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        member['name'] ?? "Unknown User",
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        isTargetOwner ? "Club Administrator" : "Active Member",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTargetOwner)
                            _buildBadge("OWNER", Colors.orange)
                          else if (isMeOwner) ...[
                            // Transfer Ownership Button
                            IconButton(
                              tooltip: "Transfer Leadership",
                              icon: const Icon(Icons.swap_horiz, color: Colors.blue, size: 22),
                              onPressed: () => _confirmTransfer(
                                  member['userId'], member['name'], clubDoc.id),
                            ),
                            // Kick Member Button
                            IconButton(
                              tooltip: "Remove Member",
                              icon: const Icon(Icons.person_remove_outlined, color: Colors.redAccent, size: 22),
                              onPressed: () => _confirmRemoveMember(
                                  memberDocId, member['name']),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Ensure you have this helper method for the "OWNER" badge
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
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  // Remove Member Function
  Future<void> _confirmRemoveMember(String registrationId, String name) async {
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Member?"),
        content: Text("Are you sure you want to remove $name from the club?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('registrations')
          .doc(registrationId)
          .delete();
    }
  }

  // --- MEMBER TILE WITH OWNER BADGE & TRANSFER ---
  Widget _buildMemberTile(
      DocumentSnapshot member, String leaderId, String clubId) {
    final bool isOwner = member['userId'] == leaderId;
    final bool isMeOwner = _currentUserId == leaderId;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isOwner ? Border.all(color: Colors.orange, width: 2) : null,
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: member['photoUrl'] != ""
              ? NetworkImage(member['photoUrl'])
              : null,
          child: member['photoUrl'] == "" ? const Icon(Icons.person) : null,
        ),
        title: Row(
          children: [
            Text(member['name'],
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (isOwner) ...[
              const SizedBox(width: 8),
              _buildBadge("OWNER", Colors.orange),
            ],
          ],
        ),
        subtitle: Text(member['bio'], maxLines: 1),
        trailing: (isMeOwner && !isOwner)
            ? IconButton(
                icon: const Icon(Icons.swap_horiz, color: AppTheme.primaryBlue),
                onPressed: () =>
                    _confirmTransfer(member['userId'], member['name'], clubId),
              )
            : null,
      ),
    );
  }

  // --- OWNERSHIP TRANSFER LOGIC ---
  Future<void> _confirmTransfer(
      String newId, String newName, String clubId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Transfer Ownership?"),
        content: Text(
            "Make $newName the new owner? You will become a regular student."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _executeTransfer(newId, clubId);
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTransfer(String newId, String clubId) async {
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
    _fetchUserData(); // Refresh local UI state
  }

  Widget _buildClubHeader(String desc) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.primaryBlue, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("About",
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          Text(desc, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
    );
  } 

  Widget _buildPendingApprovalScreen(DocumentSnapshot clubDoc) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.hourglass_empty_rounded, size: 100, color: Colors.orange),
              const SizedBox(height: 24),
              Text(
                "${clubDoc['name']} is Under Review",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                "Your club registration has been submitted successfully. Please wait for an Admin to approve your request before you can manage events and chat with members.",
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
              const Icon(Icons.report_problem_rounded, size: 100, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                "Club Registration Rejected",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.red),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Reason: ${clubDoc['rejectionReason'] ?? 'No specific reason provided. Please update your details and resubmit.'}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Colors.redAccent, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () => _showEditClubSheet(context, clubDoc),
                icon: const Icon(Icons.edit_note, color: Colors.white),
                label: const Text("Edit & Resubmit", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
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
            const Text("You haven't created a club yet!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  // --- FORM SHEETS (Moved inside the State class) ---
  void _showEditClubSheet(BuildContext context, DocumentSnapshot clubDoc) {
    final TextEditingController nameController =
        TextEditingController(text: clubDoc['name']);
    final TextEditingController categoryController =
        TextEditingController(text: clubDoc['category']);
    final TextEditingController descController =
        TextEditingController(text: clubDoc['description']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the sheet to move up with the keyboard
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // Keyboard padding
          left: 20, right: 20, top: 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Edit Club Details",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
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
                  labelText: "Club Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Description",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 25),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      // 2. Update Firestore and RESET status to pending
                      await FirebaseFirestore.instance
                          .collection('clubs')
                          .doc(clubDoc.id)
                          .update({
                        'name': nameController.text.trim(),
                        'category': categoryController.text.trim(),
                        'description': descController.text.trim(),
                        'status': 'pending', // Re-triggers Admin review
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Resubmitted! Waiting for Admin review."),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            top: 20),
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
                    labelText: "Club Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: selectedCategory,
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
                    labelText: "Description", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.all(15)),
                onPressed: () async {
                  // 1. Simple Validation
                  if (nameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a club name")),
                    );
                    return;
                  }

                  // 2. Add to Firestore with 'pending' status
                  await FirebaseFirestore.instance.collection('clubs').add({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'category': selectedCategory,
                    'leaderId': _currentUserId,
                    'status': 'pending', // This ensures it doesn't show up yet
                    'createdAt': FieldValue.serverTimestamp(),
                  });

                  // 3. Close the sheet and show feedback
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Club request sent! Awaiting Admin approval."),
                        backgroundColor: Colors.orange, // Visual cue for "Pending"
                      ),
                    );
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

  void _showPostUpdateSheet(BuildContext context, String clubId) {
    final updateController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20,
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _submitUpdate(context, clubId, updateController.text),
                child: const Text("Post to Feed", style: TextStyle(color: Colors.white)),
              ),
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
    
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder( // CRITICAL: This allows the sheet to update!
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Plan New Event", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: "Event Title", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descController, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
                
                // Date & Time Row
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text("Date"),
                        subtitle: Text("${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setModalState(() => selectedDate = date);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text("Time"),
                        subtitle: Text(selectedTime.format(context)),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) setModalState(() => selectedTime = time);
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                    onPressed: () {
                      // Combine Date and Time before submitting
                      final finalDateTime = DateTime(
                        selectedDate.year, selectedDate.month, selectedDate.day,
                        selectedTime.hour, selectedTime.minute,
                      );
                      _submitEvent(context, clubId, titleController.text, descController.text, finalDateTime,);
                    },
                    child: const Text("Create Event", style: TextStyle(color: Colors.white)),
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
        content: const Text("This action cannot be undone and will notify members."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
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

  void _showEditEventSheet(DocumentSnapshot eventDoc) {
    final event = eventDoc.data() as Map<String, dynamic>;
    
    // Pre-fill controllers with existing data
    final titleController = TextEditingController(text: event['title']);
    final descController = TextEditingController(text: event['description']);
    
    DateTime selectedDate = (event['date'] as Timestamp).toDate();
    TimeOfDay selectedTime = TimeOfDay.fromDateTime(selectedDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20, right: 20, top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Edit Event", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                TextField(controller: titleController, decoration: const InputDecoration(labelText: "Event Title", border: OutlineInputBorder())),
                const SizedBox(height: 10),
                TextField(controller: descController, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder())),
                
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text("Date"),
                        subtitle: Text("${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now().subtract(const Duration(days: 30)), // Allow editing past events
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) setModalState(() => selectedDate = date);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text("Time"),
                        subtitle: Text(selectedTime.format(context)),
                        onTap: () async {
                          final time = await showTimePicker(context: context, initialTime: selectedTime);
                          if (time != null) setModalState(() => selectedTime = time);
                        },
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), // Use orange for "Edit"
                    onPressed: () {
                      final finalDateTime = DateTime(
                        selectedDate.year, selectedDate.month, selectedDate.day,
                        selectedTime.hour, selectedTime.minute,
                      );
                      _updateEvent(eventDoc.reference, titleController.text, descController.text, finalDateTime);
                    },
                    child: const Text("Save Changes", style: TextStyle(color: Colors.white)),
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

  Future<void> _updateEvent(DocumentReference ref, String title, String desc, DateTime date) async {
    try {
      await ref.update({
        'title': title.trim(),
        'description': desc.trim(),
        'date': Timestamp.fromDate(date),
        'lastEditedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Close the sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event updated!"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  Future<void> _submitUpdate(BuildContext context, String clubId, String content) async {
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
          const SnackBar(content: Text("Announcement posted!"), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    }
  }

  Future<void> _submitEvent(BuildContext context, String clubId, String title, String desc, DateTime date) async {
    if (title.trim().isEmpty || desc.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    try {
      // Check console for this log
      debugPrint("Attempting to upload to Firestore...");

      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('events') // Ensure this sub-collection exists or can be created
          .add({
        'title': title.trim(),
        'description': desc.trim(),
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': _currentUserId,
      });

      if (context.mounted) {
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event Created!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // THIS WILL TELL YOU THE REAL ERROR
      debugPrint("Firebase Error: $e"); 
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }
}
