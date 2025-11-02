import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Sign up with email, password & name ---
  Future<User?> signUp(String email, String password, String displayName) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // ✅ Set display name in Firebase Auth
      await result.user!.updateDisplayName(displayName);

      // ✅ Create Firestore user document
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email.toLowerCase(),
        'displayName': displayName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return result.user;
    } catch (e) {
      print("❌ SignUp Error: $e");
      return null;
    }
  }

  // --- Log in with email & password ---
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      return result.user;
    } catch (e) {
      print("❌ Login Error: $e");
      return null;
    }
  }

  // --- Send password reset email ---
  Future<PasswordResetResult> sendPasswordResetEmail(String email) async {
    try {
      // Firebase Auth will check if email exists automatically
      await _auth.sendPasswordResetEmail(email: email.trim());

      return PasswordResetResult(
        success: true,
        message: 'Password reset email sent! Check your inbox.',
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'invalid-email':
          message = 'Invalid email address format.';
          break;
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'too-many-requests':
          message = 'Too many requests. Please try again later.';
          break;
        default:
          message = 'An error occurred. Please try again.';
      }
      return PasswordResetResult(success: false, message: message);
    } catch (e) {
      print("❌ Password Reset Error: $e");
      return PasswordResetResult(
        success: false,
        message: 'Failed to send reset email. Please try again.',
      );
    }
  }

  // --- Verify password reset code ---
  Future<bool> verifyPasswordResetCode(String code) async {
    try {
      await _auth.verifyPasswordResetCode(code);
      return true;
    } catch (e) {
      print("❌ Verify Reset Code Error: $e");
      return false;
    }
  }

  // --- Confirm password reset with code ---
  Future<PasswordResetResult> confirmPasswordReset(String code, String newPassword) async {
    try {
      await _auth.confirmPasswordReset(code: code, newPassword: newPassword);
      return PasswordResetResult(
        success: true,
        message: 'Password reset successful! You can now log in.',
      );
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'expired-action-code':
          message = 'Reset code has expired. Please request a new one.';
          break;
        case 'invalid-action-code':
          message = 'Invalid reset code. Please try again.';
          break;
        case 'weak-password':
          message = 'Password is too weak. Use at least 6 characters.';
          break;
        default:
          message = 'Failed to reset password. Please try again.';
      }
      return PasswordResetResult(success: false, message: message);
    }
  }

  // --- Log out ---
  Future<void> logout() async {
    await _auth.signOut();
  }

  // --- Get current user (real-time stream) ---
  Stream<User?> get userStream => _auth.authStateChanges();
}

// Result class for password reset operations
class PasswordResetResult {
  final bool success;
  final String message;

  PasswordResetResult({
    required this.success,
    required this.message,
  });
}