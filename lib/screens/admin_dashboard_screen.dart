import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Ensure this path matches your project structure
import '../theme/app_theme.dart'; 

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  // The list of "Pages" the admin can see
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildOverviewStats(),
      _buildClubApprovals(),
      _buildUserManagement(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("APU Connect Admin"),
        backgroundColor: AppTheme.primaryBlue,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Row(
        children: [
          // sidebar for Web/Tablet layout
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            selectedIconTheme: const IconThemeData(color: AppTheme.primaryBlue),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: Text('Approvals'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.manage_accounts_outlined),
                selectedIcon: Icon(Icons.manage_accounts),
                label: Text('Users'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // Main Content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "System Insights",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
              Text(
                "Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 30),
          
          // Dynamic Stat Cards
          StreamBuilder(
            stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
            builder: (context, clubSnapshot) {
              return StreamBuilder(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  if (!clubSnapshot.hasData || !userSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  int totalUsers = userSnapshot.data?.docs.length ?? 0;
                  
                  // Accurate counting for each status
                  int pendingClubs = 0;
                  int approvedClubs = 0;

                  for (var doc in clubSnapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final status = data['status'];
                    
                    if (status == 'pending') {
                      pendingClubs++;
                    } else if (status == 'approved') {
                      approvedClubs++;
                    }
                  }

                  return GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildAnalyticsCard("Total Students", totalUsers.toString(), Icons.person_add, Colors.blue),
                      // Now strictly counts only approved clubs:
                      _buildAnalyticsCard("Approved Clubs", approvedClubs.toString(), Icons.verified, Colors.green),
                      _buildAnalyticsCard("Pending Review", pendingClubs.toString(), Icons.new_releases, Colors.orange),
                      _buildAnalyticsCard("Security Alerts", "0", Icons.shield, Colors.red),
                    ],
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 40),
          
          // Recent Activity Section
          const Text("Quick Actions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildQuickActionRow(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border(left: BorderSide(color: color, width: 5)), // Color-coded accent
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildQuickActionRow() {
    return Row(
      children: [
        _actionButton("Export User List", Icons.download, Colors.grey),
        const SizedBox(width: 12),
        _actionButton("System Logs", Icons.terminal, Colors.grey),
        const SizedBox(width: 12),
        _actionButton("BroadCast Alert", Icons.campaign, AppTheme.primaryBlue),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color) {
    return OutlinedButton.icon(
      onPressed: () {}, // Add logic later
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildClubApprovals() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Center(child: Text("Error loading requests"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No pending club approvals. All caught up!"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final club = docs[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  child: Icon(Icons.group_add, color: Colors.white),
                ),
                title: Text(
                  club['name'] ?? "Unknown Club",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Category: ${club['category']}\nLeader: ${club['leaderId'].toString().substring(0, 8)}..."),
                ),
                isThreeLine: true, // Gives more vertical space
                trailing: Column( // Using Column instead of Row to avoid horizontal overflow
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => _handleApproval(club.id, 'approved'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text("Approve", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => _showRejectDialog(context, club.id), // Change this
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                      child: const Text("Reject", style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleApproval(String clubId, String newStatus, {String? reason}) async {
    try {
      // 1. Create the update map
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'actionedAt': FieldValue.serverTimestamp(), // Better name than approvedAt if it might be a rejection
      };

      // 2. If it's a rejection, add the reason to the map
      if (newStatus == 'rejected' && reason != null) {
        updateData['rejectionReason'] = reason;
      }

      // 3. Update Firestore
      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Club ${newStatus == 'approved' ? 'Approved' : 'Rejected'}!"),
            backgroundColor: newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Widget _buildUserManagement() {
  return Column(
    children: [
      // 1. Search Bar
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          decoration: InputDecoration(
            hintText: "Search by Display Name or Student ID...",
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          onChanged: (value) {
            // Future: You can add filtering logic here later
          },
        ),
      ),
      
      // 2. User List
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return const Center(child: Text("Error loading users"));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final users = snapshot.data!.docs;
            
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final data = user.data() as Map<String, dynamic>;
                
                // Fetch fields from the NEW version schema
                final String currentRole = data['role'] ?? 'student';
                final String displayName = data['displayName'] ?? "New User";
                final String studentId = data['studentId'] ?? "TPXXXXXX";
                final String email = data['email'] ?? "No Email";

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      radius: 25,
                      backgroundColor: currentRole == 'admin' 
                          ? Colors.red[50] 
                          : AppTheme.primaryBlue.withOpacity(0.1),
                      child: Icon(
                        currentRole == 'admin' ? Icons.admin_panel_settings : Icons.person, 
                        color: currentRole == 'admin' ? Colors.red : AppTheme.primaryBlue,
                      ),
                    ),
                    title: Text(
                      displayName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            studentId,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                    trailing: DropdownButtonHideUnderline(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          // Ensure currentRole matches one of the items below exactly
                          value: ['student', 'leader', 'admin'].contains(currentRole) ? currentRole : 'student',
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          items: <String>['student', 'leader', 'admin'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (newRole) {
                            if (user.id == FirebaseAuth.instance.currentUser?.uid) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("You cannot change your own admin role!")),
                              );
                              return;
                            }
                            _updateUserRole(user.id, newRole!);
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

// Logic to change roles in Firestore
  void _updateUserRole(String userId, String newRole) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': newRole,
    });
    
    // Show a quick confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("User role updated to $newRole")),
    );
  }
  
  Widget _buildEventManagement() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final events = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: events.length,
          itemBuilder: (context, index) {
            final event = events[index];
            final data = event.data() as Map<String, dynamic>;

            return Card(
              child: ListTile(
                leading: const Icon(Icons.event, color: Colors.red),
                title: Text(data['title'] ?? "Untitled Event"),
                subtitle: Text("Club: ${data['clubName'] ?? 'General'}"),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.red),
                  onPressed: () => _confirmDelete(event.id),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRejectDialog(BuildContext context, String clubId) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Reason for Rejection"),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: "e.g., Incomplete information...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              // Now we call the updated handleApproval with the reason
              _handleApproval(clubId, 'rejected', reason: reasonController.text.trim());
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Confirm Reject", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(String eventId) async {
    // Add a confirmation dialog here for safety
    await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Event removed by Admin")),
    );
  }
}