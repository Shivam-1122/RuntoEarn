import 'dart:async';
import 'package:geolocator/geolocator.dart';

class GPSService {

  Position? _last;

  double _distance = 0; // meters
  double _speed = 0;    // m/s

  DateTime? _startTime;


  // ================= INIT =================

  Future<bool> init() async {

    bool enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) return false;

    LocationPermission perm =
    await Geolocator.checkPermission();

    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }


  // ================= START =================

  void start() {

    _last = null;
    _distance = 0;
    _speed = 0;
    _startTime = DateTime.now();
  }


  // ================= STREAM =================

  Stream<Position> stream() {

    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }


  // ================= UPDATE =================

  void update(Position p) {

    if (_last != null) {

      final d = Geolocator.distanceBetween(
        _last!.latitude,
        _last!.longitude,
        p.latitude,
        p.longitude,
      );

      // Filter GPS jumps (anti-cheat basic)
      if (d < 50) {
        _distance += d;
      }
    }

    _last = p;

    _calculateSpeed();
  }


  // ================= SPEED =================

  void _calculateSpeed() {

    if (_startTime == null || _distance <= 0) return;

    final sec =
        DateTime.now().difference(_startTime!).inSeconds;

    if (sec <= 0) return;

    _speed = _distance / sec;
  }


  // ================= GETTERS =================

  double get distance => _distance; // meters

  double get distanceKm => _distance / 1000;

  double get speed => _speed; // m/s

  double get speedKmh => _speed * 3.6;


  // ================= STOP =================

  void stop() {
    _last = null;
  }
}
