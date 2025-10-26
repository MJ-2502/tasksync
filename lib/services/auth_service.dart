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

      // ✅ Automatically handle pending invites after signup
      await _handlePendingInvites(email);

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

      // Automatically handle pending invites after login
      await _handlePendingInvites(email);

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

// lib/services/auth_service.dart

Future<void> _handlePendingInvites(String email) async {
  final user = _auth.currentUser;
  if (user == null) return;

  final invitesSnapshot = await _firestore
      .collection('project_invites')
      .where('email', isEqualTo: email.toLowerCase())
      .get();

  if (invitesSnapshot.docs.isEmpty) return;

  for (var invite in invitesSnapshot.docs) {
    final data = invite.data();
    final projectId = data['projectId'];
    if (projectId == null) continue;

    final projectRef = _firestore.collection('projects').doc(projectId);

    try {
      // Attempt to join directly without prior read
      await projectRef.update({
        'memberIds': FieldValue.arrayUnion([user.uid])
      });

      await invite.reference.delete();
      ("✅ User ${user.email} joined project $projectId");
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        ("⚠️ Skipped project $projectId (no permission yet)");
      } else {
        ("❌ Error adding to project $projectId: ${e.message}");
      }
    }
  }
}

}
