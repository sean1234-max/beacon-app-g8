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
  
  // Note: userRole should ideally be passed in or fetched from Auth
  String userRole = 'leader'; 
  
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

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
    // Basic validation
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Check if user is logged in
      if (user == null) {
        throw Exception("You must be logged in to create an event.");
      }

      // Step 1: Save the event with the 'creatorId'
      await FirebaseFirestore.instance.collection('events').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locController.text.trim(),
        'dateTime': Timestamp.fromDate(_selectedDate),
        
        // This line is the most important for the "Modify" feature:
        'creatorId': user.uid, 
        
        'clubId': "APU General", 
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create New Event"),
        // Match your APU Connect theme
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF003366), // Example primary blue
        elevation: 0,
      ),
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
                    decoration: const InputDecoration(
                      labelText: "Event Title", 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event),
                    ),
                    validator: (val) => val!.isEmpty ? "Enter a title" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(
                      labelText: "Description", 
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    validator: (val) => val!.isEmpty ? "Enter a description" : null,
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _locController,
                    decoration: const InputDecoration(
                      labelText: "Location (e.g. Block B, L3)", 
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on),
                    ),
                    validator: (val) => val!.isEmpty ? "Enter a location" : null,
                  ),
                  const SizedBox(height: 15),
                  // Date Picker UI
                  InkWell(
                    onTap: _pickDateTime,
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                        color: Colors.blue.withOpacity(0.05),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Color(0xFF003366)),
                          const SizedBox(width: 10),
                          Text(
                            "Date: ${DateFormat('dd MMM yyyy, hh:mm a').format(_selectedDate)}",
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _submitEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text("Post Event", style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}