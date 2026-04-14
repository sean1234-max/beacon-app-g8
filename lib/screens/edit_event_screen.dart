import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart'; // Make sure this path is correct
import 'package:intl/intl.dart';

class EditEventScreen extends StatefulWidget {
  final Event event; // We pass the whole event object here

  const EditEventScreen({super.key, required this.event});

  @override
  State<EditEventScreen> createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _locController;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with EXISTING data from the event
    _titleController = TextEditingController(text: widget.event.title);
    _descController = TextEditingController(text: widget.event.description);
    _locController = TextEditingController(text: widget.event.location);
    _selectedDate = widget.event.dateTime;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locController.dispose();
    super.dispose();
  }

  Future<void> _updateEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(widget.event.id) // Use the unique ID of the event
          .update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locController.text.trim(),
        'dateTime': Timestamp.fromDate(_selectedDate),
        'lastModified': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context); // Go back to list
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event updated successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update: $e")),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Reuse your date picker logic here...
  Future<void> _pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime(2027),
    );
    if (date == null) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Event Details")),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: "Event Title", border: OutlineInputBorder()),
                    validator: (val) => val!.isEmpty ? "Title cannot be empty" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _locController,
                    decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 15),
                  ListTile(
                    title: Text("Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(_selectedDate)}"),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: _pickDateTime,
                    tileColor: Colors.blue.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _updateEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("Save Changes"),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}