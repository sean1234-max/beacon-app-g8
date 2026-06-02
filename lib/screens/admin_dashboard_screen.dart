// ignore_for_file: use_build_context_synchronously, non_constant_identifier_names, deprecated_member_use

import 'package:assignment/models/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import '../theme/app_theme.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  int _selectedIndex = 0;
  bool _isDashboardMounted = true;
  String _userSearchQuery = "";
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _isDashboardMounted = true;
  }

  @override
  void dispose() {
    _isDashboardMounted = false; 
    super.dispose();
  }
  // Top banner + bottom navigation bar
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Beacon Admin",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
        actions: [
          IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              tooltip: "Logout",
              onPressed: () async {
                // 1. Immediately drop the dashboard ticker loop switch
                _isDashboardMounted = false; 

                // 2. Kill the stack and route cleanly back to a brand new LoginScreen instance
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                }

                // 3. Clean up the server authentication session safely in the background
                await FirebaseAuth.instance.signOut();
              },
            ),
          const SizedBox(width: 12),
        ],
      ),
      
      body: SafeArea(
        child: Container(
          color: Colors.grey[50],
          child: _getSelectedPage(),
        ),
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed, // Keeps labels visible for all 5 items
          selectedItemColor: AppTheme.primaryBlue,
          unselectedItemColor: Colors.grey[600],
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics_outlined),
              activeIcon: Icon(Icons.analytics),
              label: 'Overview',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.fact_check_outlined),
              activeIcon: Icon(Icons.fact_check),
              label: 'Approvals',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: 'Events',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.manage_accounts_outlined),
              activeIcon: Icon(Icons.manage_accounts),
              label: 'Roles',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history),
              label: 'Logs',
            ),
          ],
        ),
      ),
    );
  }

  //Help user navigate to different pages based on the selected index of the bottom navigation bar
  Widget _getSelectedPage() {
    switch (_selectedIndex) {
      case 0:
        return _buildOverviewStats();
      case 1:
        return _buildClubApprovals();
      case 2:
        return _buildEventManagement();
      case 3:
        return _buildUserManagement();
      case 4:
        return _buildLogsView(); 
      default:
        return _buildOverviewStats();
    }
  }

  // Activity logs interface
  Widget _buildLogsView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page Title & Header
          const Text("System Activity Logs",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
            "Immutable audit trail of administrative activities, access changes, and system modifications.",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('system_logs')
                    .orderBy('timestamp', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                        child: Text("Error loading logs: ${snapshot.error}"));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                        child: Text("No activity logs recorded yet."));
                  }

                  final logs = snapshot.data!.docs;

                  return Column(
                    children: [
                      // TABLE HEADERS
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          border: Border(
                              bottom: BorderSide(color: Colors.grey[200]!)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                                flex: 3,
                                child:
                                    Text("ACTION", style: _tableHeaderStyle())),
                            Expanded(
                                flex: 4,
                                child: Text("OPERATOR (ADMIN)",
                                    style: _tableHeaderStyle())),
                            Expanded(
                                flex: 3,
                                child: Text("TARGET OBJECT ID",
                                    style: _tableHeaderStyle())),
                            Expanded(
                                flex: 2,
                                child: Align(
                                    alignment: Alignment.centerRight,
                                    child: Text("TIMESTAMP",
                                        style: _tableHeaderStyle()))),
                          ],
                        ),
                      ),

                      // TABLE BODY ROWS
                      Expanded(
                        child: ListView.separated(
                          itemCount: logs.length,
                          separatorBuilder: (context, index) =>
                              Divider(height: 1, color: Colors.grey[100]),
                          itemBuilder: (context, index) {
                            final data =
                                logs[index].data() as Map<String, dynamic>;

                            // Parse Timestamp Safely
                            final dynamic timestamp = data['timestamp'];
                            DateTime? date = timestamp is Timestamp
                                ? timestamp.toDate()
                                : null;
                            String formattedTime = date != null
                                ? "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}"
                                : "Syncing...";

                            final String action =
                                data['action'] ?? "UNKNOWN_ACTION";
                            final String adminEmail = data['adminEmail'] ??
                                data['performedBy'] ??
                                "System";
                            final String targetId = data['targetId'] ?? "N/A";

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 16),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  // COLUMN 1: Action Badge
                                  Expanded(
                                    flex: 3,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: _buildActionBadge(action),
                                    ),
                                  ),
                                  // COLUMN 2: Admin Identifier
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      adminEmail,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // COLUMN 3: Target Resource Referenced ID
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      targetId.length > 12
                                          ? "${targetId.substring(0, 12)}..."
                                          : targetId,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontFamily: 'Courier',
                                          color: Colors.grey[
                                              700]), 
                                    ),
                                  ),
                                  // COLUMN 4: Timestamp
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: Text(
                                        formattedTime,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.w400),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  //Grey color header of activity logs table
  TextStyle _tableHeaderStyle() {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Colors.grey[600],
      letterSpacing: 1.0,
    );
  }

  Widget _buildActionBadge(String action) {
    Color backgroundColor;
    Color textColor;

    if (action.contains('APPROVE') || action.contains('CREATE')) {
      backgroundColor = Colors.green[50]!;
      textColor = Colors.green[700]!;
    } else if (action.contains('BAN') ||
        action.contains('DELETE') ||
        action.contains('REJECT')) {
      backgroundColor = Colors.red[50]!;
      textColor = Colors.red[700]!;
    } else if (action.contains('UPDATE') || action.contains('UNBAN')) {
      backgroundColor = Colors.blue[50]!;
      textColor = Colors.blue[700]!;
    } else {
      backgroundColor = Colors.grey[100]!;
      textColor = Colors.grey[700]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        action.replaceAll(
            '_', ' '), 
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  //Admin dashboard overview interface code
  Widget _buildOverviewStats() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 16, // Horizontal gap
            runSpacing: 12, // Vertical gap when wrapped down
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "System Insights",
                    style: TextStyle(
                      fontSize: 26, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Monitor Beacon performance and user activity",
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min, 
                  children: [
                    const Icon(Icons.refresh, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      "Last updated: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          StreamBuilder(
            stream: FirebaseFirestore.instance.collection('clubs').snapshots(),
            builder: (context, clubSnapshot) {
              return StreamBuilder(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  if (!clubSnapshot.hasData || !userSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  int totalUsers = userSnapshot.data?.docs.length ?? 0;
                  int pendingClubs = clubSnapshot.data!.docs
                      .where((d) => d['status'] == 'pending')
                      .length;
                  int approvedClubs = clubSnapshot.data!.docs
                      .where((d) => d['status'] == 'approved')
                      .length;

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = constraints.maxWidth > 1200 ? 4 : (constraints.maxWidth > 800 ? 2 : 1);
                      return GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 24,
                        mainAxisSpacing: 24,
                        childAspectRatio: 1.8,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildAnalyticsCard(
                              "Total Students",
                              totalUsers.toString(),
                              Icons.group,
                              AppTheme.primaryBlue),
                          _buildAnalyticsCard(
                              "Approved Clubs",
                              approvedClubs.toString(),
                              Icons.verified_user,
                              Colors.teal),
                          _buildAnalyticsCard(
                              "Pending Review",
                              pendingClubs.toString(),
                              Icons.hourglass_empty,
                              Colors.orange),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 40),

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
          const SizedBox(height: 40),

          const Text("System Performance & Distribution", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Deep-dive historical operational metrics for campus activity planning.", style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildTrafficAnalysisCard()),
                    const SizedBox(width: 24),
                    Expanded(child: _buildSystemAuditSummaryCard()),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTrafficAnalysisCard(),
                    const SizedBox(height: 24),
                    _buildSystemAuditSummaryCard(),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 24),
          
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 1000) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: _buildRecentActivityFeed()), 
                    const SizedBox(width: 24),
                    Expanded(flex: 1, child: _buildServerHealthPanel()),  
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildRecentActivityFeed(),
                    const SizedBox(height: 24),
                    _buildServerHealthPanel(),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServerHealthPanel() {
    Stream<Map<String, dynamic>> streamInfrastructureHealth() async* {
      while (_isDashboardMounted) {
        // 🚀 SAFETY CHECK: If the user clicked logout, exit the stream immediately!
        if (FirebaseAuth.instance.currentUser == null) {
          break;
        }

        String firestoreStatus = "Connecting...";
        Color firestoreColor = Colors.orange;
        
        String storageStatus = "Calculating...";
        Color storageColor = Colors.orange;
        
        String fcmStatus = "Disconnected";
        Color fcmColor = Colors.red;

        try {
          final stopwatch = Stopwatch()..start();
          await FirebaseFirestore.instance.collection('system_logs').limit(1).get().timeout(
            const Duration(seconds: 2),
          );
          stopwatch.stop();
          
          firestoreStatus = "Operational (${stopwatch.elapsedMilliseconds}ms)";
          firestoreColor = Colors.green;
        } catch (e) {
          // If we logged out mid-request, catch it silently
          if (FirebaseAuth.instance.currentUser == null) break;
          firestoreStatus = "Latency Alert / Offline";
          firestoreColor = Colors.red;
        }

        try {
          if (FirebaseAuth.instance.currentUser == null) break;
          DocumentSnapshot storageMeta = await FirebaseFirestore.instance
              .collection('system_metrics')
              .doc('storage_summary')
              .get();

          if (storageMeta.exists && storageMeta.data() != null) {
            final data = storageMeta.data() as Map<String, dynamic>;
            double gigaBytesUsed = (data['bytesUsed'] ?? 0) / (1024 * 1024 * 1024);
            double maxQuota = (data['maxQuotaGB'] ?? 50.0);
            
            storageStatus = "${gigaBytesUsed.toStringAsFixed(1)} GB / ${maxQuota.toStringAsFixed(0)} GB Used";
            storageColor = (gigaBytesUsed / maxQuota) > 0.85 ? Colors.red : Colors.green;
          } else {
            storageStatus = "0.0 GB / 50 GB Used";
            storageColor = Colors.green;
          }
        } catch (e) {
          if (FirebaseAuth.instance.currentUser == null) break;
          storageStatus = "Metrics Unavailable";
          storageColor = Colors.grey;
        }

        try {
          if (FirebaseAuth.instance.currentUser == null) break;
          String? token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            fcmStatus = "Connected (Active)";
            fcmColor = Colors.green;
          }
        } catch (e) {
          if (FirebaseAuth.instance.currentUser == null) break;
          fcmStatus = "Gateway Error";
          fcmColor = Colors.red;
        }

        if (!_isDashboardMounted || FirebaseAuth.instance.currentUser == null) break;

        yield {
          'firestoreStatus': firestoreStatus,
          'firestoreColor': firestoreColor,
          'storageStatus': storageStatus,
          'storageColor': storageColor,
          'fcmStatus': fcmStatus,
          'fcmColor': fcmColor,
        };

        await Future.delayed(const Duration(seconds: 3));
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Cloud Service Infrastructure", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          // 🚀 SWITCHED TO STREAMBUILDER: Re-renders layout components on every stream yield
          StreamBuilder<Map<String, dynamic>>(
            stream: streamInfrastructureHealth(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                if (snapshot.error.toString().contains('permission-denied') || 
                    FirebaseAuth.instance.currentUser == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Text("Error fetching logs: ${snapshot.error}");
              }

              final metrics = snapshot.data ?? {
                'firestoreStatus': 'Offline', 'firestoreColor': Colors.red,
                'storageStatus': 'Unavailable', 'storageColor': Colors.grey,
                'fcmStatus': 'Disconnected', 'fcmColor': Colors.red,
              };

              return Column(
                children: [
                  _buildStatusRow("Cloud Firestore Node", metrics['firestoreStatus'], metrics['firestoreColor']),
                  const SizedBox(height: 12),
                  _buildStatusRow("Firebase Storage Cluster", metrics['storageStatus'], metrics['storageColor']),
                  const SizedBox(height: 12),
                  _buildStatusRow("FCM Push Gateway", metrics['fcmStatus'], metrics['fcmColor']),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivityFeed() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Live Audit Feed", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 3), // Point to your System Logs index
                child: const Text("View Full Trail →", style: TextStyle(fontSize: 13)),
              )
            ],
          ),
          const Divider(),
          
          // --- LIVE FIREBASE STREAM ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('system_logs')
                .orderBy('timestamp', descending: true)
                .limit(3) // Keeps layout neat by matching your original UI scale
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text("Error fetching logs: ${snapshot.error}", style: const TextStyle(color: Colors.red)),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("No operational logs recorded yet.", style: TextStyle(color: Colors.grey)),
                );
              }

              final logs = snapshot.data!.docs;

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final logData = logs[index].data() as Map<String, dynamic>;
                  
                  // Parse fields from your Firestore snapshot schema
                  final String action = logData['action'] ?? 'Unknown Action';
                  final String email = logData['adminEmail'] ?? 'System';
                  final String target = logData['targetId'] ?? '';
                  final Timestamp? timeStamp = logData['timestamp'] as Timestamp?;
                  
                  // Format relative or localized clock string snippet
                  String timeDisplay = "Just now";
                  if (timeStamp != null) {
                    final date = timeStamp.toDate();
                    timeDisplay = "${date.hour}:${date.minute.toString().padLeft(2, '0')}";
                  }

                  // Dynamically pick look-and-feel treatments depending on the logged string value
                  IconData icon = Icons.info_outline;
                  Color color = AppTheme.primaryBlue;

                  if (action.contains("Banned") || action.contains("Reject")) {
                    icon = Icons.block;
                    color = Colors.red;
                  } else if (action.contains("Broadcast") || action.contains("Alert")) {
                    icon = Icons.campaign;
                    color = AppTheme.primaryBlue;
                  } else if (action.contains("Approve") || action.contains("Club")) {
                    icon = Icons.verified;
                    color = Colors.teal;
                  }

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      radius: 18,
                      child: Icon(icon, color: color, size: 18),
                    ),
                    title: Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("$email • Target: $target", maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: Text(timeDisplay, style: TextStyle(color: Colors.grey[400], fontSize: 11)),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String service, String status, Color statusColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(service, style: TextStyle(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500)),
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(status, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        )
      ],
    );
  }
  
  Widget _buildTrafficAnalysisCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Student Peak Activity", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6)),
                child: const Text("Live Weekly View", style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text("Total administrative & system interactions recorded per day.", style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 24),
          
          // --- LIVE TRAFFIC CALCULATOR STREAM ---
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('system_logs').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(height: 140, child: Center(child: CircularProgressIndicator()));
              }

              final logs = snapshot.data!.docs;
              
              // Array buckets for weekdays: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
              List<int> weekdayCounts = [0, 0, 0, 0, 0, 0, 0];

              for (var doc in logs) {
                final data = doc.data() as Map<String, dynamic>;
                if (data['timestamp'] != null) {
                  final DateTime logDate = (data['timestamp'] as Timestamp).toDate();
                  int dayIndex = logDate.weekday - 1; 
                  if (dayIndex >= 0 && dayIndex < 7) {
                    weekdayCounts[dayIndex]++;
                  }
                }
              }

              // Find the highest volume day to set our scale ceiling (Prevent division by zero)
              int maxActivity = weekdayCounts.reduce((curr, next) => curr > next ? curr : next);
              
              return SizedBox(
                height: 140, // Strict bounded frame for the graph area
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end, // Keeps all bar bases grounded on the same baseline
                  children: [
                    _buildDynamicBar("Mon", weekdayCounts[0], maxActivity, weekdayCounts[0] == maxActivity && weekdayCounts[0] > 0),
                    _buildDynamicBar("Tue", weekdayCounts[1], maxActivity, weekdayCounts[1] == maxActivity && weekdayCounts[1] > 0),
                    _buildDynamicBar("Wed", weekdayCounts[2], maxActivity, weekdayCounts[2] == maxActivity && weekdayCounts[2] > 0),
                    _buildDynamicBar("Thu", weekdayCounts[3], maxActivity, weekdayCounts[3] == maxActivity && weekdayCounts[3] > 0),
                    _buildDynamicBar("Fri", weekdayCounts[4], maxActivity, weekdayCounts[4] == maxActivity && weekdayCounts[4] > 0),
                    _buildDynamicBar("Sat", weekdayCounts[5], maxActivity, weekdayCounts[5] == maxActivity && weekdayCounts[5] > 0),
                    _buildDynamicBar("Sun", weekdayCounts[6], maxActivity, weekdayCounts[6] == maxActivity && weekdayCounts[6] > 0),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicBar(String label, int totalRawCount, int maxActivity, bool isPeak) {
    // 1. Define the exact maximum height the bar container can reach in pixels
    const double maxChartHeightAllowed = 85.0; 
    const double minimumBaselineHeight = 6.0;

    // 2. Compute proportional ratio directly (clean math logic)
    double calculatedBarHeight = minimumBaselineHeight;
    if (maxActivity > 0 && totalRawCount > 0) {
      calculatedBarHeight = (totalRawCount / maxActivity) * maxChartHeightAllowed;
    }

    // 3. Keep it within strict safety bounds
    if (calculatedBarHeight < minimumBaselineHeight) {
      calculatedBarHeight = minimumBaselineHeight;
    } else if (calculatedBarHeight > maxChartHeightAllowed) {
      calculatedBarHeight = maxChartHeightAllowed;
    }

    return Tooltip(
      message: "$totalRawCount Actions Logged",
      child: SizedBox(
        width: 32, // Guarantees structural room for text elements to avoid clipping
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Raw Count Label
            Text(
              totalRawCount.toString(),
              style: TextStyle(
                fontSize: 11, 
                fontWeight: FontWeight.w600, 
                color: isPeak ? const Color(0xFF0D47A1) : Colors.grey[600], // Replaced AppTheme placeholder with a safe fallback blue color if needed
              ),
            ),
            const SizedBox(height: 6),
            
            // 2. Proportional Bar
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: 24,
              height: calculatedBarHeight, // Exact, calculated raw safe pixel height
              decoration: BoxDecoration(
                color: isPeak ? const Color(0xFF0D47A1) : Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            
            const SizedBox(height: 8),
            // 3. Day Label
            Text(
              label, 
              style: TextStyle(
                fontSize: 11, 
                color: isPeak ? const Color(0xFF0D47A1) : Colors.grey[600], 
                fontWeight: isPeak ? FontWeight.bold : FontWeight.normal
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemAuditSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Administrative Action Distribution", 
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Real-time breakdown of core system roles and mass broadcast counts.", 
            style: TextStyle(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 24),
          
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const SizedBox(
                  height: 120, 
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final userDocs = userSnapshot.data!.docs;

              // Compute precise role aggregates from user dataset
              int studentCount = 0;
              int clubLeaderCount = 0;
              int adminCount = 0;

              for (var doc in userDocs) {
                final data = doc.data() as Map<String, dynamic>? ?? {};
                String role = data['role'] ?? 'student';
                
                if (role == 'admin') {
                  adminCount++;
                } else if (role == 'club_leader') {
                  clubLeaderCount++;
                } else {
                  studentCount++; // Defaults unassigned profiles gracefully to standard student base
                }
              }

              // 🚀 STREAM 2: Nest a FutureBuilder to read the mass broadcasts counts seamlessly
              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('announcements').get(), // Change collection name if yours is different (e.g. 'broadcasts')
                builder: (context, broadcastSnapshot) {
                  // Display structural container block while fetching asynchronous metrics
                  if (!broadcastSnapshot.hasData) {
                    return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
                  }

                  int broadcastCount = broadcastSnapshot.data!.docs.length;
                  
                  // Calculate the combined global metric pool size
                  int totalVolume = studentCount + clubLeaderCount + adminCount + broadcastCount;

                  if (totalVolume == 0) {
                    return const Text(
                      "No system records found to compute metrics.", 
                      style: TextStyle(color: Colors.grey),
                    );
                  }

                  final List<Map<String, dynamic>> metricItems = [
                    {
                      'label': 'Student Accounts',
                      'count': studentCount,
                      'color': const Color(0xFF0D47A1), // Royal Blue
                    },
                    {
                      'label': 'Club Leader Accounts',
                      'count': clubLeaderCount,
                      'color': Colors.teal,
                    },
                    {
                      'label': 'Admin Accounts',
                      'count': adminCount,          // 🚀 FIXED: Now passing the correct int counter variable
                      'color': Colors.red.shade600, // 🚀 FIXED: Now properly assigned to the color key
                    },
                    {
                      'label': 'Mass Broadcasts Sent',
                      'count': broadcastCount,
                      'color': Colors.orange.shade700,
                    },
                  ];

                  return Column(
                    children: [
                      ...metricItems.map((item) {
                        int count = item['count'];
                        double percentageFactor = totalVolume > 0 ? (count / totalVolume) : 0.0;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16.0),
                          child: _buildMetricDistributionRow(
                            item['label'],
                            "$count (${(percentageFactor * 100).toStringAsFixed(0)}%)",
                            item['color'],
                            percentageFactor,
                          ),
                        );
                      }),
                      
                      const SizedBox(height: 12),
                      Divider(color: Colors.grey[100]),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Tracked Entities", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                          Text("$totalVolume items", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricDistributionRow(String title, String trailingValue, Color color, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
            Text(trailingValue, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[100],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsCard(
      String title, String value, IconData icon, Color color) {
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
                            Icon(Icons.shield_outlined,
                                size: 18, color: Colors.green),
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
                            Icon(Icons.file_download_outlined,
                                size: 18, color: Colors.teal),
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
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
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
        setState(() => _selectedIndex = 3); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Displaying latest system audit logs!")),
        );
        break;

      case 'refresh':
        setState(() {});
        break;
    }
  }

  Widget _buildQuickActionRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🚀 MOBILE HINT: Only shows on narrow viewports to guide the user
        LayoutBuilder(
          builder: (context, constraints) {
            // If the parent width is typical for mobile (e.g., less than 600px)
            if (MediaQuery.of(context).size.width < 600) {
              return const Padding(
                padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
                child: Row(
                  children: [
                    Icon(Icons.swipe_left_alt_rounded, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Text(
                      "Scroll left or right to see all tools",
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              );
            }
            return const SizedBox.shrink(); // Hide completely on Web/Desktop
          },
        ),
        
        // The horizontal scrolling row of action items
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _actionButton(
                "Export User List",
                Icons.download,
                AppTheme.primaryBlue,
                onTap: () => _exportData('users'),
              ),
              const SizedBox(width: 12),
              _actionButton(
                "System Logs",
                Icons.terminal,
                AppTheme.primaryBlue,
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
                onTap: _showBroadcastDialog,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String title, IconData icon, Color color,
      {required VoidCallback onTap}) {
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
            Text(title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
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
        if (snapshot.hasError) {
          return const Center(child: Text("Error loading requests"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
              child: Text("No pending club approvals. All caught up!"));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final club = docs[index];
            return Card(
              elevation: 2,
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(
                    16.0), // Adds uniform padding inside the card
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. LEADING ICON
                    const CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blueAccent,
                      child:
                          Icon(Icons.group_add, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 16),

                    // 2. TEXT INFO (Expanded so it pushes the buttons to the far right)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            club['name'] ?? "Unknown Club",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Category: ${club['category']}\nLeader: ${club['leaderId'].toString().substring(0, 8)}...",
                            style:
                                TextStyle(color: Colors.grey[700], height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),

                    // 3. VERTICAL BUTTONS SIDE
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // APPROVE BUTTON
                        ElevatedButton(
                          onPressed: () => _handleApproval(
                            club.id,
                            'approved',
                            club['name'] ?? 'Unknown Club',
                            club['leaderId'] ?? '',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(100,
                                36), // Forces both buttons to be equal width
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Approve",
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),

                        const SizedBox(
                            height: 8), // Clean spacing between stacked buttons

                        // REJECT BUTTON (Matches Approve style but in Red)
                        ElevatedButton(
                          onPressed: () => _showRejectDialog(
                              context,
                              club.id,
                              club['name'] ?? 'Unknown Club',
                              club['leaderId'] ?? ''),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.red, // Solid red background banner
                            foregroundColor:
                                Colors.white, // Pure white text words
                            minimumSize: const Size(100,
                                36), // Matches Approve button size perfectly
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text("Reject",
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                      ],
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
        'adminEmail':
            FirebaseAuth.instance.currentUser?.email ?? 'Unknown Admin',
        'action': action,
        'targetId': targetId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to create log: $e");
    }
  }

  Future<void> _exportData(String collectionName) async {
    try {
      // 1. Fetch data based on the collection passed (e.g., 'clubs' or 'users')
      final snapshot =
          await FirebaseFirestore.instance.collection(collectionName).get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No data found!")));
        return;
      }

      List<List<dynamic>> csvRows = [];

      // 2. Logic to handle different headers
      if (collectionName == 'clubs') {
        csvRows.add(
            ["Club Name", "Category", "Leader ID", "Status"]); // Club Headers
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
        csvRows.add(
            ["Display Name", "Student ID", "Email", "Role"]); // User Headers
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

        final anchor = html.AnchorElement(href: url);
        anchor.setAttribute("download", "APU_${collectionName}_${DateTime.now().day}.csv");
        anchor.click(); 
        html.Url.revokeObjectUrl(url);
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  Future<void> _handleApproval(
      String clubId, String newStatus, String clubName, String leaderId,
      {String? reason}) async {
    try {
      Map<String, dynamic> updateData = {
        'status': newStatus,
        'actionedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == 'rejected' && reason != null) {
        updateData['rejectionReason'] = reason;
      }

      // 1. Update the Club Document
      if (newStatus == 'approved') {
        // Initialize members array with the leaderId
        updateData['members'] = FieldValue.arrayUnion([leaderId]);
      }

      await FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .update(updateData);

      // 2. LOGIC FOR SUCCESSFUL APPROVAL
      if (newStatus == 'approved') {
        // Fetch leader's details from 'users' collection
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(leaderId)
            .get();

        if (!userDoc.exists) {
          throw "Leader user document not found in 'users' collection!";
        }

        final userData = userDoc.data() as Map<String, dynamic>;
        final String leaderName = userData['displayName'] ?? "Club Leader";

        // 3. CREATE THE REGISTRATION RECORD
        // CRITICAL: Ensure 'userId' matches exactly what your Member List screen queries!
        await FirebaseFirestore.instance.collection('registrations').add({
          'clubId': clubId,
          'userId': leaderId,
          'name': leaderName,
          'role': 'leader',
          'joinedAt': FieldValue.serverTimestamp(),
          'bio': userData['bio'] ?? "Club Administrator",
          'photoUrl': userData['photoUrl'] ?? "",
        });

        // 4. Update Leader's user document
        await FirebaseFirestore.instance
            .collection('users')
            .doc(leaderId)
            .update({
          'joinedClubs': FieldValue.arrayUnion([clubId])
        });

        // 5. System Update for the feed
        await FirebaseFirestore.instance
            .collection('clubs')
            .doc(clubId)
            .collection('updates')
            .add({
          'content':
              '$clubName has officially started! 🚀 Welcome our leader, $leaderName.',
          'authorName': 'System',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      // --- NOTIFICATION LOGIC ---
      await NotificationService.sendNotification(
        userId: leaderId,
        title: newStatus == 'approved'
            ? "Club Approved! 🎉"
            : "Club Application Update",
        message: newStatus == 'approved'
            ? "Congratulations! Your application for $clubName has been approved."
            : "The application for $clubName was rejected. ${reason ?? ''}",
        type: newStatus == 'approved' ? "approval" : "rejection",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Club ${newStatus == 'approved' ? 'Approved' : 'Rejected'}!"),
            backgroundColor:
                newStatus == 'approved' ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint("Approval Error: $e"); // Logs the error to your console
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Widget _buildUserManagement() {
    return Column(
      children: [
        // 1. Sleek Search Bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: "Search by Display Name or Student ID...",
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: _userSearchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      onPressed: () => setState(() => _userSearchQuery = ""))
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 14.0),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[200]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.primaryBlue, width: 1.5),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _userSearchQuery = value.toLowerCase();
              });
            },
          ),
        ),

        // 2. User Management List View
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text("Error loading users"));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final String query = _userSearchQuery.trim().toLowerCase();

              // Filter users safely based on search query criteria
              final filteredUsers = snapshot.data!.docs.where((doc) {
                try {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  if (query.isEmpty) return true;

                  final String name = (data['displayName'] ?? "").toString().toLowerCase();
                  final String tp = (data['studentId'] ?? "").toString().toLowerCase();

                  return name.contains(query) || tp.contains(query);
                } catch (e) {
                  debugPrint("Error filtering user document ${doc.id}: $e");
                  return false;
                }
              }).toList();

              if (filteredUsers.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        "No users found matching your search.",
                        style: TextStyle(color: Colors.grey, fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];
                  final data = user.data() as Map<String, dynamic>;

                  final String currentRole = data['role'] ?? 'student';
                  final String displayName = data['displayName'] ?? "Unassigned User";
                  final String studentId = data['studentId'] ?? "TPXXXXXX";
                  final String email = data['email'] ?? "No Email Registered";
                  final String? photoUrl = data['photoUrl']; 

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 0, 
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade100),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        
                        // Profile avatar placeholder or network picture loader
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: currentRole == 'admin' ? Colors.red.shade50 : Colors.blue.shade50,
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty && photoUrl.startsWith('http'))
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty || !photoUrl.startsWith('http'))
                              ? Icon(
                                  currentRole == 'admin' ? Icons.admin_panel_settings_rounded : Icons.person_rounded,
                                  color: currentRole == 'admin' ? Colors.red.shade700 : AppTheme.primaryBlue,
                                  size: 26,
                                )
                              : null,
                        ),
                        
                        title: Text(
                          displayName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        
                        // Subtitle area: Displays email and Student ID
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                email,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                studentId,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade500,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        trailing: DropdownButtonHideUnderline(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              border: Border.all(color: Colors.grey.shade200),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButton<String>(
                              value: ['student', 'club_leader', 'admin'].contains(currentRole) 
                                  ? currentRole 
                                  : 'student',
                              icon: Icon(Icons.unfold_more_rounded, size: 16, color: Colors.grey.shade600),
                              elevation: 3,
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                              // 🚀 CONDITIONAL MATRIX: Full access for Admin targets
                              items: (() {
                                if (currentRole == 'admin') {
                                  // Allows full structural assignment options for admins
                                  return <String>['student', 'club_leader', 'admin'];
                                } else if (currentRole == 'club_leader') {
                                  return <String>['club_leader', 'admin'];
                                } else {
                                  return <String>['student', 'admin'];
                                }
                              })().map((String value) {
                                String displayLabel = value.toUpperCase();
                                if (value == 'club_leader') displayLabel = 'CLUB LEADER';
                                
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(displayLabel),
                                );
                              }).toList(),
                              onChanged: (newRole) {
                                if (user.id == FirebaseAuth.instance.currentUser?.uid) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text("Action denied: You cannot revoke your own admin rights!"),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                _updateUserRole(user.id, newRole!);
                              },
                            ),
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

    String displayRole = newRole == 'club_leader' ? 'CLUB LEADER' : newRole.toUpperCase();

    _logAction("Changed role to $displayRole", userId);

    // Displays the clean role name in the snackbar notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("User role updated to ${displayRole.toLowerCase()}"),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildEventManagement() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Manage All Events",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const Text(
              "As an admin, you can remove events that violate community standards."),

          const SizedBox(height: 16),

          // --- ADDED SEARCH BAR CONTAINER ---
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value
                      .toLowerCase(); // Triggers rebuild on every keystroke
                });
              },
              decoration: InputDecoration(
                hintText: "Search events by title...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          setState(() {
                            _searchQuery = "";
                          });
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),

          const SizedBox(height: 16), // Spacing between Search Bar and List

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('events').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 1. Get raw documents from Firebase
                final allEvents = snapshot.data!.docs;

                // 2. Filter events matching the search query locally
                final filteredEvents = allEvents.where((event) {
                  final Map<String, dynamic> data =
                      event.data() as Map<String, dynamic>;
                  final String title =
                      (data['title'] ?? "").toString().toLowerCase();
                  final String description =
                      (data['description'] ?? "").toString().toLowerCase();

                  // Matches if search text is found in either title or description
                  return title.contains(_searchQuery) ||
                      description.contains(_searchQuery);
                }).toList();

                // 3. Fallback if search returns nothing
                if (filteredEvents.isEmpty) {
                  return const Center(
                    child: Text("No events found matching your search.",
                        style: TextStyle(color: Colors.grey)),
                  );
                }

                return ListView.builder(
                  itemCount: filteredEvents.length,
                  itemBuilder: (context, index) {
                    final event = filteredEvents[index];
                    final Map<String, dynamic> data =
                        event.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      elevation: 1,
                      child: ListTile(
                        leading:
                            const Icon(Icons.event_note, color: Colors.red),
                        title: Text(
                          data.containsKey('title')
                              ? data['title']
                              : "Untitled Event",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          data.containsKey('description')
                              ? data['description']
                              : "No description provided.",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () => _showEventDetails(context, data),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_sweep, color: Colors.red),
                          onPressed: () {
                            // 1. Safely extract the current title for logs and notifications
                            final String currentTitle = data['title'] ?? "Unnamed Event";

                            // 2. Call your warning-free multi-parameter dialog handler
                            _confirmDeleteEvent(event.id, currentTitle);
                          },
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEventDetails(BuildContext context, Map<String, dynamic> data) {
    // Convert Firestore Timestamp to a readable string if it's not already a string
    String formattedDateTime = "TBD";
    if (data['dateTime'] != null) {
      if (data['dateTime'] is Timestamp) {
        DateTime dt = (data['dateTime'] as Timestamp).toDate();
        formattedDateTime =
            "${dt.day}/${dt.month}/${dt.year} at ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
      } else {
        formattedDateTime = data['dateTime'].toString();
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? "Event Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow(Icons.business, "Club ID", data['clubId'] ?? "N/A"),
              _detailRow(Icons.location_on, "Location",
                  data['location'] ?? "No location"),
              _detailRow(
                  Icons.calendar_month, "Date & Time", formattedDateTime),
              _detailRow(Icons.people, "Participants",
                  "${(data['participants'] as List?)?.length ?? 0} joined"),
              const Divider(),
              const Text("Description:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(data['description'] ?? "No description available."),
              const SizedBox(height: 16),
              Text(
                  "Created: ${data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate().toString().split('.')[0] : 'Unknown'}",
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // Helper widget for the rows inside the dialog
  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text("$label: $value", style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteEvent(String eventId, String eventTitle) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: const Text(
            "Are you sure you want to permanently remove this event? This will hide it from all students."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                // 1. Fetch event data one last time before deleting
                DocumentSnapshot doc = await FirebaseFirestore.instance
                    .collection('events')
                    .doc(eventId)
                    .get();

                if (!doc.exists) return;
                Map<String, dynamic> eventData =
                    doc.data() as Map<String, dynamic>;

                String eventTitle = eventData['title'] ?? "Unnamed Event";
                String creatorId = eventData['creatorId'] ?? "";
                List<dynamic> participants = eventData['participants'] ?? [];

                // 2. DELETE THE EVENT
                await FirebaseFirestore.instance
                    .collection('events')
                    .doc(eventId)
                    .delete();

                // 3. LOG THE ACTIVITY
                await FirebaseFirestore.instance.collection('logs').add({
                  'action': 'Admin Deleted Event',
                  'details': 'Event "$eventTitle" was removed by Admin.',
                  'targetId': eventId,
                  'timestamp': FieldValue.serverTimestamp(),
                  'adminId':
                      _currentUserId, // Ensure this variable is accessible
                });

                // 4. NOTIFY THE CREATOR
                if (creatorId.isNotEmpty) {
                  await _sendNotification(
                    userId: creatorId,
                    title: "Event Removed",
                    body:
                        "Your event '$eventTitle' was removed by the Admin for violating guidelines.",
                  );
                }

                // 5. NOTIFY ALL PARTICIPANTS
                for (String uid in participants) {
                  await _sendNotification(
                    userId: uid,
                    title: "Event Cancelled",
                    body:
                        "The event '$eventTitle' you joined has been removed by the Admin.",
                  );
                }

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Event deleted, logs updated, and users notified.")),
                  );
                }
              } catch (e) {
                debugPrint("Error during cleanup: $e");
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendNotification(
      {required String userId,
      required String title,
      required String body}) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      'type': 'admin_action',
    });
  }

    void _showRejectDialog(
      BuildContext context, String clubId, String clubName, String leaderId) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        // 🚀 FIXED: Declaring it here preserves the error message across state changes!
        String? errorText; 

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Reason for Rejection"),
              content: TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: "e.g., Incomplete information...",
                  border: const OutlineInputBorder(),
                  // 🚀 This will now successfully show the red warning text below the input field!
                  errorText: errorText, 
                ),
                onChanged: (value) {
                  // Clear the red warning message immediately when the admin starts typing
                  if (value.trim().isNotEmpty && errorText != null) {
                    setDialogState(() {
                      errorText = null;
                    });
                  }
                },
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    reasonController.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final String finalReason = reasonController.text.trim();

                    // Validation Check: Blocks submission and updates error message if empty
                    if (finalReason.isEmpty) {
                      setDialogState(() {
                        errorText = "Please provide a reject reason!";
                      });
                      return; // Blocks function thread execution
                    }

                    // If text is valid, proceed safely with backend operations
                    _handleApproval(
                      clubId, 
                      'rejected', 
                      clubName, 
                      leaderId,
                      reason: finalReason,
                    );
                    
                    reasonController.dispose(); 
                    Navigator.pop(context); 
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text(
                    "Confirm Reject",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  void _showBroadcastDialog() {
    final TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Send System Broadcast"),
        content: TextField(
          controller: controller,
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                String broadcastMsg = controller.text.trim();

                try {
                  // 1. Create the Global Announcement record
                  await FirebaseFirestore.instance
                      .collection('announcements')
                      .add({
                    'message': broadcastMsg,
                    'timestamp': FieldValue.serverTimestamp(),
                    'sender': 'System Admin',
                  });

                  // 2. Prepare the Write Batch for personal notifications
                  WriteBatch batch = FirebaseFirestore.instance.batch();

                  // 3. Get all users
                  QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
                      .collection('users')
                      .get();

                  for (var userDoc in usersSnapshot.docs) {
                    // Create a reference for a new notification document for EACH user
                    DocumentReference notifRef = FirebaseFirestore.instance
                        .collection('users')
                        .doc(userDoc.id)
                        .collection('notifications')
                        .doc(); // Generates a random ID

                    batch.set(notifRef, {
                      'title': "📢 Admin Announcement",
                      'message': broadcastMsg,
                      'type': 'broadcast',
                      'isRead': false,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  }

                  // 4. Commit the batch
                  await batch.commit();

                  if (mounted) {
                    Navigator.pop(context);
                    _logAction("Sent Mass Broadcast", "Global");
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Broadcast sent to all students!")),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Error sending broadcast: $e")),
                    );
                  }
                }
              }
            },
            child:
                const Text("Send Now", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
