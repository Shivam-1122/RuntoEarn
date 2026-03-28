import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'home_screen.dart';
import 'login_screen.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  Future<void> _createUser(String uid) async {
    final ref =
    FirebaseFirestore.instance.collection("users").doc(uid);

    final snap = await ref.get();

    if (!snap.exists) {
      await ref.set({
        "createdAt": FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (c, snap) {
        if (snap.connectionState ==
            ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snap.hasData) {
          _createUser(snap.data!.uid);
          return HomeScreen();
        }

        return LoginScreen();
      },
    );
  }
}
