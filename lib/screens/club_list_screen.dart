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

        // 2. SAFETY CHECK: If the name is empty, it's a "broken" club.
        // We show the prompt to create a new one (or you can show an error message).
        if (clubName.trim().isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Found a club with no name. Please contact Admin."),
                ElevatedButton(
                    onPressed: () => _buildCreateClubPrompt(),
                    child: const Text("Create Valid Club")),
              ],
            ),
          );
        }

        // 3. If the name is valid, proceed to the chat and management interface
        return _buildClubManagementInterface(clubDoc);
      },
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

                  if (mounted) {
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
  Widget _buildClubManagementInterface(DocumentSnapshot club) {
    final String leaderId = club['leaderId'];
    final bool isMeOwner = _currentUserId == leaderId;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F7FA),
        appBar: AppBar(
          title: Text(club['name'],
              style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.primaryBlue,
          elevation: 0,
          bottom: const TabBar(
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryBlue,
            tabs: [
              Tab(icon: Icon(Icons.group), text: "Members"),
              Tab(icon: Icon(Icons.chat_bubble), text: "Club Chat"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: Member List (with Remove & Transfer)
            _buildMemberTab(club, leaderId, isMeOwner),

            // TAB 2: Real-time Chat
            _buildChatTab(club),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTab(
      DocumentSnapshot club, String leaderId, bool isMeOwner) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('registrations')
          .where('clubId', isEqualTo: club.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final members = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            final bool isTargetOwner = member['userId'] == leaderId;

            return Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(member['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Transfer Button
                    if (isMeOwner && !isTargetOwner)
                      IconButton(
                        icon: const Icon(Icons.swap_horiz, color: Colors.blue),
                        onPressed: () => _confirmTransfer(
                            member['userId'], member['name'], club.id),
                      ),
                    // REMOVE BUTTON
                    if (isMeOwner && !isTargetOwner)
                      IconButton(
                        icon: const Icon(Icons.person_remove,
                            color: Colors.redAccent),
                        onPressed: () =>
                            _confirmRemoveMember(member.id, member['name']),
                      ),
                    if (isTargetOwner) _buildBadge("OWNER", Colors.orange),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Inside your _buildChatTab
  Widget _buildChatTab(DocumentSnapshot club) {
    // Use consistent naming (no underscores for local variables)
    final msgController = TextEditingController();

    void sendMessage() async {
      final text = msgController.text.trim();
      if (text.isEmpty) return;

      await FirebaseFirestore.instance.collection('messages').add({
        'clubId': club.id, // Fixed: uses the club parameter passed to the function
        'senderId': _currentUserId,
        'senderName': _currentUserName,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
      });
      msgController.clear();
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('messages')
                .where('clubId', isEqualTo: club.id) // Fixed: clubId -> club.id
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text(
                      "Firestore Error: ${snapshot.error}",
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final messages = snapshot.data!.docs;

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final bool isMe = msg['senderId'] == _currentUserId;
                  
                  final DateTime? timestamp = msg['timestamp'] != null 
                      ? (msg['timestamp'] as Timestamp).toDate() 
                      : DateTime.now();

                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 4),
                            child: Text(
                              msg['senderName'] ?? "Member",
                              style: const TextStyle(
                                fontSize: 12, 
                                fontWeight: FontWeight.bold, 
                                color: Colors.blueGrey
                              ),
                            ),
                          ),
                        Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMe ? AppTheme.primaryBlue : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(18),
                              topRight: const Radius.circular(18),
                              bottomLeft: Radius.circular(isMe ? 18 : 0),
                              bottomRight: Radius.circular(isMe ? 0 : 18),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Text(
                            msg['text'],
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 8, left: 4, right: 4),
                          child: Text(
                            "${timestamp?.hour}:${timestamp?.minute.toString().padLeft(2, '0')}",
                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        // --- Message Input Area ---
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: msgController, // Fixed: removed underscore
                  onSubmitted: (_) => sendMessage(), // Fixed: calling local sendMessage
                  decoration: InputDecoration(
                    hintText: "Type a message...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: AppTheme.primaryBlue,
                child: IconButton(
                  icon: const Icon(Icons.send, color: Colors.white, size: 20),
                  onPressed: sendMessage, // Fixed: calling local sendMessage
                ),
              ),
            ],
          ),
        ),
      ],
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

  // --- UI HELPERS ---
  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
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
                  await FirebaseFirestore.instance.collection('clubs').add({
                    'name': nameController.text.trim(),
                    'description': descController.text.trim(),
                    'category': selectedCategory,
                    'leaderId': _currentUserId,
                    'status': 'pending',
                    'createdAt': FieldValue.serverTimestamp(),
                  });
                  Navigator.pop(context);
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

  void _showCreateEventSheet(BuildContext context, String clubId) {
    final eventNameController = TextEditingController();

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
          children: [
            const Text("Announce New Event",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
                controller: eventNameController,
                decoration: const InputDecoration(
                    labelText: "Event Name", border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.all(15)),
                onPressed: () async {
                  await FirebaseFirestore.instance.collection('events').add({
                    'title': eventNameController.text.trim(),
                    'clubId': clubId,
                    'date': DateTime.now(),
                  });
                  Navigator.pop(context);
                },
                child: const Text("Post Event",
                    style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
