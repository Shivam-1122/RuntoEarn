import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/payment_service.dart';
import 'run_screen.dart';

class PreviewScreen extends StatefulWidget {
  final String matchId;

  const PreviewScreen(this.matchId, {super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen>
    with SingleTickerProviderStateMixin {
  bool paying = false;
  bool paid = false;

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final pay = PaymentService();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation =
        Tween<double>(begin: 0.95, end: 1).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ================= PAY =================

  Future<void> _pay(int min) async {
    if (paying) return;

    setState(() => paying = true);

    await pay.pay(min);

    setState(() {
      paying = false;
      paid = true;
    });
  }

  // ================= START =================

  void _start() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RunScreen(widget.matchId),
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),

      body: SafeArea(
        child: Column(
          children: [

            _header(),

            Expanded(
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection("matches")
                    .doc(widget.matchId)
                    .snapshots(),

                builder: (c, snap) {

                  if (!snap.hasData) {
                    return _loading();
                  }

                  if (!snap.data!.exists) {
                    return _error("Match not found");
                  }

                  final data = snap.data!.data()!;
                  final players =
                  List<String>.from(data["players"] ?? []);

                  final int duration = data["duration"] ?? 10;
                  final double fee = pay.getFee(duration);

                  return LayoutBuilder(
                    builder: (context, constraints) {

                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),

                        padding: const EdgeInsets.all(20),

                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),

                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              _summary(duration, fee, players.length),

                              const SizedBox(height: 20),

                              _countdown(),

                              const SizedBox(height: 20),

                              _players(players),

                              const SizedBox(height: 30),

                              paid
                                  ? _startButton()
                                  : _payButton(duration),

                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================= HEADER =================

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.all(16),

      child: Row(
        children: [

          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),

          const Spacer(),

          Text(
            "MATCH LOBBY",
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }

  // ================= SUMMARY =================

  Widget _summary(int min, double fee, int count) {
    return Card(
      color: Colors.white10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,

          children: [

            _stat("STAKE", "$fee"),

            _stat("TIME", "$min MIN"),

            _stat(
              "POOL",
              (fee * count).toStringAsFixed(2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String t, String v) {
    return Column(
      children: [

        Text(
          t,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          v,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ================= COUNTDOWN =================

  Widget _countdown() {
    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,

        children: const [

          Icon(Icons.timer, color: Colors.orange),

          SizedBox(width: 8),

          Text(
            "Match starting soon",
            style: TextStyle(
              color: Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ================= PLAYERS =================

  Widget _players(List<String> players) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,

      children: [

        Text(
          "PLAYERS (${players.length}/4)",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (players.isEmpty)
          _emptyPlayers(),

        if (players.isNotEmpty)
          ListView.builder(
            itemCount: players.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),

            itemBuilder: (c, i) {

              final id = players[i];
              final me = id == uid;

              return _playerTile(id, me);
            },
          ),
      ],
    );
  }

  Widget _playerTile(String id, bool me) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),

      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),

      child: ListTile(

        leading: CircleAvatar(
          backgroundColor: Colors.blueAccent,
          child: Icon(
            me ? Icons.person : Icons.person_outline,
            color: Colors.white,
          ),
        ),

        title: Text(
          me ? "YOU" : id.substring(0, 6),
          style: const TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),

        trailing: Chip(
          backgroundColor:
          paid ? Colors.green : Colors.orange,

          label: Text(
            paid ? "PAID" : "WAIT",
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _emptyPlayers() {
    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),

      child: const Center(
        child: Text(
          "Waiting for players...",
          style: TextStyle(color: Colors.white54),
        ),
      ),
    );
  }

  // ================= BUTTONS =================

  Widget _payButton(int min) {
    return AnimatedBuilder(
      animation: _pulseAnimation,

      builder: (c, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: child,
        );
      },

      child: SizedBox(
        width: double.infinity,
        height: 50,

        child: ElevatedButton(
          onPressed: paying ? null : () => _pay(min),

          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),

          child: paying
              ? const CircularProgressIndicator(
            color: Colors.white,
          )
              : const Text(
            "PAY ENTRY",
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _startButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,

      child: ElevatedButton(
        onPressed: _start,

        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),

        child: const Text(
          "START RUN",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ================= STATES =================

  Widget _loading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _error(String msg) {
    return Center(
      child: Text(
        msg,
        style: const TextStyle(color: Colors.white),
      ),
    );
  }
}
