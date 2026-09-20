import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Invertible gravity modifiers for propulsion physics
enum GravityTier {
  standard(1.0, 9.81, 'Standard (1.0g)', Color(0xFF00E676)),
  lunar(0.16, 1.57, 'Lunar (0.16g)', Color(0xFF00F0FF)),
  zeroG(0.0, 0.0, 'Zero-G (0.0g)', Color(0xFFFF9100)),
  invertedBoost(-0.35, -3.43, 'Inverted Boost (-0.35g)', Color(0xFFFF3366));

  final double modifierG;
  final double accelerationMps2;
  final String label;
  final Color themeColor;

  const GravityTier(this.modifierG, this.accelerationMps2, this.label, this.themeColor);
}

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
  GravityTier _gravityTier = GravityTier.standard;
  bool _isThrusterEngaged = false;
  double _altitude = 0.0; // Meters (0.0 to 85.0m)
  double _verticalVelocity = 0.0; // m/s
  double _forwardVelocity = 0.0; // m/s
  double _energy = 100.0; // Quantum Flux Energy Battery (0% - 100%)
  bool _momentumBoostActive = false;
  double _pitchDeg = 0.0; // Gyroscope pitch tilt (-25° to +25°)
  double _rollDeg = 0.0; // Gyroscope roll tilt (-25° to +25°)
  double _runningCadenceSpM = 165.0; // Steps per minute for particle vector scaling

  Timer? _physicsTimer;
  DateTime? _lastTick;

  // Particle micro-thruster buffer
  final List<SlipstreamParticle> particles = [];
  final math.Random _rng = math.Random(42);

  KinematicState get kinematicState => _kinematicState;
  GravityTier get gravityTier => _gravityTier;
  bool get isThrusterEngaged => _isThrusterEngaged;
  double get altitude => _altitude;
  double get verticalVelocity => _verticalVelocity;
  double get forwardVelocity => _forwardVelocity;
  double get energy => _energy;
  bool get isAirborne => _altitude >= 1.5 || _kinematicState == KinematicState.zeroGSubOrbitalGlide || _gravityTier != GravityTier.standard;
  bool get momentumBoostActive => _momentumBoostActive;
  double get pitchDeg => _pitchDeg;
  double get rollDeg => _rollDeg;
  double get runningCadenceSpM => _runningCadenceSpM;
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

  /// Changes the active gravity modifier tier
  void setGravityTier(GravityTier tier) {
    _gravityTier = tier;
    if (tier == GravityTier.zeroG || tier == GravityTier.invertedBoost) {
      _kinematicState = KinematicState.zeroGSubOrbitalGlide;
    } else {
      if (!_isThrusterEngaged) {
        _kinematicState = KinematicState.groundTraction;
      }
    }
    notifyListeners();
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

  /// Updates device orientation tilt angles from 6DOF sensors
  void updateDeviceOrientation({required double pitchDeg, required double rollDeg}) {
    _pitchDeg = pitchDeg.clamp(-35.0, 35.0);
    _rollDeg = rollDeg.clamp(-35.0, 35.0);
    notifyListeners();
  }

  /// Updates runner cadence for particle emission and energy generation
  void updateCadence(double spm) {
    _runningCadenceSpM = spm.clamp(0.0, 240.0);
    if (_runningCadenceSpM > 150.0) {
      rechargeEnergy(0.05); // Continuous recharge on high cadence
    }
  }

  /// Recharges Quantum Flux battery (e.g. from territory capture or running cadence)
  void rechargeEnergy(double amount) {
    _energy = (_energy + amount).clamp(0.0, 100.0);
    notifyListeners();
  }

  void _tick() {
    final now = DateTime.now();
    final dt = (_lastTick != null ? (now.difference(_lastTick!).inMilliseconds / 1000.0) : 0.033).clamp(0.01, 0.1);
    _lastTick = now;

    // 1. Quantum Flux Battery Dynamics
    if (_isThrusterEngaged || _gravityTier == GravityTier.invertedBoost) {
      _energy = (_energy - (1.8 * dt)).clamp(0.0, 100.0);
      if (_energy <= 0.0) {
        setThruster(false);
      }
    } else {
      // Slow passive battery recovery
      _energy = (_energy + (0.4 * dt)).clamp(0.0, 100.0);
    }

    // 2. Vertical Kinematics & Gravity Calculations
    if (_isThrusterEngaged || _gravityTier == GravityTier.invertedBoost) {
      // Sub-orbital ascent with pitch coupling
      final double pitchLift = math.sin(_pitchDeg * math.pi / 180.0) * 2.0;
      final double targetLiftAccel = -zeroGGravity + pitchLift;
      _verticalVelocity += (targetLiftAccel * dt);

      // Dampen vertical velocity as altitude reaches hover ceiling (15m)
      if (_altitude > maxHoverAltitudeMeters) {
        _verticalVelocity *= 0.88;
      }
      _altitude = (_altitude + (_verticalVelocity * dt)).clamp(0.0, maxFlightCeilingMeters);
    } else if (_gravityTier == GravityTier.lunar) {
      // Lunar low gravity
      _verticalVelocity -= (GravityTier.lunar.accelerationMps2 * dt);
      _altitude = (_altitude + (_verticalVelocity * dt)).clamp(0.0, maxFlightCeilingMeters);
      if (_altitude <= 0.0) {
        _altitude = 0.0;
        _verticalVelocity = 0.0;
      }
    } else if (_gravityTier == GravityTier.zeroG) {
      // Zero-G drift
      _verticalVelocity *= 0.95;
      _altitude = (_altitude + (_verticalVelocity * dt)).clamp(2.5, maxFlightCeilingMeters);
    } else {
      // Standard ground gravity descent (1.0G)
      if (_altitude > 0.0) {
        _verticalVelocity -= (groundGravity * dt);
        _altitude = (_altitude + (_verticalVelocity * dt)).clamp(0.0, maxFlightCeilingMeters);
        if (_altitude <= 0.0) {
          _altitude = 0.0;
          _verticalVelocity = 0.0;
          _kinematicState = KinematicState.groundTraction;
        }
      }
    }

    // 3. Forward Velocity & Atmospheric Drag Decay
    if (_momentumBoostActive) {
      // Atmospheric drag decay (drag factor based on current gravity mode)
      final double dragFactor = _kinematicState == KinematicState.zeroGSubOrbitalGlide ? 0.995 : 0.96;
      _forwardVelocity *= dragFactor;
      if (_forwardVelocity < 3.5) {
        _momentumBoostActive = false;
      }
    }

    // 4. Vector Particle Field Emission
    _updateParticles(dt);

    notifyListeners();
  }

  void _updateParticles(double dt) {
    // Spawn particles when moving or airborne, scaled to runner cadence
    final int spawnCount = isAirborne ? 3 : (_runningCadenceSpM > 140 ? 2 : 1);
    for (int i = 0; i < spawnCount; i++) {
      final double pAngle = (_rollDeg * math.pi / 180.0) + ((_rng.nextDouble() - 0.5) * 0.8);
      final double speed = (_rng.nextDouble() * 3.0 + 1.5);
      particles.add(
        SlipstreamParticle(
          x: (_rng.nextDouble() - 0.5) * 40.0,
          y: (_rng.nextDouble() - 0.5) * 20.0,
          vx: -math.sin(pAngle) * speed,
          vy: math.cos(pAngle) * speed,
          size: _rng.nextDouble() * 4.0 + 2.0,
          opacity: 0.85,
          color: isAirborne ? _gravityTier.themeColor : const Color(0xFF00F0FF),
        ),
      );
    }

    for (final p in particles) {
      p.update();
    }
    particles.removeWhere((p) => p.isDead);
    if (particles.length > 60) {
      particles.removeRange(0, particles.length - 60);
    }
  }
}
