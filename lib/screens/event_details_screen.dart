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

    await DatabaseService().joinEvent(widget.event.id, userId!);

    if (mounted) {
      setState(() => _isRegistering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Successfully registered! Your Entry Pass is ready.")),
      );
      // We don't Navigator.pop here anymore, so the user can see their QR code!
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: If you renamed participants in your model to attendees, change this line
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
                      isAlreadyRegistered ? "Registered" : "Available",
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: isAlreadyRegistered ? Colors.blue : Colors.green,
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
                  ] else ...[
                    // Register Button only shows if NOT registered
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isRegistering ? null : _handleRegistration,
                        child: _isRegistering 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("Register Now", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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

  Widget _buildInfoRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
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
}