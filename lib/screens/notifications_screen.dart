import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  // 1. We move the list up here into the State class so it can be modified.
  // In a real app, this data would eventually come from Firebase!
  List<Map<String, dynamic>> notifications = [
    {
      "title": "New Event in your Area",
      "subtitle": "The APU Tech Symposium starts in 2 hours at Level 3.",
      "time": "2h ago",
      "isRead": false,
      "icon": Icons.event_available,
      "color": Colors.blue
    },
    {
      "title": "Club Application Approved",
      "subtitle": "Congratulations! You are now a member of the APU Robotics Club.",
      "time": "5h ago",
      "isRead": false,
      "icon": Icons.check_circle,
      "color": Colors.green
    },
    {
      "title": "Assignment Deadline",
      "subtitle": "Reminder: 'Mobile App Development' assignment is due tomorrow.",
      "time": "1d ago",
      "isRead": true,
      "icon": Icons.assignment_late,
      "color": Colors.orange
    },
  ];

  // 2. The Logic: Loop through all items and set isRead to true
  void _markAllAsRead() {
    setState(() {
      for (var item in notifications) {
        item['isRead'] = true;
      }
    });
  }

  // Optional Logic: Mark a single notification as read when clicked
  void _markSingleAsRead(int index) {
    if (!notifications[index]['isRead']) {
      setState(() {
        notifications[index]['isRead'] = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
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
                  // 3. Connect the button to our logic function
                  onPressed: _markAllAsRead, 
                  child: const Text("Mark all as read"),
                )
              ],
            ),
          ),
          
          Expanded(
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = notifications[index];
                
                return Container(
                  // Unread notifications get a slight blue background
                  color: item['isRead'] 
                      ? Colors.transparent 
                      : AppTheme.primaryBlue.withValues(alpha: 0.05),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item['color'].withValues(alpha: 0.1),
                      child: Icon(item['icon'], color: item['color']),
                    ),
                    title: Text(
                      item['title'],
                      style: TextStyle(
                        // Unread text is bold, read text is normal
                        fontWeight: item['isRead'] ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['subtitle']),
                        const SizedBox(height: 4),
                        Text(item['time'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    isThreeLine: true,
                    // 4. Connect the single tap logic
                    onTap: () => _markSingleAsRead(index),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}