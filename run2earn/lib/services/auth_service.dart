import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= LOGIN =================

  Future<User?> login(
      String email,
      String password,
      ) async {

    try {

      final res = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      return res.user;

    } catch (e) {
      rethrow;
    }
  }

  // ================= REGISTER =================

  Future<User?> register(
      String email,
      String password,
      ) async {

    try {

      final res = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = res.user;

      if (user == null) return null;

      // Create User Profile
      await _db.collection("users").doc(user.uid).set({

        "email": email.trim(),

        // Fake wallet (for now)
        "balance": 5.0,

        "createdAt": FieldValue.serverTimestamp(),

        "wallet": null,

        "totalWins": 0,
        "totalMatches": 0,

      });

      return user;

    } catch (e) {
      rethrow;
    }
  }

  // ================= CURRENT USER =================

  User? get user => _auth.currentUser;

  // ================= LOGOUT =================

  Future<void> logout() async {
    await _auth.signOut();
  }
}
