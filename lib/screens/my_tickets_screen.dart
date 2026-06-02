import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../theme/app_theme.dart';
import 'ticket_screen.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String? userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F8),
      appBar: AppBar(
        title: const Text('My Tickets'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: userId == null
          // ── Not logged in ──
          ? const Center(child: Text('Please log in to view your tickets.'))
          // ── Logged in: stream tickets from Firestore ──
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('event_registrations')
                  .where('userId', isEqualTo: userId)
                  .snapshots(),
              builder: (context, snapshot) {
                // Loading
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Error
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Something went wrong: ${snapshot.error}'),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                // Empty state
                if (docs.isEmpty) {
                  return _EmptyState();
                }

                // List of tickets
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String ticketId = docs[index].id;
                    return _TicketCard(
                      ticketId: ticketId,
                      data: data,
                    );
                  },
                );
              },
            ),
    );
  }
}

// TICKET CARD — one card per registered event
class _TicketCard extends StatelessWidget {
  final String ticketId;
  final Map<String, dynamic> data;

  const _TicketCard({required this.ticketId, required this.data});

  @override
  Widget build(BuildContext context) {
    final String eventTitle = data['eventTitle'] ?? 'Event';
    final String paymentStatus = data['paymentStatus'] ?? 'free';
    final bool isCheckedIn = data['isCheckedIn'] ?? false;
    final Timestamp? registeredAt = data['registeredAt'];

    // Payment badge color
    final Color payColor = (paymentStatus == 'paid' || paymentStatus == 'free')
        ? Colors.green
        : Colors.orange;

    // Attendance badge color
    final Color attendColor = isCheckedIn ? Colors.blue : Colors.grey;

    return GestureDetector(
      onTap: () {
        // Open the full ticket with QR code
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketScreen(ticketId: ticketId),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            //Top colour strip with event name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.event_rounded,
                      color: Colors.white70, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      eventTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Arrow hint
                  const Icon(Icons.arrow_forward_ios_rounded,
                      color: Colors.white54, size: 14),
                ],
              ),
            ),

            //Bottom: status badges + registered date
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Payment badge
                  _Badge(
                    label: paymentStatus.toUpperCase(),
                    color: payColor,
                    icon: Icons.payment_rounded,
                  ),
                  const SizedBox(width: 8),
                  // Attendance badge
                  _Badge(
                    label: isCheckedIn ? 'CHECKED IN' : 'NOT YET',
                    color: attendColor,
                    icon: isCheckedIn
                        ? Icons.how_to_reg_rounded
                        : Icons.pending_rounded,
                  ),
                  const Spacer(),
                  // Registered date (right side)
                  if (registeredAt != null)
                    Text(
                      _formatDate(registeredAt.toDate()),
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                ],
              ),
            ),

            // ── Tap hint ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_rounded,
                      size: 14, color: AppTheme.primaryBlue),
                  SizedBox(width: 6),
                  Text(
                    'Tap to view QR code',
                    style: TextStyle(
                      color: AppTheme.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}

// BADGE — small coloured pill label
class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _Badge({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// EMPTY STATE — shown when student has no tickets yet
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.confirmation_num_outlined,
                size: 56,
                color: AppTheme.primaryBlue,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Tickets Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register for an event to get your ticket and QR code.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
