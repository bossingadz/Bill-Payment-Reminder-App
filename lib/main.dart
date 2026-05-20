import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AuthService.initialize();

  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('Error initializing notifications: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String _guestModeKey = 'continue_as_guest';

  Future<bool> _canOpenHomeScreen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final continueAsGuest = prefs.getBool(_guestModeKey) ?? false;
      final hasFirebaseSession = AuthService.currentUser != null;
      return continueAsGuest || hasFirebaseSession;
    } catch (e) {
      debugPrint('Startup auth check failed: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bill Reminder',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B6CFF),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F7FF),
      ),
      home: FutureBuilder<bool>(
        future: _canOpenHomeScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return const LoginScreen();
          }

          final canOpenHome = snapshot.data ?? false;
          return canOpenHome ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}