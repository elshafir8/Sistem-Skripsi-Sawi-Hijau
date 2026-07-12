import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _auth = AuthService();
  final _formKey = GlobalKey<FormState>();

  String email = '';
  String password = '';
  String error = '';
  bool loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.green,
        elevation: 0.0,
        title: const Text('Login Smart AgriFIS', style: TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 50.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              const SizedBox(height: 20.0),
              Image.asset('assets/logo.png', height: 100),
              const SizedBox(height: 20.0),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Email',
                  prefixIcon: Icon(Icons.email, color: Colors.green),
                ),
                validator: (val) => val!.isEmpty ? 'Masukkan email' : null,
                onChanged: (val) {
                  setState(() => email = val);
                },
              ),
              const SizedBox(height: 20.0),
              TextFormField(
                decoration: const InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.lock, color: Colors.green),
                ),
                obscureText: true,
                validator: (val) => val!.length < 6 ? 'Password minimal 6 karakter' : null,
                onChanged: (val) {
                  setState(() => password = val);
                },
              ),
              const SizedBox(height: 20.0),
              loading 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Login'),
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        setState(() => loading = true);
                        dynamic result = await _auth.signInWithEmailAndPassword(email, password);
                        if (result == null) {
                          setState(() {
                            error = 'Gagal login, cek email/password';
                            loading = false;
                          });
                        }
                      }
                    },
                  ),
              const SizedBox(height: 12.0),
              Text(error, style: const TextStyle(color: Colors.red, fontSize: 14.0)),
              TextButton(
                child: const Text('Belum punya akun? Daftar di sini', style: TextStyle(color: Colors.green)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
