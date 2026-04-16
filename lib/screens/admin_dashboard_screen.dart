import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import '../theme/app_theme.dart'; 

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  
  // 1. Add the search query variable here so it persists
  String _userSearchQuery = ""; 


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
              // ADD THIS 4th ITEM HERE
              NavigationRailDestination(
                icon: Icon(Icons.history_outlined),
                selectedIcon: Icon(Icons.history),
                label: Text('Logs'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          
          // 3. Main Content: We call the functions directly here
          Expanded(
            child: _getSelectedPage(),
          ),
        ],
      ),
    );
  }
  

  // 4. This helper function replaces your '_pages' list
  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0: return _buildOverviewStats();
      case 1: return _buildClubApprovals();
      case 2: return _buildUserManagement();
      case 3: return _buildLogsView(); // Add a new case for Logs
      default: return _buildOverviewStats();
    }
  }

  Widget _buildLogsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("System Activity Logs", 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            // Use a specific limit to prevent loading thousands of logs at once
            stream: FirebaseFirestore.instance
                .collection('system_logs')
                .orderBy('timestamp', descending: true)
                .limit(100) 
                .snapshots(),
            builder: (context, snapshot) {
              // 1. Handle Error state
              if (snapshot.hasError) {
                return Center(child: Text("Error: ${snapshot.error}"));
              }

              // 2. Handle Loading state (only if there is no data at all)
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // 3. Handle Empty state
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text("No activity logs found."));
              }

              // 4. Data is ready
              return ListView.builder(
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final log = snapshot.data!.docs[index];
                  final data = log.data() as Map<String, dynamic>;
                  
                  // Safely handle the timestamp
                  final dynamic timestamp = data['timestamp'];
                  DateTime? date;
                  if (timestamp is Timestamp) {
                    date = timestamp.toDate();
                  }

                  return ListTile(
                    leading: const Icon(Icons.history, color: Colors.blueGrey),
                    title: Text(data['action'] ?? "Unknown Action"),
                    subtitle: Text("Admin: ${data['adminEmail']}\nTarget: ${data['targetId']}"),
                    isThreeLine: true,
                    trailing: Text(
                      date != null 
                        ? "${date.day}/${date.month} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}" 
                        : "Syncing...",
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
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

  Widget _buildOverviewStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "System Insights",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1),
                  ),
                  Text(
                    "Monitor APU Connect performance and user activity",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.refresh, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      "Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),

          // Statistics Grid
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
                  int pendingClubs = clubSnapshot.data!.docs.where((d) => d['status'] == 'pending').length;
                  int approvedClubs = clubSnapshot.data!.docs.where((d) => d['status'] == 'approved').length;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Adjust column count based on screen width
                      int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 2 : 1);
                      return GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.8,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildAnalyticsCard("Total Students", totalUsers.toString(), Icons.group, AppTheme.primaryBlue),
                          _buildAnalyticsCard("Approved Clubs", approvedClubs.toString(), Icons.verified_user, Colors.teal),
                          _buildAnalyticsCard("Pending Review", pendingClubs.toString(), Icons.hourglass_empty, Colors.orange),
                          _buildAnalyticsCard("Security Health", "Stable", Icons.gpp_good, Colors.green),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),

          const SizedBox(height: 50),

          // Quick Actions with improved container
          const Text("Administrative Tools", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _buildQuickActionRow(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              
              // --- THE THREE DOTS LOGIC ---
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
                onSelected: (String choice) => _handleCardAction(choice, title),
                itemBuilder: (BuildContext context) {
                  return [
                    // OPTION 1: Dynamic Primary Action
                    if (title == "Security Health")
                      const PopupMenuItem(
                        value: 'run_audit',
                        child: Row(
                          children: [
                            Icon(Icons.shield_outlined, size: 18, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Audit System'),
                          ],
                        ),
                      )
                    else if (title == "Approved Clubs")
                      const PopupMenuItem(
                        value: 'export_list',
                        child: Row(
                          children: [
                            Icon(Icons.file_download_outlined, size: 18, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('Export List'),
                          ],
                        ),
                      )
                    else
                      const PopupMenuItem(
                        value: 'view_details',
                        child: Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 18),
                            SizedBox(width: 8),
                            Text('View Details'),
                          ],
                        ),
                      ),

                    // OPTION 2: Standard Refresh
                    const PopupMenuItem(
                      value: 'refresh',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 18),
                          SizedBox(width: 8),
                          Text('Refresh Data'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              Text(
                title,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleCardAction(String choice, String cardTitle) {
    switch (choice) {
      case 'view_details':
        if (cardTitle == "Total Students") {
          setState(() => _selectedIndex = 2);
        } else if (cardTitle == "Pending Review") {
          setState(() => _selectedIndex = 1);
        }
        break;

      case 'export_list':
      if (cardTitle == "Approved Clubs") {
        _exportData('clubs'); 
      } else {
        _exportData('users'); 
      }
      break;

      case 'run_audit':
        // Specifically for Security Health
        setState(() => _selectedIndex = 3); // Jump straight to System Logs
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Opening Security Audit Logs...")),
        );
        break;

      case 'refresh':
        setState(() {}); 
        break;
    }
  }

  Widget _buildQuickActionRow() {
    return Row(
      children: [
        _actionButton(
          "Export User List", 
          Icons.download, 
          Colors.grey, 
          onTap: () => _exportData('users'), 
        ),
        const SizedBox(width: 12),
        _actionButton(
          "System Logs", 
          Icons.terminal, 
          Colors.grey, 
          onTap: () {
            setState(() {
              _selectedIndex = 3; 
            });
          },
        ),
        const SizedBox(width: 12),
        _actionButton(
          "BroadCast Alert", 
          Icons.campaign, 
          AppTheme.primaryBlue, 
          onTap: _showBroadcastDialog, // Link the function here
        ),
      ],
    );
  }

  Widget _actionButton(String title, IconData icon, Color color, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
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

  Future<void> _logAction(String action, String targetId) async {
    try {
      await FirebaseFirestore.instance.collection('system_logs').add({
        'adminEmail': FirebaseAuth.instance.currentUser?.email ?? 'Unknown Admin',
        'action': action,
        'targetId': targetId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to create log: $e");
    }
  }

  Future<void> _exportUserList() async {
    try {
      // 1. Fetch all users from Firestore
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      
      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No users found to export!")),
        );
        return;
      }

      // 2. Define the header and map the data
      List<List<dynamic>> csvRows = [];
      
      // Add Header Row
      csvRows.add(["Display Name", "Student ID", "Email", "Role"]);

      // Add User Data Rows
      for (var doc in snapshot.docs) {
        final data = doc.data();
        csvRows.add([
          data['displayName'] ?? 'N/A',
          data['studentId'] ?? 'N/A',
          data['email'] ?? 'N/A',
          data['role'] ?? 'student',
        ]);
      }

      // 3. Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvRows);

      // 4. Trigger Download (Web Logic)
      final bytes = utf8.encode(csvString);
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "APU_Connect_Users_${DateTime.now().day}_${DateTime.now().month}.csv")
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Exporting CSV...")),
      );
    } catch (e) {
      debugPrint("Export Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Export failed: $e")),
      );
    }
  }

  Future<void> _exportData(String collectionName) async {
    try {
      // 1. Fetch data based on the collection passed (e.g., 'clubs' or 'users')
      final snapshot = await FirebaseFirestore.instance.collection(collectionName).get();
      
      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data found!")));
        return;
      }

      List<List<dynamic>> csvRows = [];

      // 2. Logic to handle different headers
      if (collectionName == 'clubs') {
        csvRows.add(["Club Name", "Category", "Leader ID", "Status"]); // Club Headers
        for (var doc in snapshot.docs) {
          final data = doc.data();
          // Only export approved clubs if that's the goal
          if (data['status'] == 'approved') {
            csvRows.add([
              data['name'] ?? 'N/A',
              data['category'] ?? 'N/A',
              data['leaderId'] ?? 'N/A',
              data['status'] ?? 'N/A',
            ]);
          }
        }
      } else {
        csvRows.add(["Display Name", "Student ID", "Email", "Role"]); // User Headers
        for (var doc in snapshot.docs) {
          final data = doc.data();
          csvRows.add([
            data['displayName'] ?? 'N/A',
            data['studentId'] ?? 'N/A',
            data['email'] ?? 'N/A',
            data['role'] ?? 'student',
          ]);
        }
      }

      // 3. Convert and Download
      String csvString = const ListToCsvConverter().convert(csvRows);
      final bytes = utf8.encode(csvString);
      final blob = html.Blob([bytes], 'text/csv');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute("download", "APU_${collectionName}_${DateTime.now().day}.csv")
        ..click();
      html.Url.revokeObjectUrl(url);

    } catch (e) {
      debugPrint("Export Error: $e");
    }
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
            // Add a clear button if text is not empty
            suffixIcon: _userSearchQuery.isNotEmpty 
              ? IconButton(
                  icon: const Icon(Icons.clear), 
                  onPressed: () => setState(() => _userSearchQuery = "")) 
              : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          onChanged: (value) {
            // Update the search query state
            setState(() {
              _userSearchQuery = value.toLowerCase();
            });
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
          
          // 1. Convert the query to lowercase ONCE for efficiency
          final String query = _userSearchQuery.trim().toLowerCase();

          // Filter the users based on search query
          final filteredUsers = snapshot.data!.docs.where((doc) {
            try {
              // 1. Basic Data Check
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) return false;

              // 2. Query Preparation
              final String query = _userSearchQuery.trim().toLowerCase();
              if (query.isEmpty) return true; // Show everyone if search is empty

              // 3. Field Extraction with Fallbacks
              final String name = (data['displayName'] ?? "").toString().toLowerCase();
              final String tp = (data['studentId'] ?? "").toString().toLowerCase();
              
              // 4. Matching Logic
              final bool matches = name.contains(query) || tp.contains(query);
              
              return matches;
            } catch (e) {
              // If one specific user document is broken, skip it and print the error
              debugPrint("Error filtering user document ${doc.id}: $e");
              return false; 
            }
          }).toList();

          // 3. Handle the empty state
          if (filteredUsers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No users found matching your search.",
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          
          // 4. Return the List
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 20),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) {
              final user = filteredUsers[index];
              final data = user.data() as Map<String, dynamic>;
              
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
    _logAction("Changed role to ${newRole.toUpperCase()}", userId);
    
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

  void _showBroadcastDialog() {
    final TextEditingController _controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send System Broadcast"),
        content: TextField(
          controller: _controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Type your message here...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () async {
              if (_controller.text.isNotEmpty) {
                await FirebaseFirestore.instance.collection('announcements').add({
                  'message': _controller.text,
                  'timestamp': FieldValue.serverTimestamp(),
                  'sender': 'System Admin',
                });
                Navigator.pop(context);
                
                // Log the broadcast in our new System Logs
                _logAction("Sent Broadcast Alert", "Global");
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Broadcast sent to all students!")),
                );
              }
            },
            child: const Text("Send Now", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}