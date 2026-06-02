import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddEventScreen extends StatefulWidget {
  final String clubId;
  const AddEventScreen({super.key, this.clubId = ''});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();
  final _picNameController = TextEditingController();
  final _picPhoneController = TextEditingController();
  final _feeController = TextEditingController();
  String? _selectedBank;
  final _bankAccController = TextEditingController();
  final _bankReceiverController = TextEditingController();

  // State
  DateTime? _eventDate;
  TimeOfDay? _startTime;
  DateTime? _regDeadline;
  bool _isPaid = false;
  String? _posterBase64;
  String? _paymentQrBase64;
  bool _isLoading = false;

  static const _primary = Color(0xFF003366);
  static const _accent = Color(0xFF6C63FF);

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locController.dispose();
    _picNameController.dispose();
    _picPhoneController.dispose();
    _feeController.dispose();
    _bankAccController.dispose();
    _bankReceiverController.dispose();
    super.dispose();
  }

  //  PICKERS
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    if (date != null) setState(() => _eventDate = date);
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) setState(() => _startTime = time);
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() => _regDeadline =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  Future<void> _pickImage({required bool isPoster}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: isPoster ? 40 : 40,
      maxWidth: isPoster ? 800 : 400,
      maxHeight: isPoster ? 1131 : 400,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();

    // Each image goes into its own sub-document (1MB limit each).
    // Reject anything over 750KB raw (~1MB as base64).
    if (bytes.lengthInBytes > 750000) {
      _showErrorDialog(
        'Image Too Large',
        'The selected image is ${(bytes.lengthInBytes / 1024).toStringAsFixed(0)} KB '
            'after compression, which is still too large.\n\n'
            'Please use a screenshot or export the poster at a lower resolution.',
      );
      return;
    }

    final b64 = base64Encode(bytes);
    setState(() {
      if (isPoster) {
        _posterBase64 = b64;
      } else {
        _paymentQrBase64 = b64;
      }
    });
  }

  //  SUBMIT
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_titleController.text.trim().isEmpty) {
      _showError('Event title is required.');
      return;
    }
    if (_descController.text.trim().isEmpty) {
      _showError('Event description is required.');
      return;
    }
    if (_locController.text.trim().isEmpty) {
      _showError('Event location is required.');
      return;
    }
    if (_eventDate == null) {
      _showError('Please select an event date.');
      return;
    }
    if (_startTime == null) {
      _showError('Please select a start time.');
      return;
    }
    if (_regDeadline == null) {
      _showError('Please select a registration deadline.');
      return;
    }
    if (_picNameController.text.trim().isEmpty) {
      _showError('Person in charge name is required.');
      return;
    }
    if (_picPhoneController.text.trim().isEmpty) {
      _showError('Person in charge phone number is required.');
      return;
    }
    if (_isPaid && _paymentQrBase64 == null) {
      _showError('Please upload a payment QR code.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final startDateTime = DateTime(
        _eventDate!.year,
        _eventDate!.month,
        _eventDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      final Map<String, dynamic> data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locController.text.trim(),
        'dateTime': Timestamp.fromDate(startDateTime),
        'registrationDeadline': Timestamp.fromDate(_regDeadline!),
        'picName': _picNameController.text.trim(),
        'picPhone': _picPhoneController.text.trim(),
        'paymentType': _isPaid ? 'paid' : 'free',
        'creatorId': user.uid,
        'clubId': widget.clubId,
        'participants': [],
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_isPaid) {
        data['eventFee'] = double.tryParse(_feeController.text.trim()) ?? 0;
        data['bankName'] = _selectedBank ?? '';
        data['bankAccountNumber'] = _bankAccController.text.trim();
        data['bankReceiverName'] = _bankReceiverController.text.trim();
      }

      // Save text-only main document first (no images = well under 1MB)
      final docRef =
          await FirebaseFirestore.instance.collection('events').add(data);

      // Save images to sub-documents — each gets its own 1MB budget
      if (_posterBase64 != null) {
        await docRef
            .collection('media')
            .doc('poster')
            .set({'base64': _posterBase64});
      }
      if (_isPaid && _paymentQrBase64 != null) {
        await docRef
            .collection('media')
            .doc('paymentQr')
            .set({'base64': _paymentQrBase64});
      }

      debugPrint('Event saved successfully (id: ${docRef.id})');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Event successfully created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) => _showErrorDialog('Error', msg);

  void _showErrorDialog(String title, String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  //  BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Create Event',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPosterUpload(),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.info_outline,
                    color: Colors.blue,
                    label: 'Basic Information',
                    children: [
                      _buildField(
                        controller: _titleController,
                        label: 'Event Title',
                        hint: 'Enter event title',
                        validator: (v) =>
                            v!.isEmpty ? 'Event title is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _descController,
                        label: 'Event Description',
                        hint: 'Describe your event...',
                        maxLines: 4,
                        validator: (v) =>
                            v!.isEmpty ? 'Description is required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.calendar_month_outlined,
                    color: Colors.orange,
                    label: 'Event Details',
                    children: [
                      _buildField(
                        controller: _locController,
                        label: 'Location / Venue',
                        hint: 'Enter location or venue',
                        prefixIcon: Icons.location_on_outlined,
                        validator: (v) =>
                            v!.isEmpty ? 'Location is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildTapField(
                        label: 'Event Date',
                        value: _eventDate != null
                            ? DateFormat('dd MMM yyyy').format(_eventDate!)
                            : null,
                        hint: 'Select date',
                        icon: Icons.calendar_today_outlined,
                        onTap: _pickDate,
                        required: true,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTapField(
                              label: 'Start Time',
                              value: _startTime?.format(context),
                              hint: 'Select time',
                              icon: Icons.access_time_outlined,
                              onTap: _pickStartTime,
                              required: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTapField(
                              label: 'Reg. Deadline',
                              value: _regDeadline != null
                                  ? DateFormat('dd MMM, hh:mm a')
                                      .format(_regDeadline!)
                                  : null,
                              hint: 'Select deadline',
                              icon: Icons.event_busy_outlined,
                              onTap: _pickDeadline,
                              required: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    icon: Icons.person_outline,
                    color: Colors.teal,
                    label: 'Person in Charge',
                    children: [
                      _buildField(
                        controller: _picNameController,
                        label: 'Person in Charge Name',
                        hint: 'Enter full name',
                        prefixIcon: Icons.person_outline,
                        validator: (v) =>
                            v!.isEmpty ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      _buildField(
                        controller: _picPhoneController,
                        label: 'Person in Charge Phone Number',
                        hint: 'Enter phone number',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v!.isEmpty ? 'Phone number is required' : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPaymentSection(),
                  const SizedBox(height: 24),
                  _buildSubmitButton(),
                  const SizedBox(height: 12),
                  _buildCancelButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  //  POSTER UPLOAD
  Widget _buildPosterUpload() {
    return GestureDetector(
      onTap: () => _pickImage(isPoster: true),
      child: AspectRatio(
        aspectRatio: 1 / 1.414, //A4 poster size
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _posterBase64 != null ? _accent : Colors.grey[300]!,
              width: _posterBase64 != null ? 2 : 1,
            ),
          ),
          child: _posterBase64 != null
              ? Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.memory(
                        base64Decode(_posterBase64!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                    // Re-upload hint overlay at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(15)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.edit_outlined,
                                color: Colors.white, size: 14),
                            SizedBox(width: 6),
                            Text('Tap to change poster',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(Icons.cloud_upload_outlined,
                          size: 36, color: _accent),
                    ),
                    const SizedBox(height: 12),
                    const Text('Tap to upload poster',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
                    const SizedBox(height: 4),
                    Text('JPG, PNG (Max: 5MB)',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[500])),
                  ],
                ),
        ),
      ),
    );
  }

  //  PAYMENT SECTION
  Widget _buildPaymentSection() {
    return _buildSection(
      icon: Icons.payment_outlined,
      color: Colors.purple,
      label: 'Payment',
      children: [
        // Free / Paid toggle
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPaid = false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: !_isPaid ? _primary : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: !_isPaid ? _primary : Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.money_off_rounded,
                          size: 18,
                          color: !_isPaid ? Colors.white : Colors.grey),
                      const SizedBox(width: 6),
                      Text('Free',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isPaid ? Colors.white : Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _isPaid = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _isPaid ? _primary : Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _isPaid ? _primary : Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.attach_money_rounded,
                          size: 18,
                          color: _isPaid ? Colors.white : Colors.grey),
                      const SizedBox(width: 6),
                      Text('Paid',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isPaid ? Colors.white : Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // Paid-only fields
        if (_isPaid) ...[
          const SizedBox(height: 16),
          _buildField(
            controller: _feeController,
            label: 'Event Fee (RM)',
            hint: 'e.g. 10.00',
            prefixIcon: Icons.attach_money_rounded,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) {
              if (!_isPaid) return null;
              if (v!.isEmpty) return 'Please enter the event fee';
              if (double.tryParse(v) == null) return 'Enter a valid amount';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedBank,
            decoration: InputDecoration(
              labelText: 'Bank Name',
              prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
              filled: true,
              fillColor: const Color(0xFFF8F9FF),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _primary, width: 1.5),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.red),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
            hint: const Text('Select bank'),
            items: const [
              'Affin Bank',
              'Alliance Bank',
              'AmBank',
              'Bank Islam',
              'Bank Rakyat',
              'Boost',
              'BSN',
              'CIMB Bank',
              'GrabPay',
              'Hong Leong Bank',
              'HSBC Bank',
              'Maybank',
              'OCBC Bank',
              'Public Bank',
              'RHB Bank',
              'Standard Chartered',
              'Touch \'n Go (TNG)',
            ]
                .map((bank) => DropdownMenuItem(
                      value: bank,
                      child: Text(bank),
                    ))
                .toList(),
            onChanged: (val) => setState(() => _selectedBank = val),
            validator: (v) => _isPaid && (v == null || v.isEmpty)
                ? 'Please select a bank'
                : null,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _bankAccController,
            label: 'Bank Account Number',
            hint: 'Enter account number',
            prefixIcon: Icons.credit_card_outlined,
            keyboardType: TextInputType.number,
            validator: (v) =>
                _isPaid && v!.isEmpty ? 'Account number is required' : null,
          ),
          const SizedBox(height: 12),
          _buildField(
            controller: _bankReceiverController,
            label: 'Bank Receiver Name',
            hint: 'Enter receiver full name',
            prefixIcon: Icons.person_outline,
            validator: (v) =>
                _isPaid && v!.isEmpty ? 'Receiver name is required' : null,
          ),
          const SizedBox(height: 12),
          // QR upload
          GestureDetector(
            onTap: () => _pickImage(isPoster: false),
            child: Container(
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _paymentQrBase64 != null
                      ? Colors.purple
                      : Colors.grey[300]!,
                  width: _paymentQrBase64 != null ? 2 : 1,
                ),
              ),
              child: _paymentQrBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.memory(
                        base64Decode(_paymentQrBase64!),
                        fit: BoxFit.contain,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2_rounded,
                            size: 40, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        const Text('Upload Payment QR Code',
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Bank QR or Touch \'n Go QR',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey[500])),
                      ],
                    ),
            ),
          ),
          if (_paymentQrBase64 != null)
            TextButton.icon(
              onPressed: () => setState(() => _paymentQrBase64 = null),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label:
                  const Text('Remove QR', style: TextStyle(color: Colors.red)),
            ),
        ],
      ],
    );
  }

  //  BUTTONS
  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _submit,
        icon: const Icon(Icons.send_rounded, color: Colors.white),
        label: const Text('Create Event',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey[700],
          side: BorderSide(color: Colors.grey[300]!),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: const Text('Cancel',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  //  REUSABLE WIDGETS
  Widget _buildSection({
    required IconData icon,
    required Color color,
    required String label,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
        filled: true,
        fillColor: const Color(0xFFF8F9FF),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildTapField({
    required String label,
    required String? value,
    required String hint,
    required IconData icon,
    required VoidCallback onTap,
    bool required = false,
  }) {
    final hasValue = value != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: hasValue ? _primary : Colors.grey[400]),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(
                    hasValue ? value : hint,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          hasValue ? FontWeight.w600 : FontWeight.normal,
                      color: hasValue ? Colors.black87 : Colors.grey[400],
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
