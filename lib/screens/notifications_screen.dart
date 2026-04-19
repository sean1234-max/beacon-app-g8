import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // Mark all notifications as read in Firestore
  Future<void> _markAllAsRead() async {
    if (currentUserId == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshots = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (snapshots.docs.isEmpty) return; // Nothing to update

      for (var doc in snapshots.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("All notifications marked as read"),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error marking notifications as read: $e");
    }
  }

  // Mark a single notification as read
  Future<void> _markSingleAsRead(String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('notifications')
        .doc(docId)
        .update({'isRead': true});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUserId)
                  .collection('notifications')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No notifications yet"));

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String docId = docs[index].id;
                    
                    return _notificationItem(docId, data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Recent Updates",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          TextButton(
            onPressed: _markAllAsRead, 
            child: const Text("Mark all as read"),
          )
        ],
      ),
    );
  }

  Widget _notificationItem(String docId, Map<String, dynamic> data) {
    bool isRead = data['isRead'] ?? false;
    // Map icons based on notification type
    IconData icon;
    Color color;
    switch (data['type']) {
      case 'approval': 
        icon = Icons.check_circle; color = Colors.green; break;
      case 'rejection': 
        icon = Icons.cancel; color = Colors.red; break;
      case 'event': 
        icon = Icons.event_available; color = Colors.blue; break;
      case 'broadcast': 
        icon = Icons.campaign; color = Colors.orange; break;
      case 'security': // Added for Password Resets
        icon = Icons.security; color = Colors.blueGrey; break;
      default: 
        icon = Icons.notifications; color = Colors.grey;
    }

    return Container(
      color: isRead ? Colors.transparent : AppTheme.primaryBlue.withValues(alpha: 0.05),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(
          data['title'] ?? 'Notification',
          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
        ),
        subtitle: Text(data['message'] ?? ''),
        onTap: () => _markSingleAsRead(docId),
      ),
    );
  }
}