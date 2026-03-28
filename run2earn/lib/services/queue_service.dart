import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QueueService {

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ================= JOIN QUEUE =================

  Future<void> join(int minutes) async {

    final String uid = _auth.currentUser!.uid;

    final queueRef = _db.collection("queues").doc("$minutes");

    final userRef = queueRef.collection("users").doc(uid);

    // Ensure queue document exists
    await queueRef.set({
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Add / Update user
    await userRef.set({
      "uid": uid,
      "joinedAt": FieldValue.serverTimestamp(),
      "active": true,
    }, SetOptions(merge: true));
  }

  // ================= LEAVE QUEUE =================

  Future<void> leave(int minutes) async {

    final String uid = _auth.currentUser!.uid;

    final userRef = _db
        .collection("queues")
        .doc("$minutes")
        .collection("users")
        .doc(uid);

    await userRef.delete();
  }

  // ================= HEARTBEAT (OPTIONAL) =================
  // Call every 10–15s if you want auto-cleanup later

  Future<void> heartbeat(int minutes) async {

    final String uid = _auth.currentUser!.uid;

    final userRef = _db
        .collection("queues")
        .doc("$minutes")
        .collection("users")
        .doc(uid);

    await userRef.update({
      "lastSeen": FieldValue.serverTimestamp(),
      "active": true,
    });
  }

  // ================= CLEANUP (ADMIN / CRON) =================
  // Remove users inactive for 60s+

  Future<void> cleanup(int minutes) async {

    final snap = await _db
        .collection("queues")
        .doc("$minutes")
        .collection("users")
        .get();

    final now = DateTime.now();

    for (var doc in snap.docs) {

      final ts = doc["lastSeen"];

      if (ts == null) continue;

      final last = ts.toDate();

      if (now.difference(last).inSeconds > 60) {
        await doc.reference.delete();
      }
    }
  }
}
