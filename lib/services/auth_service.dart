import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static bool _isInitialized = false;
  static String? _initializationError;

  static bool get isSupportedPlatform {
    if (kIsWeb) return true;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  static bool get isReady => _isInitialized;
  static bool get canUseFirebaseAuth => isSupportedPlatform && _isInitialized;
  static String? get initializationError => _initializationError;

  static Future<void> initialize() async {
    if (!isSupportedPlatform) {
      _isInitialized = false;
      _initializationError =
          'Firebase Auth is not supported on this platform. Use Guest mode or run the app on Android, iOS, macOS, or Web.';
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp()
            .timeout(const Duration(seconds: 10));
      }

      // Ensure Firebase Auth is ready by waiting a moment for initialization
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Verify Firebase Auth can be accessed
      final _ = _auth.currentUser;

      _isInitialized = true;
      _initializationError = null;
    } catch (e) {
      _isInitialized = false;
      _initializationError =
          'Firebase is not configured yet for this app. Add your Firebase config files (android/app/google-services.json) or run FlutterFire configure.';
      debugPrint('Firebase initialization failed: $e');
    }
  }

  static User? get currentUser => canUseFirebaseAuth ? _auth.currentUser : null;

  static Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureReady();
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: 'Sign in failed: ${e.toString()}',
      );
    }
  }

  static Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    _ensureReady();
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: 'Sign up failed: ${e.toString()}',
      );
    }
  }

  static Future<void> sendPasswordResetEmail({
    required String email,
  }) async {
    _ensureReady();
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'unknown-error',
        message: 'Password reset failed: ${e.toString()}',
      );
    }
  }

  static Future<void> signOut() async {
    if (!canUseFirebaseAuth) return;
    await _auth.signOut();
  }

  static void _ensureReady() {
    if (!canUseFirebaseAuth) {
      throw FirebaseAuthException(
        code: 'firebase-not-ready',
        message: _initializationError ??
            'Firebase Auth is not available. Please configure Firebase first.',
      );
    }
  }
}
