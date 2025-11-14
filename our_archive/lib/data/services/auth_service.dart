import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  String? get currentUserId => _auth.currentUser?.uid;

  // Week 1: Anonymous auth
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  // Week 2: Email/Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user profile
    await _firestore.collection('users').doc(credential.user!.uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'households': [],
    });

    return credential;
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Link anonymous to permanent
  Future<void> linkAnonymousToEmail(String email, String password) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw Exception('No anonymous user to link');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.linkWithCredential(credential);

    // Update user profile
    await _firestore.collection('users').doc(user.uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'households': [],
    }, SetOptions(merge: true));
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
