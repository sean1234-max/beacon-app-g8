import 'package:flutter/material.dart';
import '../models/event_model.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;
  final String userRole; // Pass the current user's role here
  final VoidCallback? onDelete; // Callback for delete action
  final VoidCallback? onEdit;   // Callback for edit action

  const EventCard({
    super.key,
    required this.event,
    required this.onTap,
    required this.userRole,
    this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    // PERMISSION CHECK:
    // 1. Admin can modify everything.
    // 2. Club Leader can modify ONLY if they are the creatorId.
    bool canManage = (userRole == 'admin') || 
                     (userRole == 'leader' && event.creatorId == currentUserId);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                // Event Image Placeholder
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blueGrey[100],
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: const Icon(Icons.event, size: 50, color: Colors.blue),
                ),
                
                // Show Management Options only if permitted
                if (canManage)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.black87),
                      tooltip: "Manage Event",
                      onSelected: (value) {
                        switch (value) {
                          case 'participants':
                            _showParticipantsDialog(context, event.participants);
                            break;
                          case 'edit':
                            if (onEdit != null) onEdit!();
                            break;
                          case 'delete':
                            if (onDelete != null) onDelete!();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        // Option 1: View Participants (Shows count)
                        PopupMenuItem(
                          value: 'participants',
                          child: ListTile(
                            leading: const Icon(Icons.people_outline, size: 20),
                            title: Text('Participants (${event.participants.length})'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        const PopupMenuDivider(), // Visual separator
                        // Option 2: Edit
                        const PopupMenuItem(
                          value: 'edit',
                          child: ListTile(
                            leading: Icon(Icons.edit, size: 20),
                            title: Text('Edit Details'),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        // Option 3: Delete
                        const PopupMenuItem(
                          value: 'delete',
                          child: ListTile(
                            leading: Icon(Icons.delete, color: Colors.red, size: 20),
                            title: Text('Delete Event', style: TextStyle(color: Colors.red)),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(DateFormat('dd MMM yyyy, hh:mm a').format(event.dateTime)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(event.location),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showParticipantsDialog(BuildContext context, List<String> participants) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Event Participants"),
        content: participants.isEmpty
            ? const Text("No students have joined this event yet.")
            : Text("There are ${participants.length} students registered for this event."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}