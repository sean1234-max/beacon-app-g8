import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AddEventScreen extends StatefulWidget {
  const AddEventScreen({super.key});

  @override
  State<AddEventScreen> createState() => _AddEventScreenState();
}

class _AddEventScreenState extends State<AddEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // Function to pick date and time
  Future<void> _pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2027),
    );
    if (date == null) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      _selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _submitEvent() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      await FirebaseFirestore.instance.collection('events').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locController.text.trim(),
        'dateTime': Timestamp.fromDate(_selectedDate),
        'clubId': user?.uid, // Ideally, this would be the specific Club ID
        'participants': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Event created successfully!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create New Event")),
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
                    validator: (val) => val!.isEmpty ? "Enter a title" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()),
                    maxLines: 3,
                    validator: (val) => val!.isEmpty ? "Enter a description" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _locController,
                    decoration: const InputDecoration(labelText: "Location (e.g. Block B, L3)", border: OutlineInputBorder()),
                    validator: (val) => val!.isEmpty ? "Enter a location" : null,
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
                    onPressed: _submitEvent,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
                    child: const Text("Post Event", style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}