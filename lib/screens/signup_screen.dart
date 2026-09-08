import 'package:flutter/material.dart';
import 'login_screen.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 100),
                const Text(
                  'StockWise',
                  style: TextStyle(
                    color: Color(0xFF76A873),
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 50),
                const Text(
                  'Sign Up',
                  style: TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 30),
                _buildTextField('Email'),
                const SizedBox(height: 18),
                _buildTextField('Password', isPassword: true),
                const SizedBox(height: 18),
                _buildTextField('Confirm Password', isPassword: true),
                const SizedBox(height: 55),
                _buildRegisterButton(),
                const SizedBox(height: 16),
                _buildLoginNowLink(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildTextField(String hint, {bool isPassword = false}) {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: TextField(
        obscureText: isPassword,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFFAAAAAA),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 2.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFDDDDDD), width: 2.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF75A972), width: 2.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        ),
        style: const TextStyle(
          color: Color(0xFF555555),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF75A972),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 4,
          shadowColor: Colors.black26,
        ),
        child: const Text(
          'REGISTER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  static Widget _buildLoginNowLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'Already have an account? ',
          style: TextStyle(
            color: Color(0xFF777777),
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        GestureDetector(
          onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          child: const Text(
            'Login Now',
            style: TextStyle(
              color: Color(0xFFD32F2F),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
