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
      ("❌ SignUp Error: $e");
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
      ("❌ Login Error: $e");
      return null;
    }
  }

  // --- Log out ---
  Future<void> logout() async {
    await _auth.signOut();
  }

  // --- Get current user (real-time stream) ---
  Stream<User?> get userStream => _auth.authStateChanges();
}
