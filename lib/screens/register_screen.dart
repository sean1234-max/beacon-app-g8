import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:assignment/theme/app_theme.dart';
import 'package:assignment/screens/login_screen.dart';
import 'package:assignment/screens/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:assignment/services/auth_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Ensure your web config is set up as discussed
  runApp(const APUConnectApp());
}

class APUConnectApp extends StatelessWidget {
  const APUConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'APU Connect',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme, // Using the theme from Step 1
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    // This listens to whether a user is logged in or not
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return const MainNavigationScreen(); // Logged in
        }
        return const LoginScreen(); // Not logged in
      },
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  void _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // --- 1. Basic Validation ---
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    // --- 2. Domain-Based Role Logic ---
    String assignedRole = 'student'; // Default role
    if (email.endsWith('@mail.apu.edu.my')) {
      assignedRole = 'club_leader';
    }

    // --- 3. Call AuthService with the role ---
    final user = await AuthService().register(
      email,
      password,
      role: assignedRole, // This passes the role to your updated AuthService
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      // If successful, navigate back
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(assignedRole == 'club_leader' 
            ? "Club Leader account created!" 
            : "Student account created!"),
          backgroundColor: AppTheme.primaryBlue,
        ),
      );
    } else {
      // Handle potential errors (e.g. weak password or email already in use)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration failed. Please check your details.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController, 
              decoration: const InputDecoration(labelText: "Full Name")
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _emailController, 
              decoration: const InputDecoration(
                labelText: "Email",
                hintText: "Use @mail.apu.edu.my for Leader role", // Hint for testing
                hintStyle: TextStyle(fontSize: 12)
              )
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController, 
              decoration: const InputDecoration(labelText: "Password"), 
              obscureText: true
            ),
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _register, 
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text("Register"),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}