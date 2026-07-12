import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// Import file navigasi kamu
import 'screens/main_navigation.dart'; 
import 'screens/login_screen.dart';
import 'services/notification_service.dart'; 
import 'services/auth_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

// Konstanta URL Database — region Asia Southeast 1 (bukan US default!)
const String kFirebaseDatabaseUrl = 
  'https://sawi-hijau-ai-default-rtdb.asia-southeast1.firebasedatabase.app';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase dengan opsi eksplisit
  // PENTING: databaseURL wajib diisi karena database ada di region Asia (bukan US default)
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyBkBjSv6-KDrBKkhDz7J0U9uYcQ0NjUxs0',
      appId: '1:868536611623:android:eb211cb8170fed6acf6f02',
      messagingSenderId: '868536611623',
      projectId: 'sawi-hijau-ai',
      databaseURL: 'https://sawi-hijau-ai-default-rtdb.asia-southeast1.firebasedatabase.app',
      storageBucket: 'sawi-hijau-ai.firebasestorage.app',
    ),
  );

  // Set databaseURL default agar instance global otomatis memakai region Asia
  FirebaseDatabase.instance.databaseURL = 'https://sawi-hijau-ai-default-rtdb.asia-southeast1.firebasedatabase.app';

  // Menyalakan Satpam Notifikasi
  NotificationService.init();

  runApp(const SmartAgriFISApp());
}

class SmartAgriFISApp extends StatelessWidget {
  const SmartAgriFISApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart AgriFIS',
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: AuthService().authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) {
            return const MainNavigation();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
