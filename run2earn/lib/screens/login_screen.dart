import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final AuthService auth = AuthService();

  final email = TextEditingController();
  final pass = TextEditingController();

  bool isLogin = true;
  bool loading = false;

  // ================= SUBMIT =================

  Future<void> _submit() async {

    if (email.text.isEmpty || pass.text.isEmpty) {
      _showError("Fill all fields");
      return;
    }

    setState(() => loading = true);

    try {

      final user = isLogin
          ? await auth.login(email.text, pass.text)
          : await auth.register(email.text, pass.text);

      if (user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(),
          ),
        );
      }

    } catch (e) {
      _showError(e.toString());
    }

    setState(() => loading = false);
  }

  // ================= ERROR =================

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(25),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // Logo
                const Icon(
                  Icons.flash_on,
                  color: Colors.cyanAccent,
                  size: 60,
                ),

                const SizedBox(height: 10),

                const Text(
                  "RUN2EARN",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  isLogin ? "Login" : "Create Account",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 25),

                // Email
                _input(
                  controller: email,
                  hint: "Email",
                  icon: Icons.email,
                ),

                const SizedBox(height: 15),

                // Password
                _input(
                  controller: pass,
                  hint: "Password",
                  icon: Icons.lock,
                  hide: true,
                ),

                const SizedBox(height: 25),

                // Button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: loading ? null : _submit,
                    child: loading
                        ? const CircularProgressIndicator(
                      color: Colors.black,
                    )
                        : Text(
                      isLogin ? "LOGIN" : "REGISTER",
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Switch
                TextButton(
                  onPressed: () {
                    setState(() {
                      isLogin = !isLogin;
                    });
                  },
                  child: Text(
                    isLogin
                        ? "Create new account"
                        : "Already have account?",
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================= INPUT =================

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool hide = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: hide,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white54),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
