// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';

class EditBioScreen extends StatefulWidget {
  const EditBioScreen({super.key});

  @override
  State<EditBioScreen> createState() => _EditBioScreenState();
}

class _EditBioScreenState extends State<EditBioScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final _formKey = GlobalKey<FormState>();

  // Controllers to handle text input
  late TextEditingController _bioController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers with current user data
    _bioController = TextEditingController();
    _loadUserData();
  }

  // Fetch extra data (Bio/Student ID) from Firestore
  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    if (doc.exists) {
      setState(() {
        _bioController.text = doc.data()?['bio'] ?? "";
      });
    }
  }

  Future<void> _updateBio() async {
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
      'bio': _bioController.text,
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Update Firestore (Bio, Student ID, Name)
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'bio': _bioController.text,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bio Updated Successfully!")),
        );
        Navigator.pop(context); // Go back to Profile Screen
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
      appBar: AppBar(
        title: const Text("Edit Bio"),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // const Stack(
                    //   alignment: Alignment.bottomRight,
                    //   children: [
                    //     CircleAvatar(
                    //       radius: 50,
                    //       backgroundColor: Colors.grey,
                    //       child:
                    //           Icon(Icons.person, size: 50, color: Colors.white),
                    //     ),
                    //     CircleAvatar(
                    //       radius: 18,
                    //       backgroundColor: AppTheme.primaryBlue,
                    //       child: Icon(Icons.camera_alt,
                    //           size: 18, color: Colors.white),
                    //     ),
                    //   ],
                    // ),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: _bioController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: "Bio",
                        border: OutlineInputBorder(),
                        hintText: "Tell us about yourself...",
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _updateBio,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text("Save Changes"),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
