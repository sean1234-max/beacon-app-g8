// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:assignment/models/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // needed for _loadPoster + _loadExistingTicket
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/event_model.dart';
import '../services/database_service.dart';
import 'payment_screen.dart';

class EventDetailsScreen extends StatefulWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  static const _primary = Color(0xFF003366);

  bool _isRegistering = false;
  final String? userId = FirebaseAuth.instance.currentUser?.uid;
  String? _ticketId;
  String? _posterBase64;
  bool _posterLoading = true;

  @override
  void initState() {
    super.initState();
    _loadExistingTicket();
    _loadPoster();
  }

  Future<void> _loadExistingTicket() async {
    if (userId == null) return;
    if (!widget.event.participants.contains(userId)) return;
    final id = await DatabaseService().findTicketId(widget.event.id, userId!);
    if (mounted && id != null) setState(() => _ticketId = id);
  }

  Future<void> _loadPoster() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('media')
          .doc('poster')
          .get();
      if (mounted && doc.exists) {
        setState(() => _posterBase64 = doc.data()?['base64'] as String?);
      }
    } catch (_) {
      // No poster — use placeholder
    } finally {
      if (mounted) setState(() => _posterLoading = false);
    }
  }

  // ─────────────────────────────────────────────
  //  REGISTRATION
  // ─────────────────────────────────────────────

  Future<void> _handleRegistration() async {
    if (userId == null) return;

    // Paid event → go to payment screen first
    if (widget.event.isPaid) {
      final registered = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentScreen(event: widget.event, userId: userId!),
        ),
      );
      if (registered == true && mounted) {
        setState(() => widget.event.participants.add(userId!));
        _loadExistingTicket();
      }
      return;
    }

    // Free event → register directly
    setState(() => _isRegistering = true);
    try {
      final newTicketId = await DatabaseService()
          .joinEvent(widget.event.id, userId!, eventTitle: widget.event.title);
      _ticketId = newTicketId;

      try {
        await NotificationService.sendNotification(
          userId: userId!,
          title: "Event Registered! 🎟️",
          message:
              "You have successfully registered for ${widget.event.title}. Your QR pass is now active!",
          type: "event",
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isRegistering = false;
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _handleUnregister() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Leave Event?"),
            content: const Text(
                "Are you sure you want to unregister? You will need to register again if you change your mind."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child:
                      const Text("Leave", style: TextStyle(color: Colors.red))),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;
    setState(() => _isRegistering = true);

    try {
      // 1. Process unregistration across all Firestore targets
      await DatabaseService().leaveEvent(widget.event.id, userId!);
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': "Left Event Confirmation",
        'body': "You have successfully unregistered from '${widget.event.title}'.",
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'type': 'event_unregistration',
        'eventId': widget.event.id,
      });

      if (mounted) {
        // 3. Show brief confirmation snackbar
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You have left the event.")));
        
        // 4. Navigate back to the Event Dashboard screen
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Unregister Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to leave event: $e")));
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final bool isExpired = event.dateTime.isBefore(DateTime.now());
    final bool isRegistered = event.participants.contains(userId);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Event Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Poster with bottom shadow
                _buildPosterSection(),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      _buildStatusBadge(isExpired, isRegistered),
                      const SizedBox(height: 12),

                      // Title
                      Text(
                        event.title,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A2E),
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date & Time — full width card
                      _buildInfoCard(
                        icon: Icons.calendar_today_outlined,
                        iconColor: const Color(0xFF6C63FF),
                        iconBg: const Color(0xFFEEEBFF),
                        label: 'Date & Time',
                        value: DateFormat('EEEE, d MMMM yyyy')
                            .format(event.dateTime),
                        subValue: DateFormat('hh:mm a').format(event.dateTime),
                        fullWidth: true,
                      ),
                      const SizedBox(height: 12),

                      // Location + Fee — side by side
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.location_on_outlined,
                                iconColor: Colors.orange,
                                iconBg: const Color(0xFFFFF0DC),
                                label: 'Location',
                                value: event.location,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.payments_outlined,
                                iconColor: Colors.teal,
                                iconBg: const Color(0xFFE0F7F4),
                                label: 'Event Fee',
                                value: event.isPaid
                                    ? 'RM ${event.eventFee.toStringAsFixed(event.eventFee.truncateToDouble() == event.eventFee ? 0 : 2)}'
                                    : 'Free',
                                valueColor: event.isPaid
                                    ? const Color(0xFF003366)
                                    : Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Deadline + Contact — side by side
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.event_busy_outlined,
                                iconColor: Colors.red,
                                iconBg: const Color(0xFFFFEBEB),
                                label: 'Deadline',
                                value: event.registrationDeadline != null
                                    ? DateFormat('MMM d, yyyy')
                                        .format(event.registrationDeadline!)
                                    : 'N/A',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildInfoCard(
                                icon: Icons.person_outline,
                                iconColor: const Color(0xFF6C63FF),
                                iconBg: const Color(0xFFEEEBFF),
                                label: 'Contact',
                                value: event.picName.isNotEmpty
                                    ? event.picName
                                    : 'N/A',
                                subValue: event.picPhone.isNotEmpty
                                    ? '(${event.picPhone})'
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // About Event
                      _buildAboutSection(event),
                      const SizedBox(height: 20),

                      // Payment details (if paid)
                      if (event.isPaid) _buildPaymentDetails(event),

                      // QR code (if registered)
                      if (isRegistered) ...[
                        const SizedBox(height: 20),
                        _buildQrSection(),
                        const SizedBox(height: 16),
                        _buildLeaveButton(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sticky Register button at bottom
          if (!isRegistered)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildRegisterButton(isExpired),
            ),
        ],
      ),
    );
  }

  //  POSTER SECTION (with bottom shadow)
  Widget _buildPosterSection() {
    return GestureDetector(
      onTap: _posterBase64 != null ? _showFullScreenPoster : null,
      child: SizedBox(
        height: 280,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Poster image or placeholder
            _buildPosterHero(),

            // Bottom gradient shadow
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Color(0xFFF5F6FA), Colors.transparent],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenPoster() {
    if (_posterBase64 == null) return;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: GestureDetector(
            onTap: () => Navigator.pop(ctx),
            child: Center(
              child: Hero(
                tag: 'event_poster_${widget.event.id}',
                child: InteractiveViewer(
                  child: Image.memory(
                    base64Decode(_posterBase64!),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterHero() {
    if (_posterLoading) {
      return Container(
        color: _primary,
        child: const Center(
            child: CircularProgressIndicator(color: Colors.white54)),
      );
    }
    if (_posterBase64 != null) {
      try {
        return Hero(
          tag: 'event_poster_${widget.event.id}',
          child: Image.memory(
            base64Decode(_posterBase64!),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        );
      } catch (_) {}
    }
    // Fallback gradient placeholder
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF003366), Color(0xFF6C63FF)],
        ),
      ),
      child: const Center(
        child: Icon(Icons.event_rounded, size: 80, color: Colors.white30),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  STATUS BADGE
  // ─────────────────────────────────────────────

  Widget _buildStatusBadge(bool isExpired, bool isRegistered) {
    final String label;
    final Color color;
    final Color bg;

    if (isExpired) {
      label = 'Ended';
      color = Colors.grey[700]!;
      bg = Colors.grey[200]!;
    } else if (isRegistered) {
      label = 'Registered';
      color = Colors.blue[700]!;
      bg = Colors.blue[50]!;
    } else {
      label = 'Available';
      color = Colors.green[700]!;
      bg = Colors.green[50]!;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  INFO CARD
  // ─────────────────────────────────────────────

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String label,
    required String value,
    String? subValue,
    Color? valueColor,
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: valueColor ?? const Color(0xFF1A1A2E),
                    height: 1.3,
                  ),
                ),
                if (subValue != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subValue,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  ABOUT SECTION
  // ─────────────────────────────────────────────

  Widget _buildAboutSection(Event event) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About Event',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            event.description.isNotEmpty
                ? event.description
                : 'No description provided.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  PAYMENT DETAILS
  // ─────────────────────────────────────────────

  Widget _buildPaymentDetails(Event event) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.payment_outlined,
                    color: Colors.purple, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Payment Details',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: Colors.grey[100], height: 1),
          const SizedBox(height: 12),
          _buildPaymentRow('Bank', event.bankName),
          const SizedBox(height: 8),
          _buildPaymentRow('Account Number', event.bankAccountNumber),
          const SizedBox(height: 8),
          _buildPaymentRow('Account Name', event.bankReceiverName),
        ],
      ),
    );
  }

  Widget _buildPaymentRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: Color(0xFF1A1A2E)),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  QR CODE
  // ─────────────────────────────────────────────

  Widget _buildQrSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text(
            'YOUR ENTRY PASS',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E4FF)),
            ),
            child: _ticketId == null
                ? const SizedBox(
                    width: 180,
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : QrImageView(
                    data: _ticketId!,
                    version: QrVersions.auto,
                    size: 180,
                    eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square, color: _primary),
                  ),
          ),
          const SizedBox(height: 10),
          Text(
            'Show this QR at the venue',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUTTONS
  // ─────────────────────────────────────────────

  Widget _buildRegisterButton(bool isExpired) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, -4))
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton.icon(
          onPressed: (isExpired || _isRegistering) ? null : _handleRegistration,
          icon: _isRegistering
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          label: Text(
            isExpired
                ? 'Event Ended'
                : _isRegistering
                    ? 'Registering...'
                    : 'Register Now',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: isExpired ? Colors.grey : _primary,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _isRegistering ? null : _handleUnregister,
        icon: const Icon(Icons.logout_rounded, color: Colors.red, size: 18),
        label: Text(
          _isRegistering ? 'Processing...' : 'Leave Event',
          style: const TextStyle(
              color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
