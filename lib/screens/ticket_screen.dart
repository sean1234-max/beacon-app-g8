import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TicketScreen extends StatelessWidget {
  final String ticketId;

  const TicketScreen({super.key, required this.ticketId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('My Ticket'),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A1628),
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('event_registrations')
            .doc(ticketId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData ||
              snapshot.data == null ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text('Ticket not found'),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final eventTitle = data['eventTitle'] ?? 'Unknown Event';
          final userName = data['userName'] ?? 'Unknown User';
          final studentId = data['studentId'] ?? 'No Student ID';
          final paymentStatus = data['paymentStatus'] ?? 'unknown';
          final isCheckedIn = data['isCheckedIn'] ?? false;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Top header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 24,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A1628),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EVENT TICKET',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            eventTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            userName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            studentId,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Divider
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(
                        height: 1,
                        color: Colors.grey.shade300,
                      ),
                    ),

                    // QR section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: Column(
                        children: [
                          QrImageView(
                            data: ticketId,
                            size: 220,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Ticket ID',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ticketId,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Bottom info
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatusCard(
                              title: 'Payment',
                              value: paymentStatus.toString().toUpperCase(),
                              color: paymentStatus == 'paid' ||
                                      paymentStatus == 'free'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusCard(
                              title: 'Attendance',
                              value: isCheckedIn ? 'CHECKED IN' : 'NOT YET',
                              color:
                                  isCheckedIn ? Colors.green : Colors.redAccent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
