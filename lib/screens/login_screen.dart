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
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  void _submit(bool isLogin) async {
    setState(() => _isLoading = true);
    var user = isLogin 
      ? await _authService.signIn(_emailController.text, _passwordController.text)
      : await _authService.register(_emailController.text, _passwordController.text);
    
    setState(() => _isLoading = false);

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Authentication Failed. Please try again.")),
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

  // 🟢 NEW: Google Sign-In Method Handler
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 60), // Spacing from top safe area
                Image.asset(
                  'assets/Beacon Logo.png',
                  height: 250,
                  width: 250,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 30),
                
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Student Email'),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Please enter a valid student email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 24),
                _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: () => _submit(true),
                      child: const Text('Login'),
                    ),
                
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const RegisterScreen()),
                    );
                  },
                  child: const Text("Don't have an account? Register here"),
                ),

                // 🟢 NEW: Clean UI Visual Divider
                const Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, endIndent: 10)),
                    Text("OR", style: TextStyle(color: Colors.grey)),
                    Expanded(child: Divider(thickness: 1, indent: 10)),
                  ],
                ),
                const SizedBox(height: 16),

                // 🟢 NEW: Material Styled Google Button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  // 🟢 UPDATED: This handles the 900x715 proportions automatically
                  icon: Image.asset(
                    'assets/googleLogo.png', // Make sure this matches your filename exactly
                    height: 20,
                    width: 20,                 // Forces it into a 1:1 box aspect ratio
                    fit: BoxFit.contain,       // Scales it down safely without distortion
                  ),
                  label: const Text(
                    "Continue with Google",
                    style: TextStyle(color: Colors.black87, fontSize: 16),
                  ),
                  onPressed: _isLoading ? null : _submitGoogle,
                )
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