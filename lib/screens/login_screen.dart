import 'package:assignment/screens/admin_dashboard_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:assignment/screens/register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _submit(bool isLogin) async {
    setState(() => _isLoading = true);
    var user = isLogin 
      ? await _authService.signIn(_emailController.text.trim(), _passwordController.text)
      : await _authService.register(
          _emailController.text.trim(), 
          _passwordController.text,
          name: _nameController.text.trim(), 
          phone: _phoneController.text.trim(), 
      );
    
    setState(() => _isLoading = false);

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication Failed. Please try again.")),
        );
      }
    } else {
      if (mounted) {
        await _handleRoleBasedNavigation(user.uid);
      }
    }
  }

  Future<void> _handleRoleBasedNavigation(String uid) async {
    try {
      // Fetch user data from your Firestore users collection
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (!mounted) return;

      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        String role = data['role'] ?? 'student'; 

        if (role == 'admin') {
          // Redirect to your Admin Dashboard
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()), 
            (route) => false,
          );
          return;
        }
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => MainNavigationScreen()),
        (route) => false,
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching user profile: $e")),
        );
      }
    }
  }

  // 🟢 Google Sign-In Method Handler
  void _submitGoogle() async {
    setState(() => _isLoading = true);
    var user = await _authService.signInWithGoogle();
    setState(() => _isLoading = false);

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Google Sign-In Canceled or Failed.")),
        );
      }
    } else {
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => MainNavigationScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean white background
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo Section
                Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    'assets/Beacon Logo.png',
                    height: 140, // Slightly smaller for better proportions
                    width: 140,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Welcome Text
                Text(
                  "Welcome Back",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to continue to your account",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 40),
                
                // Email Field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Student Email',
                    hintText: 'e.g. TP123456@mail.apu.edu.my',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Please enter a valid student email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(true), // Allow pressing enter to submit
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _submit(true),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).primaryColor, // Uses your app's primary color
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Login',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                ),
                const SizedBox(height: 16),
                
                // Register Prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Don't have an account?",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    TextButton(
                      onPressed: _isLoading 
                        ? null 
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const RegisterScreen()),
                            );
                          },
                      child: const Text(
                        "Register here",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              
                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, endIndent: 16, color: Colors.grey.shade300)),
                    Text(
                      "OR", 
                      style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                    Expanded(child: Divider(thickness: 1, indent: 16, color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 24),

                // Google Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Colors.white, // In case of background tint
                  ),
                  icon: Image.asset(
                    'assets/googleLogo.png', 
                    height: 24,
                    width: 24,                
                    fit: BoxFit.contain,       
                  ),
                  label: const Text(
                    "Continue with Google",
                    style: TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onPressed: _isLoading ? null : _submitGoogle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      var user = await _authService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (user == null && mounted) {
        throw Exception("Invalid credentials");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}