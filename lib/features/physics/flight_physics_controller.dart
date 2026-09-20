import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Kinematic State Modes for Anti-Gravity Movement Physics
enum KinematicState {
  groundTraction, // 1.0G, friction: 0.82
  zeroGSubOrbitalGlide, // -0.4G, friction: 0.985
}

/// Single particle for anti-gravity micro-thruster slipstream visual effects
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

/// Anti-Gravity Movement Physics, Kinematics & Flight Telemetry Controller
class FlightPhysicsController extends ChangeNotifier {
  static final FlightPhysicsController _instance = FlightPhysicsController._internal();
  factory FlightPhysicsController() => _instance;

  FlightPhysicsController._internal();

  // Kinematic Physics Constants
  static const double groundGravity = 9.81; // 1.0G (m/s²)
  static const double zeroGGravity = -3.924; // -0.4G upward sub-orbital lift (m/s²)
  static const double groundFriction = 0.82; // Ground traction coefficient
  static const double zeroGFriction = 0.985; // Low-drag sub-orbital glide coefficient
  static const double minHoverAltitudeMeters = 2.5; // Hovering floor
  static const double maxHoverAltitudeMeters = 15.0; // Hovering sub-orbital ceiling
  static const double maxFlightCeilingMeters = 85.0; // Terminal flight ceiling

  // State
  KinematicState _kinematicState = KinematicState.groundTraction;
  bool _isThrusterEngaged = false;
  double _altitude = 0.0; // Meters (0.0 to 85.0m)
  double _verticalVelocity = 0.0; // m/s
  double _forwardVelocity = 0.0; // m/s
  double _energy = 100.0; // Quantum Flux Energy Battery (0% - 100%)
  bool _momentumBoostActive = false;
  double _pitchDeg = 0.0; // Gyroscope pitch tilt (-25° to +25°)
  double _rollDeg = 0.0; // Gyroscope roll tilt (-25° to +25°)
  double _runningCadenceSpM = 0.0; // Steps per minute for battery cadence recharge

  Timer? _physicsTimer;
  DateTime? _lastTick;

  // Particle micro-thruster buffer
  final List<SlipstreamParticle> particles = [];
  final math.Random _rng = math.Random.secure();

  KinematicState get kinematicState => _kinematicState;
  bool get isThrusterEngaged => _isThrusterEngaged;
  double get altitude => _altitude;
  double get verticalVelocity => _verticalVelocity;
  double get forwardVelocity => _forwardVelocity;
  double get energy => _energy;
  bool get isAirborne => _altitude >= 1.5 || _kinematicState == KinematicState.zeroGSubOrbitalGlide;
  bool get momentumBoostActive => _momentumBoostActive;
  double get pitchDeg => _pitchDeg;
  double get rollDeg => _rollDeg;
  double get friction => _kinematicState == KinematicState.zeroGSubOrbitalGlide ? zeroGFriction : groundFriction;

  /// 1.5x Multiplier for XP & Territory points while in Zero-G / Airborne
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

  /// Engages or disengages Zero-G sub-orbital glide thrusters
  void setThruster(bool active, {double currentRunSpeedMps = 3.5}) {
    if (_isThrusterEngaged != active) {
      _isThrusterEngaged = active;

      if (active && _energy > 5.0) {
        _kinematicState = KinematicState.zeroGSubOrbitalGlide;
        // Momentum Conservation: Convert sprint kinetic energy into +40% forward glide velocity boost
        _forwardVelocity = (currentRunSpeedMps > 0 ? currentRunSpeedMps : 3.5) * 1.40;
        _momentumBoostActive = true;
        HapticFeedback.heavyImpact();
      } else {
        _kinematicState = KinematicState.groundTraction;
        _momentumBoostActive = false;
        HapticFeedback.lightImpact();
      }
      notifyListeners();
    }
  }

  /// Recharges Quantum Flux battery (e.g. on territory loop closure or cadence)
  void rechargeEnergy(double amount) {
    _energy = (_energy + amount).clamp(0.0, 100.0);
    notifyListeners();
  }

  /// Updates live runner cadence for kinetic ground battery recharge
  void updateCadence(double stepsPerMinute) {
    _runningCadenceSpM = stepsPerMinute;
  }

  /// Updates gyroscope 6DOF attitude orientation (Pitch and Roll)
  void updateGyroscopeOrientation(double pitch, double roll) {
    _pitchDeg = pitch.clamp(-25.0, 25.0);
    _rollDeg = roll.clamp(-25.0, 25.0);
    notifyListeners();
  }

  void _tick() {
    final now = DateTime.now();
    final double dt = _lastTick != null ? (now.difference(_lastTick!).inMilliseconds / 1000.0).clamp(0.01, 0.1) : 0.033;
    _lastTick = now;

    if (_kinematicState == KinematicState.zeroGSubOrbitalGlide && _energy > 0) {
      // 1. Quantum Flux battery depletion: 1.8% per second
      _energy = (_energy - (1.8 * dt)).clamp(0.0, 100.0);

      if (_energy <= 0.0) {
        _kinematicState = KinematicState.groundTraction;
        _isThrusterEngaged = false;
        _momentumBoostActive = false;
        HapticFeedback.vibrate();
      }

      // 2. Harmonic vertical hovering damping towards target (between 2.5m - 15m)
      const double targetHoverAltitude = 8.5; // Mid-point of 2.5m - 15m range
      final double altitudeError = targetHoverAltitude - _altitude;
      const double springK = 3.2;
      const double dampingC = 1.8;
      final double springForce = (springK * altitudeError) - (dampingC * _verticalVelocity);

      // Apply -0.4G upward kinematic lift + spring hover damping
      _verticalVelocity += (-zeroGGravity + springForce) * dt;
      _verticalVelocity = _verticalVelocity.clamp(-8.0, 12.0);

      // Apply low-drag glide friction (0.985)
      _forwardVelocity *= math.pow(zeroGFriction, dt * 30.0);

      _spawnMicroThrusterParticles();
    } else {
      // Ground Traction Mode: 1.0G gravity descent
      _verticalVelocity = (_verticalVelocity - (groundGravity * dt)).clamp(-15.0, 15.0);

      // Kinetic battery recharge on ground (cadence based recharge: ~2.5% per sec)
      final double cadenceBoost = _runningCadenceSpM > 60 ? (_runningCadenceSpM / 160.0) * 2.5 : 1.2;
      _energy = (_energy + (cadenceBoost * dt)).clamp(0.0, 100.0);

      // Ground friction (0.82)
      _forwardVelocity *= math.pow(groundFriction, dt * 30.0);
      _momentumBoostActive = false;
    }

    // Integrate vertical altitude
    _altitude = (_altitude + (_verticalVelocity * dt)).clamp(0.0, maxFlightCeilingMeters);

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

  void _spawnMicroThrusterParticles() {
    for (int i = 0; i < 3; i++) {
      particles.add(
        SlipstreamParticle(
          x: 0.5 + (_rng.nextDouble() - 0.5) * 0.15,
          y: 0.90 + (_rng.nextDouble() * 0.08),
          vx: (_rng.nextDouble() - 0.5) * 0.015,
          vy: -(_rng.nextDouble() * 0.05 + 0.025),
          size: _rng.nextDouble() * 4.5 + 2.5,
          opacity: 0.90,
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

/// Custom canvas painter for anti-gravity micro-thruster slipstream particles
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

      // Trailing micro-thruster speed streak
      final tailPaint = Paint()
        ..color = p.color.withValues(alpha: p.opacity * 0.55)
        ..strokeWidth = p.size * 0.85
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        center,
        Offset(center.dx - (p.vx * size.width * 10), center.dy - (p.vy * size.height * 10)),
        tailPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SlipstreamPainter oldDelegate) => true;
}
