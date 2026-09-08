import 'package:flutter/material.dart';
import 'signup_screen.dart';
import 'home_screen.dart';
import 'shop_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  void _login(BuildContext context) {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email == 'admin@stockwise.com' && password == 'admin123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (email == 'user@stockwise.com' && password == 'user123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ShopScreen()),
      );
    } else {
      setState(() => _error = 'Invalid email or password');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 30),
                  const Text(
                    'StockWise',
                    style: TextStyle(
                      color: Color(0xFF76A873),
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 55),
                  const Text(
                    'Welcome Back!',
                    style: TextStyle(
                      color: Color(0xFF5F8F5F),
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Manage stock, reduce waste',
                    style: TextStyle(
                      color: Color(0xFF6F6F6F),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  _buildTextField(_emailController, 'Email'),
                  const SizedBox(height: 18),
                  _buildTextField(_passwordController, 'Password', isPassword: true),
                  const SizedBox(height: 24),
                  _buildLoginButton(context),
                  const SizedBox(height: 18),
                  _buildLinks(context),
                  const SizedBox(height: 20),
                  const Text(
                    'Demo: admin@stockwise.com / admin123\n      user@stockwise.com / user123',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF999999),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint,
      {bool isPassword = false}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFB5B5B5),
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 2.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 2.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF75A972), width: 2.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 17,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _login(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF75A972),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
          shadowColor: Colors.black26,
        ),
        child: const Text(
          'LOGIN',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _buildLinks(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {},
          child: const Text(
            'Forgot Password',
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const Text(
          ' | ',
          style: TextStyle(
            color: Color(0xFF555555),
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SignupScreen()),
            );
          },
          child: const Text(
            'Sign Up',
            style: TextStyle(
              color: Color(0xFF555555),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
