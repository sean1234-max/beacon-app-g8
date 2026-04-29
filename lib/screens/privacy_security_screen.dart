// ignore_for_file: use_build_context_synchronously

import 'package:assignment/models/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:assignment/theme/app_theme.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Adjust based on your folder structure
import 'package:cloud_firestore/cloud_firestore.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _isPrivateAccount = false;

  // Inside your _PrivacySecurityScreenState
  bool _isPasswordVisible = false;
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handlePasswordReset() async {
    String newPassword = _passwordController.text.trim();

    if (newPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a new password")),
      );
      return;
    }

    if (newPassword.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password must be at least 6 characters")),
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Update the password in Firebase Auth
        await user.updatePassword(newPassword);

        // 2. TRIGGER THE SECURITY NOTIFICATION
        // This ensures the student has a persistent record of the account change
        await NotificationService.sendNotification(
          userId: user.uid,
          title: "Password Changed 🔐",
          message:
              "Your account password was successfully updated. If you did not perform this action, please contact APU IT support immediately.",
          type: "security",
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Password updated successfully!"),
              backgroundColor: Colors.green,
            ),
          );
          _passwordController.clear();
          Navigator.pop(context); // Closes the dialog/screen after success
        }
      }
    } catch (e) {
      // Note: updatePassword often requires "Recent Login".
      // If this fails, the user might need to log out and log back in.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadPrivacySetting();
  }

  Future<void> _loadPrivacySetting() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          // Default to false if the field doesn't exist yet
          _isPrivateAccount = doc.data()?['isPrivate'] ?? false;
        });
      }
    }
  }

  Future<void> _handleDeleteAccount() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // 1. Delete user data from Firestore first
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .delete();

        // 2. Delete the Auth account
        await user.delete();

        // 3. Navigate back to Login
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/login', (route) => false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Error: Please re-login to delete your account.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Privacy & Security"),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Privacy Settings",
                style: TextStyle(
                    color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
          ),
          SwitchListTile(
            title: const Text("Private Profile"),
            subtitle: const Text("Only mutuals can see your event history"),
            value: _isPrivateAccount,
            activeThumbColor: AppTheme.primaryBlue,
            onChanged: (val) async {
              setState(() => _isPrivateAccount = val);

              // Save to Firestore
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'isPrivate': val});
              }
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text("Account Security",
                style: TextStyle(
                    color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.password_rounded),
            title: const Text("Reset Password"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Show a dialog when tapped
              showDialog(
                context: context,
                builder: (context) => StatefulBuilder(
                  // Necessary to toggle the eye icon inside a dialog
                  builder: (context, setDialogState) {
                    return AlertDialog(
                      title: const Text("Change Password"),
                      content: TextFormField(
                        controller: _passwordController,
                        obscureText: !_isPasswordVisible,
                        decoration: InputDecoration(
                          labelText: "New Password",
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isPasswordVisible
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: AppTheme.primaryBlue,
                            ),
                            onPressed: () {
                              // Use setDialogState to refresh the eye icon in the popup
                              setDialogState(() {
                                _isPasswordVisible = !_isPasswordVisible;
                              });
                            },
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: _handlePasswordReset,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue),
                          child: const Text("Update",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text("Delete Account",
                style: TextStyle(color: Colors.red)),
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Delete Account?"),
                  content: const Text(
                      "This action is permanent and will wipe all your data from Beacon."),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: _handleDeleteAccount,
                      child: const Text("Delete",
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
