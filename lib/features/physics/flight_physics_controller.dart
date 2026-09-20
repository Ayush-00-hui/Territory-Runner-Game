import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single particle for anti-gravity slipstream visual effects
class SlipstreamParticle {
  double x;
  double y;
  double vx;
  double vy;
  double size;
  double opacity;
  Color color;

  SlipstreamParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.opacity,
    required this.color,
  });

  void update() {
    x += vx;
    y += vy;
    opacity = (opacity - 0.035).clamp(0.0, 1.0);
  }

  bool get isDead => opacity <= 0.0;
}

/// Anti-Gravity Flight Physics & Telemetry Controller
class FlightPhysicsController extends ChangeNotifier {
  static final FlightPhysicsController _instance = FlightPhysicsController._internal();
  factory FlightPhysicsController() => _instance;

  FlightPhysicsController._internal();

  // Physics Constants
  static const double gravity = 9.81; // m/s²
  static const double invertedGravityAccel = -3.43; // -0.35g upward acceleration (m/s²)
  static const double maxAltitudeMeters = 85.0; // Flight ceiling
  static const double terminalDescentSpeed = 12.0; // m/s
  static const double maxClimbSpeed = 18.0; // m/s

  // State
  bool _isThrusterEngaged = false;
  double _altitude = 0.0; // Current altitude in meters (0 to 85m)
  double _verticalVelocity = 0.0; // m/s
  double _energy = 100.0; // 0 to 100%
  Timer? _physicsTimer;
  DateTime? _lastTick;

  // Particle slipstream buffer
  final List<SlipstreamParticle> particles = [];
  final math.Random _rng = math.Random.secure();

  bool get isThrusterEngaged => _isThrusterEngaged;
  double get altitude => _altitude;
  double get verticalVelocity => _verticalVelocity;
  double get energy => _energy;
  bool get isAirborne => _altitude > 1.5;

  /// 1.5x Multiplier for XP & Territory points while airborne
  double get conquestMultiplier => isAirborne ? 1.5 : 1.0;

  void startPhysicsLoop() {
    _physicsTimer?.cancel();
    _lastTick = DateTime.now();
    _physicsTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
  }

  void stopPhysicsLoop() {
    _physicsTimer?.cancel();
    _physicsTimer = null;
  }

  /// Engages thruster (e.g. Hold-to-Glide or Toggle)
  void setThruster(bool active) {
    if (_isThrusterEngaged != active) {
      _isThrusterEngaged = active;
      if (active) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
      notifyListeners();
    }
  }

  void _tick() {
    final now = DateTime.now();
    final double dt = _lastTick != null ? (now.difference(_lastTick!).inMilliseconds / 1000.0).clamp(0.01, 0.1) : 0.033;
    _lastTick = now;

    if (_isThrusterEngaged && _energy > 0) {
      // Apply inverted gravity acceleration
      _verticalVelocity = (_verticalVelocity - (invertedGravityAccel * 3.5 * dt)).clamp(-terminalDescentSpeed, maxClimbSpeed);
      // Deplete thruster energy
      _energy = (_energy - (15.0 * dt)).clamp(0.0, 100.0);
      if (_energy <= 0) {
        _isThrusterEngaged = false;
        HapticFeedback.vibrate();
      }
      _spawnSlipstreamParticles();
    } else {
      // Normal gravitational descent
      _verticalVelocity = (_verticalVelocity - (gravity * dt)).clamp(-terminalDescentSpeed, maxClimbSpeed);
      // Recharge energy when thrusters are off
      _energy = (_energy + (20.0 * dt)).clamp(0.0, 100.0);
    }

    // Integrate altitude
    _altitude = (_altitude + (_verticalVelocity * dt)).clamp(0.0, maxAltitudeMeters);

    if (_altitude <= 0.0) {
      _altitude = 0.0;
      _verticalVelocity = 0.0;
    }

    // Update slipstream particles
    for (int i = particles.length - 1; i >= 0; i--) {
      particles[i].update();
      if (particles[i].isDead) {
        particles.removeAt(i);
      }
    }

    notifyListeners();
  }

  void _spawnSlipstreamParticles() {
    for (int i = 0; i < 3; i++) {
      particles.add(
        SlipstreamParticle(
          x: _rng.nextDouble(),
          y: 0.95 + (_rng.nextDouble() * 0.05),
          vx: (_rng.nextDouble() - 0.5) * 0.01,
          vy: -(_rng.nextDouble() * 0.04 + 0.02),
          size: _rng.nextDouble() * 4.0 + 2.0,
          opacity: 0.85,
          color: _rng.nextBool() ? const Color(0xFF00F0FF) : const Color(0xFF8A2BE2),
        ),
      );
    }
  }

  @override
  void dispose() {
    stopPhysicsLoop();
    super.dispose();
  }
}

/// Custom canvas painter for anti-gravity slipstream particles
class SlipstreamPainter extends CustomPainter {
  final List<SlipstreamParticle> particles;
  SlipstreamPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      final center = Offset(p.x * size.width, p.y * size.height);
      canvas.drawCircle(center, p.size, paint);

      // Trailing speed streak
      final tailPaint = Paint()
        ..color = p.color.withValues(alpha: p.opacity * 0.5)
        ..strokeWidth = p.size * 0.8
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center,
        Offset(center.dx - (p.vx * size.width * 8), center.dy - (p.vy * size.height * 8)),
        tailPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SlipstreamPainter oldDelegate) => true;
}

