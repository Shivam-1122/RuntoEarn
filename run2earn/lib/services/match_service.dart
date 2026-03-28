import 'package:cloud_firestore/cloud_firestore.dart';

class MatchService {
  final _db = FirebaseFirestore.instance;

  Future<void> tryCreate(int min) async {

    final ref = FirebaseFirestore.instance
        .collection("queues")
        .doc("$min")
        .collection("users");

    final snap = await ref.get();

    if (snap.docs.length < 2) return;

    final players =
    snap.docs.map((e)=>e.id).toList();

    final match =
    FirebaseFirestore.instance
        .collection("matches")
        .doc();

    await match.set({

      "players": players,
      "duration": min,

      "status": "preview", // IMPORTANT

      "createdAt": FieldValue.serverTimestamp(),
    });

    for(final d in snap.docs){
      await d.reference.delete();
    }

    await FirebaseFirestore.instance
        .collection("queues")
        .doc("$min")
        .update({
      "timerStart": FieldValue.delete(),
    });
  }
}
