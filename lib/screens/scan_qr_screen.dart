import 'package:assignment/models/event_model.dart';
import 'package:assignment/screens/checked_in_participants_screen.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';

class ScanQrScreen extends StatefulWidget {
  final Event event;
  const ScanQrScreen({super.key, required this.event});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  // Controls the device camera
  final MobileScannerController _camera = MobileScannerController(
    detectionSpeed:
        DetectionSpeed.noDuplicates, // avoids scanning same code twice
    facing: CameraFacing.back, // use rear camera
  );

  final DatabaseService _db = DatabaseService();

  // Prevents processing multiple QR detections at the same time
  bool _isProcessing = false;

  @override
  void dispose() {
    _camera.dispose(); // always release camera when leaving screen
    super.dispose();
  }

  //Called automatically every time camera detects a QR code
  Future<void> _onDetect(BarcodeCapture capture) async {
    // If we're already handling a previous scan, ignore new ones
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? ticketId = barcodes.first.rawValue;
    if (ticketId == null || ticketId.trim().isEmpty) return;

    // Lock so we don't process another QR while this one is loading
    setState(() => _isProcessing = true);

    // Pause camera while we show the result — avoids repeated flicker
    await _camera.stop();

    await _verifyAndShowResult(ticketId.trim());
  }

  // ── Main logic: look up the ticketId in Firestore and decide what to show ──
  Future<void> _verifyAndShowResult(String ticketId) async {
    // Call the verifyEventTicket function we built in database_service.dart
    final ticketData = await _db.verifyEventTicket(ticketId);

    if (!mounted) return;

    if (ticketData == null) {
      // ticketId not found in event_registrations → invalid QR
      _showResultSheet(
        status: _ScanStatus.invalid,
        ticketId: ticketId,
        ticketData: null,
      );
      return;
    }

    final bool isCheckedIn = ticketData['isCheckedIn'] ?? false;
    final String paymentStatus = ticketData['paymentStatus'] ?? 'free';

    if (isCheckedIn) {
      // Already checked in → show warning
      _showResultSheet(
        status: _ScanStatus.alreadyCheckedIn,
        ticketId: ticketId,
        ticketData: ticketData,
      );
      return;
    }

    if (paymentStatus == 'unpaid') {
      // Registration exists but payment not done
      _showResultSheet(
        status: _ScanStatus.unpaid,
        ticketId: ticketId,
        ticketData: ticketData,
      );
      return;
    }

    // All checks passed ✅ — valid and ready to check in
    _showResultSheet(
      status: _ScanStatus.valid,
      ticketId: ticketId,
      ticketData: ticketData,
    );
  }

  // ── Show the result as a bottom sheet ──
  void _showResultSheet({
    required _ScanStatus status,
    required String ticketId,
    required Map<String, dynamic>? ticketData,
  }) {
    showModalBottomSheet(
      context: context,
      isDismissible: false, // leader must tap a button to dismiss
      enableDrag: false,
      isScrollControlled: true, // lets sheet grow taller if needed
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ScanResultSheet(
        status: status,
        ticketId: ticketId,
        ticketData: ticketData,
        onCheckIn: () async {
          // Use the actual Firestore document ID, not the raw QR string
          final actualTicketId = ticketData?['ticketId'] ?? ticketId;
          print('[CheckIn] Attempting check-in for ticketId=$actualTicketId');
          try {
            final success = await _db.checkInParticipant(actualTicketId);
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  success
                      ? '${ticketData?['userName'] ?? 'Participant'} checked in successfully!'
                      : 'Already checked in or network error.',
                ),
                backgroundColor: success ? Colors.green : Colors.orange,
                duration: const Duration(seconds: 2),
              ),
            );
          } catch (e) {
            print('[CheckIn] Error: $e');
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Check-in failed: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
          _resumeCamera();
        },
        onScanAgain: () {
          Navigator.pop(context); // close the sheet
          _resumeCamera();
        },
      ),
    );
  }

  //Restart the camera after the sheet is dismissed
  void _resumeCamera() {
    setState(() => _isProcessing = false);
    _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Scan: ${widget.event.title}'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.group_rounded),
            tooltip: 'View Checked-in Participants',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    CheckedInParticipantsScreen(event: widget.event),
              ),
            ),
          ),
          // Torch toggle button
          IconButton(
            tooltip: 'Toggle flashlight',
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _camera.toggleTorch(),
          ),
          // Flip camera (front/back)
          IconButton(
            tooltip: 'Flip camera',
            icon: const Icon(Icons.flip_camera_ios_rounded),
            onPressed: () => _camera.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── CAMERA FEED (fills entire screen) ──
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
          ),

          // ── DARK OVERLAY with transparent target box in the middle ──
          _ScanOverlay(),

          // ── LOADING INDICATOR while looking up in Firebase ──
          if (_isProcessing)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),

          // ── HINT TEXT at the bottom ──
          const Positioned(
            bottom: 48,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Icon(Icons.qr_code_scanner, color: Colors.white70, size: 28),
                SizedBox(height: 8),
                Text(
                  'Point at a participant\'s QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white70, fontSize: 14, letterSpacing: 0.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SCAN RESULT BOTTOM SHEET
// Shows participant details and action buttons after scanning
enum _ScanStatus { valid, alreadyCheckedIn, unpaid, invalid }

class _ScanResultSheet extends StatelessWidget {
  final _ScanStatus status;
  final String ticketId;
  final Map<String, dynamic>? ticketData;
  final VoidCallback onCheckIn;
  final VoidCallback onScanAgain;

  const _ScanResultSheet({
    required this.status,
    required this.ticketId,
    required this.ticketData,
    required this.onCheckIn,
    required this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    // Choose visual style based on outcome
    final (Color color, IconData icon, String title, String subtitle) =
        switch (status) {
      _ScanStatus.valid => (
          Colors.green,
          Icons.check_circle_rounded,
          'Valid Ticket ✅',
          'This participant is registered and ready to check in.',
        ),
      _ScanStatus.alreadyCheckedIn => (
          Colors.blue,
          Icons.info_rounded,
          'Already Checked In',
          'This participant has already been checked in.',
        ),
      _ScanStatus.unpaid => (
          Colors.orange,
          Icons.warning_rounded,
          'Payment Required',
          'This registration has not been paid yet.',
        ),
      _ScanStatus.invalid => (
          Colors.red,
          Icons.cancel_rounded,
          'Invalid QR Code',
          'This QR code was not found in the system.',
        ),
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(height: 20),

            // ── Status icon ──
            CircleAvatar(
              radius: 38,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 42),
            ),

            const SizedBox(height: 14),

            // ── Status title ──
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),

            // ── Participant details (only shown if data exists) ──
            if (ticketData != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PARTICIPANT DETAILS',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.person_rounded,
                      label: 'Name',
                      value: ticketData!['userName'] ?? 'N/A',
                    ),
                    _DetailRow(
                      icon: Icons.badge_rounded,
                      label: 'Student ID',
                      value: ticketData!['studentId'] ?? 'N/A',
                    ),
                    _DetailRow(
                      icon: Icons.email_outlined,
                      label: 'Email',
                      value: ticketData!['userEmail'] ?? 'N/A',
                    ),
                    _DetailRow(
                      icon: Icons.event_rounded,
                      label: 'Event',
                      value: ticketData!['eventTitle'] ?? 'N/A',
                    ),
                    _DetailRow(
                      icon: Icons.confirmation_num_outlined,
                      label: 'Ticket ID',
                      value: ticketId,
                      isMonospace: true,
                    ),
                    _DetailRow(
                      icon: Icons.payment_rounded,
                      label: 'Payment',
                      value: (ticketData!['paymentStatus'] ?? 'N/A')
                          .toString()
                          .toUpperCase(),
                    ),
                    // Show check-in time only when already checked in
                    if (status == _ScanStatus.alreadyCheckedIn)
                      _DetailRow(
                        icon: Icons.access_time_rounded,
                        label: 'Checked In At',
                        value: ticketData!['checkedInAt'] != null
                            ? _formatTimestamp(ticketData!['checkedInAt'])
                            : 'Unknown',
                      ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            //Action buttons
            Row(
              children: [
                // "Scan Again" — always visible
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onScanAgain,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan Again'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                // "Check In" — only shown for valid tickets
                if (status == _ScanStatus.valid) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onCheckIn,
                      icon: const Icon(Icons.how_to_reg_rounded),
                      label: const Text('Check In'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Converts Firestore Timestamp to a readable date+time string
  String _formatTimestamp(dynamic ts) {
    try {
      final dt = ts.toDate() as DateTime;
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
      return '${dt.day} ${months[dt.month]} ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return 'Unknown';
    }
  }
}

// DETAIL ROW — one labelled row inside the participant details card
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isMonospace;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMonospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: isMonospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// CAMERA OVERLAY — dark surround with a transparent scan box in the middle
class _ScanOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;
    final boxSize = screenW * 0.65;
    final boxLeft = (screenW - boxSize) / 2;
    final boxTop = (screenH - boxSize) / 2.5; // slightly above centre

    return Stack(
      children: [
        // Top dark strip
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: boxTop,
          child: Container(color: Colors.black54),
        ),
        // Bottom dark strip
        Positioned(
          top: boxTop + boxSize,
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(color: Colors.black54),
        ),
        // Left dark strip
        Positioned(
          top: boxTop,
          left: 0,
          width: boxLeft,
          height: boxSize,
          child: Container(color: Colors.black54),
        ),
        // Right dark strip
        Positioned(
          top: boxTop,
          right: 0,
          width: boxLeft,
          height: boxSize,
          child: Container(color: Colors.black54),
        ),
        // White corner brackets over the transparent box
        Positioned(
          top: boxTop,
          left: boxLeft,
          width: boxSize,
          height: boxSize,
          child: _CornerBrackets(size: boxSize),
        ),
      ],
    );
  }
}

//Four white L-shaped corners
class _CornerBrackets extends StatelessWidget {
  final double size;
  const _CornerBrackets({required this.size});

  @override
  Widget build(BuildContext context) {
    const lineLen = 28.0;
    const lineW = 4.0;
    const color = Colors.white;

    return const Stack(
      children: [
        Positioned(
            top: 0,
            left: 0,
            child: _L(
                color: color,
                len: lineLen,
                thick: lineW,
                flipH: false,
                flipV: false)),
        Positioned(
            top: 0,
            right: 0,
            child: _L(
                color: color,
                len: lineLen,
                thick: lineW,
                flipH: true,
                flipV: false)),
        Positioned(
            bottom: 0,
            left: 0,
            child: _L(
                color: color,
                len: lineLen,
                thick: lineW,
                flipH: false,
                flipV: true)),
        Positioned(
            bottom: 0,
            right: 0,
            child: _L(
                color: color,
                len: lineLen,
                thick: lineW,
                flipH: true,
                flipV: true)),
      ],
    );
  }
}

//Single L-shape, mirrored for each corner
class _L extends StatelessWidget {
  final Color color;
  final double len;
  final double thick;
  final bool flipH;
  final bool flipV;

  const _L({
    required this.color,
    required this.len,
    required this.thick,
    required this.flipH,
    required this.flipV,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scaleX: flipH ? -1 : 1,
      scaleY: flipV ? -1 : 1,
      child: SizedBox(
        width: len,
        height: len,
        child: Stack(
          children: [
            // Horizontal bar
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: len,
                height: thick,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Vertical bar
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: thick,
                height: len,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
