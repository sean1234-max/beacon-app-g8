// ignore_for_file: use_build_context_synchronously

import 'dart:convert';
import 'package:assignment/models/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/event_model.dart';
import '../services/database_service.dart';

class PaymentScreen extends StatefulWidget {
  final Event event;
  final String userId;

  const PaymentScreen({
    super.key,
    required this.event,
    required this.userId,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _primary = Color(0xFF003366);

  String? _paymentQrBase64;
  bool _qrLoading = true;

  String? _receiptBase64;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPaymentQr();
  }

  Future<void> _loadPaymentQr() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('media')
          .doc('paymentQr')
          .get();
      if (mounted && doc.exists) {
        setState(() => _paymentQrBase64 = doc.data()?['base64'] as String?);
      }
    } catch (_) {}
    finally {
      if (mounted) setState(() => _qrLoading = false);
    }
  }

  Future<void> _pickReceipt() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    if (bytes.lengthInBytes > 750000) {
      _showError('Receipt image is too large. Please use a lower-resolution image.');
      return;
    }
    setState(() => _receiptBase64 = base64Encode(bytes));
  }

  Future<void> _submitRegistration() async {
    if (_receiptBase64 == null) {
      _showError('Please upload your payment receipt before registering.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Save receipt to sub-collection
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id)
          .collection('receipts')
          .doc(widget.userId)
          .set({
        'base64': _receiptBase64,
        'submittedAt': FieldValue.serverTimestamp(),
        'userId': widget.userId,
        'status': 'pending_verification',
      });

      // Add user to participants
      await DatabaseService().joinEvent(
        widget.event.id,
        widget.userId,
        eventTitle: widget.event.title,
      );

      // Send notification
      try {
        await NotificationService.sendNotification(
          userId: widget.userId,
          title: "Registration Submitted! 🎟️",
          message:
              "Your payment receipt for ${widget.event.title} has been submitted. "
              "Your QR pass will be active after verification.",
          type: "event",
        );
      } catch (_) {}

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showError('Registration failed: $e');
      }
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(width: 8),
          Text('Error'),
        ]),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final event = widget.event;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Payment',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Event summary ──
                _buildEventSummary(event),
                const SizedBox(height: 16),

                // ── Payment details card ──
                _buildPaymentDetailsCard(event),
                const SizedBox(height: 16),

                // ── QR code ──
                _buildQrSection(),
                const SizedBox(height: 16),

                // ── Receipt upload ──
                _buildReceiptUpload(),
              ],
            ),
          ),

          // Sticky register button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildRegisterButton(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  EVENT SUMMARY
  // ─────────────────────────────────────────────

  Widget _buildEventSummary(Event event) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.event_rounded, color: _primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A1A2E)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  event.location,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0DC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'RM ${event.eventFee.toStringAsFixed(event.eventFee.truncateToDouble() == event.eventFee ? 0 : 2)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  PAYMENT DETAILS
  // ─────────────────────────────────────────────

  Widget _buildPaymentDetailsCard(Event event) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  const Text('Payment Details',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15)),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Paid',
                  style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey[100], height: 1),
          const SizedBox(height: 14),

          _buildDetailRow('Bank Name', event.bankName),
          const SizedBox(height: 10),
          _buildDetailRow('Account Number', event.bankAccountNumber),
          const SizedBox(height: 10),
          _buildDetailRow('Receiver', event.bankReceiverName),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 16),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Please attach your transfer receipt during registration.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(color: Colors.grey, fontSize: 13)),
        Flexible(
          child: Text(
            value.isNotEmpty ? value : '—',
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF1A1A2E)),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  //  PAYMENT QR
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEBFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: Color(0xFF6C63FF), size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Scan to Pay',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 16),
          if (_qrLoading)
            const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()))
          else if (_paymentQrBase64 != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                base64Decode(_paymentQrBase64!),
                height: 220,
                fit: BoxFit.contain,
              ),
            )
          else
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_2_rounded,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text('QR not available',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  RECEIPT UPLOAD
  // ─────────────────────────────────────────────

  Widget _buildReceiptUpload() {
    return Container(
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
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.upload_file_outlined,
                    color: Colors.teal, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Upload Receipt',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.grey[100], height: 1),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _pickReceipt,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _receiptBase64 != null
                      ? Colors.teal
                      : Colors.grey[300]!,
                  width: _receiptBase64 != null ? 2 : 1,
                ),
              ),
              child: _receiptBase64 != null
                  ? Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.memory(
                            base64Decode(_receiptBase64!),
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.vertical(
                                  bottom: Radius.circular(11)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.edit_outlined,
                                    color: Colors.white, size: 14),
                                SizedBox(width: 6),
                                Text('Tap to change receipt',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add_photo_alternate_outlined,
                                size: 32, color: Colors.teal),
                          ),
                          const SizedBox(height: 12),
                          const Text('Tap to upload payment receipt',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text('JPG or PNG screenshot of transfer',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ),
            ),
          ),
          if (_receiptBase64 != null)
            TextButton.icon(
              onPressed: () => setState(() => _receiptBase64 = null),
              icon:
                  const Icon(Icons.delete_outline, color: Colors.red, size: 18),
              label: const Text('Remove Receipt',
                  style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  REGISTER BUTTON
  // ─────────────────────────────────────────────

  Widget _buildRegisterButton() {
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
          onPressed: _isSubmitting ? null : _submitRegistration,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_circle_outline, color: Colors.white),
          label: Text(
            _isSubmitting ? 'Submitting...' : 'Register & Submit Receipt',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _receiptBase64 != null ? _primary : Colors.grey,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}
