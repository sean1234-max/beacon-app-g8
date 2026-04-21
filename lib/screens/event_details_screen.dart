import 'package:assignment/models/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart'; // Make sure you ran 'flutter pub add qr_flutter'
import '../models/event_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  bool _isRegistering = false;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;

  void _handleRegistration() async {
    if (userId == null) return;
    setState(() => _isRegistering = true);

    try {
      // 1. Perform the database update
      await DatabaseService().joinEvent(widget.event.id, userId!);

      // 2. TRIGGER THE NOTIFICATION
      // We use widget.event.title to personalize the message
      await NotificationService.sendNotification(
        userId: userId!,
        title: "Event Registered! 🎟️",
        message: "You have successfully registered for ${widget.event.title}. Your QR pass is now active!",
        type: "event",
      );

      if (mounted) {
        setState(() {
          _isRegistering = false;
          // Manually add the ID to the local list to trigger a UI refresh
          widget.event.participants.add(userId!); 
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Successfully registered! Check your notifications."),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRegistering = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isExpired = widget.event.dateTime.isBefore(DateTime.now());
    bool isAlreadyRegistered = widget.event.participants.contains(userId);
    
    return Scaffold(
      appBar: AppBar(title: const Text("Event Details")),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image with APU Colors
            Container(
              height: 200,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: const Icon(Icons.confirmation_number_outlined, size: 80, color: Colors.white70),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.event.title,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  
                  // Status Chip
                  Chip(
                      label: Text(
                        isExpired 
                            ? "Expired" 
                            : (isAlreadyRegistered ? "Registered" : "Available"),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: isExpired 
                          ? Colors.grey 
                          : (isAlreadyRegistered ? Colors.blue : Colors.green),
                    ),

                  const Divider(height: 40),
                  
                  // Info Rows
                  _buildInfoRow(Icons.calendar_month, "Date & Time", 
                    DateFormat('EEEE, dd MMMM yyyy – hh:mm a').format(widget.event.dateTime)),
                  const SizedBox(height: 15),
                  _buildInfoRow(Icons.location_on, "Location", widget.event.location),
                  const SizedBox(height: 15),
                  _buildInfoRow(Icons.group, "Participants", "${widget.event.participants.length} students joined"),
                  
                  const SizedBox(height: 30),
                  const Text("About Event", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    widget.event.description,
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.5),
                  ),

                  const SizedBox(height: 30),

                  // --- QR CODE SECTION ---
                  if (isAlreadyRegistered) ...[
                    const Center(
                      child: Text(
                        "YOUR ENTRY PASS",
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)
                          ],
                        ),
                        child: QrImageView(
                          data: 'EVENT:${widget.event.id}|USER:$userId',
                          version: QrVersions.auto,
                          size: 180.0,
                          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppTheme.primaryBlue),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Center(
                      child: Text("Show this QR at the venue", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    
                    // --- ADDED LEAVE EVENT BUTTON ---
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isRegistering ? null : _handleUnregister,
                        icon: const Icon(Icons.logout, color: Colors.red),
                        label: Text(
                          _isRegistering ? "Processing..." : "Leave Event",
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Register Button only shows if NOT registered
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          // Change color to grey if expired
                          backgroundColor: isExpired ? Colors.grey : AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        // Disable button if expired by setting onPressed to null
                        onPressed: (isExpired || _isRegistering) ? null : _handleRegistration,
                        child: Text(
                          isExpired ? "Event Ended" : "Register Now",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUnregister() async {
    // 1. Ask for confirmation
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Leave Event?"),
        content: const Text("Are you sure you want to unregister? You will need to register again if you change your mind."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Leave", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    // 2. Perform the update
    setState(() => _isRegistering = true);

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .update({
        'participants': FieldValue.arrayRemove([userId]),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You have left the event.")),
        );
        // Optional: Navigate back if the user shouldn't be on the detail page anymore
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Unregister Error: $e");
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(subtitle, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        )
      ],
    );
  }

  // Inside your EventDetailsScreen
  Widget _buildJoinButton(Event event, String currentUserId) {
    bool isJoined = event.participants.contains(currentUserId);

    return ElevatedButton(
      onPressed: () => _toggleJoinStatus(event.id, currentUserId, isJoined),
      style: ElevatedButton.styleFrom(
        backgroundColor: isJoined ? Colors.grey : AppTheme.primaryBlue,
        minimumSize: const Size(double.infinity, 50),
      ),
      child: Text(isJoined ? "Leave Event" : "Join Event"),
    );
  }

  void _toggleJoinStatus(String eventId, String userId, bool isJoined) async {
    final docRef = FirebaseFirestore.instance.collection('events').doc(eventId);

    if (isJoined) {
      // Remove user from list
      await docRef.update({
        'participants': FieldValue.arrayRemove([userId])
      });
    } else {
      // Add user to list
      await docRef.update({
        'participants': FieldValue.arrayUnion([userId])
      });
    }
  }
}