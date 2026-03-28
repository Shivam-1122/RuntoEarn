import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import 'result_screen.dart';

class RunScreen extends StatefulWidget {
  final String matchId;

  const RunScreen(this.matchId, {super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> with SingleTickerProviderStateMixin {
  final uid = FirebaseAuth.instance.currentUser!.uid;

  StreamSubscription<Position>? _gps;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  double distance = 0;
  Position? last;
  double? caloriesBurned = 0;
  double? averageSpeed = 0;

  int seconds = 0;
  int totalSeconds = 0;
  bool started = false;
  bool finished = false;
  bool _isPaused = false;

  List<double> _paceHistory = [];
  String? _currentPace = "0:00";

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _init();
  }

  // ================= INIT =================

  Future<void> _init() async {
    final match = await FirebaseFirestore.instance
        .collection("matches")
        .doc(widget.matchId)
        .get();

    final min = match["duration"];
    totalSeconds = min * 60;
    seconds = totalSeconds;

    await _startGPS();
    _startTimer();
  }

  // ================= GPS =================

  Future<void> _startGPS() async {
    var perm = await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.deniedForever) {
      _showLocationError();
      return;
    }

    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (_isPaused) return;

      double? newDistance = 0;
      if (last != null) {
        newDistance = Geolocator.distanceBetween(
          last!.latitude,
          last!.longitude,
          pos.latitude,
          pos.longitude,
        );
        distance += newDistance;

        // Calculate pace (min/km)
        if (newDistance > 0) {
          final speed = pos.speed;
          if (speed > 0) {
            final paceSeconds = 1000 / speed; // seconds per km
            final paceMinutes = paceSeconds ~/ 60;
            final paceSecs = paceSeconds % 60;
            _currentPace = "${paceMinutes}:${paceSecs.toString().padLeft(2, '0')}";

            _paceHistory.add(speed);
            if (_paceHistory.length > 10) {
              _paceHistory.removeAt(0);
            }
            averageSpeed = _paceHistory.isNotEmpty
                ? _paceHistory.reduce((a, b) => a + b) / _paceHistory.length
                : 0;
          }
        }

        // Calculate calories (simplified: 60 cal per km)
        caloriesBurned = distance / 1000 * 60;
      }

      last = pos;

      // Save live distance
      FirebaseFirestore.instance
          .collection("runs")
          .doc("${widget.matchId}_$uid")
          .set({
        "uid": uid,
        "matchId": widget.matchId,
        "distance": distance,
        "calories": caloriesBurned,
        "averageSpeed": averageSpeed,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      if (mounted) setState(() {});
    });
  }

  void _showLocationError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Location permission is required for running tracking'),
        backgroundColor: Colors.redAccent.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ================= TIMER =================

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || finished || _isPaused) return;

      setState(() {
        seconds--;

        if (seconds <= 0) {
          finish();
        }
      });
    });
  }

  // ================= PAUSE/RESUME =================

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      if (_isPaused) {
        _pulseController.stop();
      } else {
        _pulseController.repeat(reverse: true);
      }
    });
  }

  // ================= FINISH =================

  Future<void> finish() async {
    if (finished) return;

    finished = true;

    _timer?.cancel();
    _gps?.cancel();

    await FirebaseFirestore.instance
        .collection("matches")
        .doc(widget.matchId)
        .update({
      "status": "finished",
      "endedAt": FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => ResultScreen(widget.matchId),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // ================= EXIT =================

  Future<void> exitMatch() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1D1E33),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Exit Run?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to exit? Your progress will be lost.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.cyanAccent),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              finish();
            },
            child: const Text(
              'Exit',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _gps?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    final progress = 1 - (seconds / totalSeconds);
    final distanceKm = distance / 1000;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),

      body: Stack(
        children: [

          _backgroundGradient(),

          SafeArea(
            child: Column(
              children: [

                _header(),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        const SizedBox(height: 20),

                        // Time Progress Circle
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isPaused ? 1.0 : _pulseAnimation.value,
                              child: child,
                            );
                          },
                          child: CircularPercentIndicator(
                            radius: 140,
                            lineWidth: 15,
                            percent: progress.clamp(0.0, 1.0),
                            center: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [

                                Text(
                                  "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}",
                                  style: GoogleFonts.orbitron(
                                    fontSize: 42,
                                    fontWeight: FontWeight.bold,
                                    color: _isPaused ? Colors.white60 : Colors.white,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  _isPaused ? "PAUSED" : "TIME REMAINING",
                                  style: TextStyle(
                                    color: _isPaused ? Colors.orangeAccent : Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            progressColor: _isPaused
                                ? Colors.orangeAccent
                                : LinearGradient(
                              colors: [
                                Colors.cyanAccent,
                                Colors.blueAccent,
                              ],
                            ).colors.first,
                            backgroundColor: Colors.white.withOpacity(0.1),
                            circularStrokeCap: CircularStrokeCap.round,
                            animation: true,
                            animationDuration: 1000,
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Main Stats
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.blueAccent.withOpacity(0.15),
                                Colors.purpleAccent.withOpacity(0.15),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [

                              _statCard(Icons.directions_run, "DISTANCE", "${distanceKm.toStringAsFixed(2)} km", Colors.cyanAccent),
                              _statCard(Icons.speed, "PACE", _currentPace ?? "0:00", Colors.greenAccent),
                              _statCard(Icons.local_fire_department, "CALORIES", "${caloriesBurned!.toStringAsFixed(0)} cal", Colors.orangeAccent),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Progress Bar
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: Colors.white.withOpacity(0.03),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                          child: Column(
                            children: [

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [

                                  Text(
                                    "RUN PROGRESS",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  Text(
                                    "${(progress * 100).toStringAsFixed(1)}%",
                                    style: TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),

                              Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(5),
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                child: Stack(
                                  children: [

                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 500),
                                      width: MediaQuery.of(context).size.width * 0.8 * progress,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(5),
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.cyanAccent,
                                            Colors.blueAccent,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.cyanAccent.withOpacity(0.4),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [

                            // Pause/Resume Button
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: _isPaused
                                      ? [
                                    Colors.greenAccent,
                                    Colors.cyanAccent,
                                  ]
                                      : [
                                    Colors.orangeAccent,
                                    Colors.yellowAccent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _isPaused
                                        ? Colors.greenAccent.withOpacity(0.4)
                                        : Colors.orangeAccent.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _isPaused ? Icons.play_arrow : Icons.pause,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: _togglePause,
                              ),
                            ),

                            const SizedBox(width: 30),

                            // Finish Button
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.greenAccent,
                                    Colors.cyanAccent,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(0.4),
                                    blurRadius: 15,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.flag,
                                  color: Colors.white,
                                  size: 32,
                                ),
                                onPressed: finish,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Status Message
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white.withOpacity(0.05),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              Icon(
                                _isPaused ? Icons.pause_circle_outline : Icons.directions_run,
                                color: _isPaused ? Colors.orangeAccent : Colors.cyanAccent,
                                size: 20,
                              ),

                              const SizedBox(width: 10),

                              Text(
                                _isPaused ? "Run Paused - Tap Play to Continue" : "Keep Going! You're Doing Great!",
                                style: TextStyle(
                                  color: _isPaused ? Colors.orangeAccent : Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueAccent.withOpacity(0.1),
            Colors.transparent,
          ],
        ),
      ),
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
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: exitMatch,
            ),
          ),

          const Spacer(),

          Text(
            "LIVE RUNNING",
            style: GoogleFonts.orbitron(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),

          const Spacer(),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  Colors.cyanAccent.withOpacity(0.2),
                  Colors.blueAccent.withOpacity(0.2),
                ],
              ),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Text(
              "LIVE",
              style: TextStyle(
                color: Colors.cyanAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(IconData icon, String title, String value, Color color) {
    return Column(
      children: [

        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                color.withOpacity(0.3),
                color.withOpacity(0.1),
              ],
            ),
            border: Border.all(
              color: color.withOpacity(0.4),
              width: 2,
            ),
          ),
          child: Icon(icon, color: color, size: 24),
        ),

        const SizedBox(height: 12),

        Text(
          title,
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 16,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _backgroundGradient() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              const Color(0xFF1A237E).withOpacity(0.4),
              const Color(0xFF0A0E21).withOpacity(0.6),
              const Color(0xFF0A0E21),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
        ),
        child: Opacity(
          opacity: 0.05,
          child: Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/grid_pattern.png"),
                repeat: ImageRepeat.repeat,
                scale: 2.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}