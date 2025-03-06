import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isLoading = false;
  bool _obscurePassword = true;

  // Color constants (you can tweak as desired)
  static const Color primaryGreen = Color(0xFF008300);
  static const Color darkGreen = Color(0xFF006A00);
  static const Color lightGreen = Color(0xFF229022);
  static const Color primaryBlue = Color(0xFF003299);
  static const Color darkBlue = Color(0xFF00018D);

  @override
  void initState() {
    super.initState();

    // Clear fields when the LoginPage is built
    _emailController.clear();
    _passwordController.clear();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final typedEmail = _emailController.text.trim();
        final typedPassword = _passwordController.text;

        // 1) Check if the typed creds match the single admin doc
        await FirebaseAuth.instance.signInAnonymously();
        final adminDoc = await FirebaseFirestore.instance
            .collection('admin')
            .doc('JiLwbnNdP0FwBKGmDSiD')
            .get();

        // If the doc read is successful (no PERMISSION_DENIED), proceed
        if (adminDoc.exists) {
          final adminEmail = adminDoc['email'] as String;
          final adminPassword = adminDoc['password'] as String;

          if (typedEmail == adminEmail && typedPassword == adminPassword) {
            // Condition 1: Admin credentials match
            _emailController.clear();
            _passwordController.clear();
            Navigator.pushReplacementNamed(context, '/adminDashboard');
            return; // Stop here
          }
        }

        // 2) Not admin, so check if this email is in the "users" collection
        //    We assume your 'users' docs each have a field "email" storing the user's email
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: typedEmail)
            .limit(1)
            .get();

        if (userQuery.docs.isNotEmpty) {
          // Condition 2: The email exists in 'users', so attempt Firebase Auth sign-in
          await _auth.signInWithEmailAndPassword(
            email: typedEmail,
            password: typedPassword,
          );
          _emailController.clear();
          _passwordController.clear();
          Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
          // Condition 3: Not admin & not in users => show error
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No account found for these credentials.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } on FirebaseException catch (e) {
        // Firestore or Auth error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log in: ${e.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } catch (e) {
        // Other errors
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to log in. Please check your credentials and try again.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Make the body extend behind the system status bar
      extendBodyBehindAppBar: true,
      // Transparent so our gradient background shows through
      backgroundColor: Colors.transparent,

      body: Stack(
        children: [
          // 1) Full-screen gradient background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                // Two shades of green; adjust to your preference
                colors: [
                  Color(0xFF229022), // Lighter green
                  Color(0xFF006A00), // Darker green
                ],
                stops: [0.0, 1.0],
              ),
            ),
          ),

          // 2) Foreground: the login form in a SafeArea
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Text(
                            "Electrack",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: darkGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            "Sign in to continue",
                            style: TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 32),

                          // Email
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'Enter your email',
                              prefixIcon: const Icon(Icons.email, color: darkGreen),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: lightGreen.withOpacity(0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: darkGreen, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              filled: true,
                              fillColor: lightGreen.withOpacity(0.1),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              // If user typed exactly "admin", skip the '@' check
                              if (value != 'admin' && !value.contains('@')) {
                                return 'Please enter a valid email or "admin"';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),

                          // Password
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: 'Enter your password',
                              prefixIcon: const Icon(Icons.lock, color: primaryBlue),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: darkBlue,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: primaryBlue.withOpacity(0.5)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: darkBlue, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Colors.red),
                              ),
                              filled: true,
                              fillColor: primaryBlue.withOpacity(0.05),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          // Forgot password
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                // Handle forgot password
                              },
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(color: primaryBlue),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _login,
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: primaryGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Text(
                                'LOGIN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Register link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account? "),
                              InkWell(
                                onTap: () => Navigator.pushReplacementNamed(context, '/register'),
                                child: const Text(
                                  'Register',
                                  style: TextStyle(
                                    color: darkBlue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
