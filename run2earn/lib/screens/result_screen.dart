import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultScreen extends StatelessWidget {
  final String matchId;

  const ResultScreen(this.matchId, {super.key});

  // Helper to generate dummy data for testing/fallback
  List<QueryDocumentSnapshot> _generateMockDocs() {
    final List<Map<String, dynamic>> mockData = [
      {"uid": "user_crypto_king", "distance": 5420.0, "matchId": matchId},
      {"uid": "user_runner_pro", "distance": 4800.0, "matchId": matchId},
      {"uid": "user_fast_walker", "distance": 3200.0, "matchId": matchId},
      {"uid": "user_lazy_jogger", "distance": 1500.0, "matchId": matchId},
    ];

    return mockData.map((data) => MockQueryDocumentSnapshot(data)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: Stack(
        children: [
          _backgroundGradient(),
          SafeArea(
            child: Column(
              children: [
                _header(context),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection("runs")
                        .where("matchId", isEqualTo: matchId)
                        .orderBy("distance", descending: true)
                        .snapshots(),
                    builder: (c, snap) {
                      // Logic: Use real data if available, otherwise use dummy data
                      List<QueryDocumentSnapshot> docs = [];
                      if (snap.hasData && snap.data!.docs.isNotEmpty) {
                        docs = snap.data!.docs;
                      } else {
                        docs = _generateMockDocs();
                      }

                      final winner = docs.first;

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            _winnerBanner(winner),
                            const SizedBox(height: 30),
                            _resultsHeader(docs.length),
                            const SizedBox(height: 20),
                            _leaderboard(docs),
                            const SizedBox(height: 30),
                            _statsSummary(docs),
                            const SizedBox(height: 40),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            "MATCH RESULTS",
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
        ],
      ),
    );
  }

  Widget _winnerBanner(QueryDocumentSnapshot? winner) {
    if (winner == null) return const SizedBox();

    final distance = (winner["distance"] as double) / 1000;
    final playerId = winner["uid"].toString();
    final reward = distance * 0.1;

    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9800), Color(0xFFFFC107)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          const CircleAvatar(
            radius: 35,
            backgroundColor: Colors.white24,
            child: Icon(Icons.workspace_premium, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 15),
          Text(
            "CHAMPION",
            style: GoogleFonts.orbitron(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            "ID: ${playerId.substring(0, 8).toUpperCase()}",
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _winnerStat("DISTANCE", "${distance.toStringAsFixed(2)} km"),
              _winnerStat("REWARD", "${reward.toStringAsFixed(2)} MON"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _winnerStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _resultsHeader(int count) {
    return Text(
      "$count PLAYERS FINISHED",
      style: GoogleFonts.orbitron(color: Colors.cyanAccent, fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  Widget _leaderboard(List<QueryDocumentSnapshot> docs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (c, i) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
        itemBuilder: (c, i) => _leaderboardItem(docs[i], i),
      ),
    );
  }

  Widget _leaderboardItem(QueryDocumentSnapshot doc, int index) {
    final distance = (doc["distance"] as double) / 1000;
    final reward = distance * 0.1;
    final isTop = index < 3;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isTop ? Colors.amber : Colors.white10,
        child: Text("${index + 1}", style: const TextStyle(color: Colors.white)),
      ),
      title: Text(
        "Player ${doc["uid"].toString().substring(0, 6)}",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      subtitle: Text("${distance.toStringAsFixed(2)} km", style: const TextStyle(color: Colors.white54)),
      trailing: Text(
        "+${reward.toStringAsFixed(2)} MON",
        style: GoogleFonts.orbitron(color: Colors.greenAccent, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _statsSummary(List<QueryDocumentSnapshot> docs) {
    final totalKm = docs.fold<double>(0, (sum, doc) => sum + (doc["distance"] / 1000));
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _miniStat("TOTAL KM", totalKm.toStringAsFixed(1)),
          _miniStat("AVG KM", (totalKm / docs.length).toStringAsFixed(1)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
        Text(val, style: const TextStyle(color: Colors.cyanAccent, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _backgroundGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topLeft,
          radius: 1.0,
          colors: [Color(0xFF1A237E), Color(0xFF0A0E21)],
        ),
      ),
    );
  }
}

// ================= MOCKING ENGINE =================
// This mimics a Firestore document so your UI doesn't know the difference.
class MockQueryDocumentSnapshot implements QueryDocumentSnapshot {
  final Map<String, dynamic> _data;
  MockQueryDocumentSnapshot(this._data);

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic operator [](Object field) => _data[field];

  @override
  String get id => "mock_${Random().nextInt(999)}";

  @override
  bool get exists => true;

  @override
  DocumentReference get reference => throw UnimplementedError();

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  dynamic get(Object field) => _data[field];
}