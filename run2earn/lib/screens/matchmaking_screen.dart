import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/queue_service.dart';
import '../services/match_service.dart';
import 'preview_screen.dart';

class MatchMakingScreen extends StatefulWidget {
  final int min;

  const MatchMakingScreen(this.min, {Key? key}) : super(key: key);

  @override
  State<MatchMakingScreen> createState() => _MatchMakingScreenState();
}

class _MatchMakingScreenState extends State<MatchMakingScreen>
    with TickerProviderStateMixin { // Changed to TickerProviderStateMixin for multiple controllers

  final QueueService queue = QueueService();
  final MatchService match = MatchService();

  Timer? _timer;
  Timer? _poller;

  late AnimationController _anim;
  late AnimationController _pulseController; // Added specific controller
  late Animation<double> _glowAnim;
  late Animation<double> _pulseAnim;

  int players = 0;
  int seconds = 20;

  bool requested = false;
  final int maxPlayers = 4;

  @override
  void initState() {
    super.initState();

    queue.join(widget.min);

    // Rotation and Glow Controller
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(
        parent: _anim,
        curve: Curves.easeInOut,
      ),
    );

    // Pulse Controller Fix
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);

    _startTimer();
    _startPolling();
  }

  void _startTimer() {
    _timer?.cancel();
    seconds = 20;

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        seconds--;
        if (seconds <= 0) t.cancel();
      });
    });
  }

  void _startPolling() {
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 2), (_) {
      if (requested) return;
      if (players >= maxPlayers) {
        _create();
      } else if (players >= 2 && seconds <= 0) {
        _create();
      }
    });
  }

  void _create() {
    if (requested) return;
    requested = true;
    match.tryCreate(widget.min);
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _queue() {
    return FirebaseFirestore.instance
        .collection("queues")
        .doc("${widget.min}")
        .collection("users")
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _listenMatch() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return FirebaseFirestore.instance
        .collection("matches")
        .where("players", arrayContains: uid)
        .snapshots();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _poller?.cancel();
    queue.leave(widget.min);
    _anim.dispose();
    _pulseController.dispose(); // Properly dispose the pulse controller
    super.dispose();
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
                _header(),
                const SizedBox(height: 30),
                _statusCard(),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _queue(),
                    builder: (c, snap) {
                      final docs = snap.data?.docs ?? [];
                      players = docs.length;
                      return _matchmakingRadar(docs);
                    },
                  ),
                ),
                _progressSection(),
                const SizedBox(height: 40),
              ],
            ),
          ),
          _matchListener(),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.purple.withOpacity(0.3),
                ],
              ),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Spacer(),
          const Text(
            "MATCHMAKING",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _statusCard() {
    String status = "SEARCHING";
    Color statusColor = Colors.blueAccent;

    if (players >= maxPlayers) {
      status = "STARTING";
      statusColor = Colors.greenAccent;
    } else if (players >= 2 && seconds <= 0) {
      status = "FINALIZING";
      statusColor = Colors.orangeAccent;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 30),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.05),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnim,
            child: Text(
              "$players / $maxPlayers",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              Text(
                status,
                style: TextStyle(color: statusColor, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 10),
              Text("($seconds s)", style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _matchmakingRadar(List docs) {
    return Center(
      child: SizedBox(
        width: 320,
        height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            _radarCircles(),
            _sweepRadar(),
            _orbitalPlayers(docs),
            _centerHub(),
          ],
        ),
      ),
    );
  }

  Widget _orbitalPlayers(List docs) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Stack(
          children: List.generate(maxPlayers, (i) {
            final filled = i < docs.length;
            const r = 130.0;
            final a = (i * 2 * pi / maxPlayers) + (_anim.value * 2 * pi);
            final x = 160 + r * cos(a) - 28;
            final y = 160 + r * sin(a) - 28;

            return Positioned(
              left: x,
              top: y,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: filled ? Colors.blueAccent : Colors.white10,
                  border: Border.all(color: filled ? Colors.white : Colors.white24),
                ),
                child: Icon(Icons.person, color: filled ? Colors.white : Colors.white24),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _sweepRadar() {
    return RotationTransition(
      turns: _anim,
      child: Container(
        width: 320,
        height: 320,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(
            colors: [
              Colors.transparent,
              Colors.blueAccent.withOpacity(0.2),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _centerHub() {
    return FadeTransition(
      opacity: _glowAnim,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blueAccent,
        ),
        child: const Icon(Icons.search, color: Colors.white),
      ),
    );
  }

  Widget _progressSection() {
    double progress = (players / maxPlayers).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.white10,
            color: Colors.cyanAccent,
            minHeight: 8,
          ),
          const SizedBox(height: 10),
          const Text("Waiting for players...", style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _matchListener() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _listenMatch(),
      builder: (c, snap) {
        if (snap.hasData && snap.data!.docs.isNotEmpty) {
          final doc = snap.data!.docs.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => PreviewScreen(doc.id)),
            );
          });
        }
        return const SizedBox();
      },
    );
  }

  Widget _backgroundGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0E21), Color(0xFF1A237E)],
        ),
      ),
    );
  }

  Widget _radarCircles() {
    return CustomPaint(
      size: const Size(320, 320),
      painter: _RadarPainter(),
    );
  }
}

class _RadarPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final center = Offset(s.width / 2, s.height / 2);
    final p = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 4; i++) {
      c.drawCircle(center, (s.width / 2) * i / 4, p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}