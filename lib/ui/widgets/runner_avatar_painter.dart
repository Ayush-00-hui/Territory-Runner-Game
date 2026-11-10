import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/runner_avatar.dart';
import '../../models/wardrobe_catalog.dart';
import '../../services/avatar_service.dart';
import '../theme/app_colors.dart';
import '../theme/wardrobe_colors.dart';

/// Interactive vector runner buddy widget powered by pure Flutter CustomPainter.
class AvatarWidget extends StatefulWidget {
  final RunnerAvatar? avatar;
  final double size;
  final bool isRunning;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  const AvatarWidget({
    super.key,
    this.avatar,
    this.size = 64.0,
    this.isRunning = false,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  State<AvatarWidget> createState() => _AvatarWidgetState();
}

class _AvatarWidgetState extends State<AvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _strideController;

  bool get _isTestEnv {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  void _startAnimation() {
    if (_isTestEnv) {
      _strideController.forward();
    } else {
      _strideController.repeat();
    }
  }

  @override
  void initState() {
    super.initState();
    _strideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 740),
    );

    if (widget.isRunning) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(covariant AvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRunning != oldWidget.isRunning) {
      if (widget.isRunning) {
        _startAnimation();
      } else {
        _strideController.stop();
        _strideController.reset();
      }
    }
  }

  @override
  void dispose() {
    _strideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget avatarCanvas(RunnerAvatar effectiveAvatar) {
      return CustomPaint(
        size: Size(widget.size, widget.size),
        painter: RunnerAvatarPainter(
          avatar: effectiveAvatar,
          progress: reduceMotion ? 0.0 : _strideController.value,
          isReadyPose:
              effectiveAvatar.isReadyPose || !widget.isRunning || reduceMotion,
        ),
      );
    }

    Widget content;
    if (widget.avatar != null) {
      content = reduceMotion
          ? avatarCanvas(widget.avatar!)
          : AnimatedBuilder(
              animation: _strideController,
              builder: (context, _) => avatarCanvas(widget.avatar!),
            );
    } else {
      content = ValueListenableBuilder<RunnerAvatar>(
        valueListenable: AvatarService.instance.avatarNotifier,
        builder: (context, liveAvatar, _) {
          return reduceMotion
              ? avatarCanvas(liveAvatar)
              : AnimatedBuilder(
                  animation: _strideController,
                  builder: (context, _) => avatarCanvas(liveAvatar),
                );
        },
      );
    }

    return Semantics(
      label: widget.semanticsLabel ?? 'Runner avatar. Tap to customize gear.',
      button: widget.onTap != null,
      container: true,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: content,
        ),
      ),
    );
  }
}

/// Sculpted 2.5D biomechanical runner painter with layered anatomical shading,
/// natural stride kinematics, garment silhouette detail, and track velocity cues.
class RunnerAvatarPainter extends CustomPainter {
  final RunnerAvatar avatar;
  final double progress;
  final bool isReadyPose;

  RunnerAvatarPainter({
    required this.avatar,
    required this.progress,
    required this.isReadyPose,
  });

  static Color _shade(Color c, double amount) =>
      Color.lerp(c, Colors.black, amount.clamp(0.0, 1.0)) ?? c;

  static Color _tint(Color c, double amount) =>
      Color.lerp(c, AppColors.textPrimary, amount.clamp(0.0, 1.0)) ?? c;

  static bool _isTankTop(String id) =>
      id.contains('singlet') || id.contains('tank') || id.contains('vest');

  static bool _isLongSleeveTop(String id) =>
      id.contains('long_sleeve') ||
      id.contains('windbreaker') ||
      id.contains('shell') ||
      id.contains('thermal');

  static bool _isFullTights(String id) =>
      id.contains('tights_thermal') ||
      id.contains('track_pants') ||
      id.contains('ultra_tights');

  static bool _isHalfTights(String id) =>
      id.contains('half_tights') || id.contains('aero_tights');

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0;
    final showStage = size.width >= 56.0;
    final showFineDetail = size.width >= 72.0;

    final skinBase = WardrobeCatalog.getToneColor(avatar.bodyToneId);
    final skinHighlight = _tint(skinBase, 0.16);
    final skinBack = _shade(skinBase, 0.24);

    final topItem = WardrobeCatalog.findById(avatar.topId);
    final bottomsItem = WardrobeCatalog.findById(avatar.bottomsId);
    final shoesItem = WardrobeCatalog.findById(avatar.shoesId);
    final headwearItem = WardrobeCatalog.findById(avatar.headwearId);
    final accessoryItem = WardrobeCatalog.findById(avatar.accessoryId);

    if (isReadyPose) {
      _paintReadyStance(
        canvas: canvas,
        s: s,
        showStage: showStage,
        showFineDetail: showFineDetail,
        skinBase: skinBase,
        skinHighlight: skinHighlight,
        skinBack: skinBack,
        topItem: topItem,
        bottomsItem: bottomsItem,
        shoesItem: shoesItem,
        headwearItem: headwearItem,
        accessoryItem: accessoryItem,
      );
    } else {
      _paintDynamicStride(
        canvas: canvas,
        s: s,
        showStage: showStage,
        showFineDetail: showFineDetail,
        skinBase: skinBase,
        skinHighlight: skinHighlight,
        skinBack: skinBack,
        topItem: topItem,
        bottomsItem: bottomsItem,
        shoesItem: shoesItem,
        headwearItem: headwearItem,
        accessoryItem: accessoryItem,
      );
    }
  }

  void _paintDynamicStride({
    required Canvas canvas,
    required double s,
    required bool showStage,
    required bool showFineDetail,
    required Color skinBase,
    required Color skinHighlight,
    required Color skinBack,
    required WardrobeItem topItem,
    required WardrobeItem bottomsItem,
    required WardrobeItem shoesItem,
    required WardrobeItem headwearItem,
    required WardrobeItem accessoryItem,
  }) {
    final theta = progress * 2.0 * math.pi;

    // Flight peak when theta is near 0/pi; mid-stance absorption when theta is near pi/2 or 3*pi/2.
    final flightWave = math.cos(theta * 2.0);
    final airborneFactor = ((flightWave + 1.0) * 0.5).clamp(0.0, 1.0);
    final hipX = (47.5 + math.sin(theta) * 0.8) * s;
    final hipY = (50.2 - flightWave * 2.5) * s;

    // Athletic sprint lean (~12 degrees forward with subtle cadence pulse)
    final torsoLean = 0.21 + 0.018 * math.cos(theta * 2.0);
    final torsoLen = 23.0 * s;
    final spineCurveOffset = Offset(-1.8 * s, 0.5 * s);
    final shoulderCenter = Offset(
      hipX + math.sin(torsoLean) * torsoLen,
      hipY - math.cos(torsoLean) * torsoLen,
    );

    // Subtle chest rotation across stride cycle
    final shoulderTwist = math.sin(theta) * 2.2 * s;
    final backShoulder = Offset(
      shoulderCenter.dx - shoulderTwist - 1.2 * s,
      shoulderCenter.dy + 0.8 * s,
    );
    final frontShoulder = Offset(
      shoulderCenter.dx + shoulderTwist + 1.0 * s,
      shoulderCenter.dy + 1.2 * s,
    );
    final neckTop = Offset(
      shoulderCenter.dx + math.sin(0.14) * 8.8 * s,
      shoulderCenter.dy - math.cos(0.14) * 8.8 * s,
    );

    // 1. Track Ground, Shadow & Speed Wake
    if (showStage) {
      _drawTrackEnvironment(
        canvas: canvas,
        s: s,
        groundY: 88.0 * s,
        centerX: hipX + 1.5 * s,
        airborneFactor: airborneFactor,
        accentColor: shoesItem.accentColor != Colors.transparent
            ? shoesItem.accentColor
            : AppColors.accent,
        progress: progress,
        isRunning: true,
        showFineDetail: showFineDetail,
      );
    }

    if (showFineDetail) {
      _drawVelocityWake(
        canvas: canvas,
        s: s,
        shoulder: shoulderCenter,
        hip: Offset(hipX, hipY),
        progress: progress,
        accentColor: topItem.accentColor,
      );
    }

    // 2. Back Arm (phase = theta)
    _drawStrideArm(
      canvas: canvas,
      s: s,
      shoulder: backShoulder,
      phi: theta,
      skinColor: skinBack,
      skinHighlight: skinBase,
      topItem: topItem,
      accessoryItem: accessoryItem,
      isBack: true,
      showFineDetail: showFineDetail,
    );

    // 3. Back Leg (phase = theta + pi)
    _drawStrideLeg(
      canvas: canvas,
      s: s,
      hip: Offset(hipX - 1.2 * s, hipY + 0.5 * s),
      phi: theta + math.pi,
      skinColor: skinBack,
      skinHighlight: skinBase,
      bottomsItem: bottomsItem,
      shoesItem: shoesItem,
      isBack: true,
      showFineDetail: showFineDetail,
    );

    // 4. Sculpted Athletic Torso & Waist
    _drawAthleticTorso(
      canvas: canvas,
      s: s,
      hip: Offset(hipX, hipY),
      shoulder: shoulderCenter,
      spineMidOffset: spineCurveOffset,
      leanAngle: torsoLean,
      skinColor: skinBase,
      topItem: topItem,
      bottomsItem: bottomsItem,
      accessoryItem: accessoryItem,
      showFineDetail: showFineDetail,
      isStanding: false,
    );

    // 5. Sculpted Head Profile & Headwear
    _drawProfileHead(
      canvas: canvas,
      s: s,
      shoulder: shoulderCenter,
      headCenter: neckTop,
      headTilt: 0.08 + 0.015 * flightWave,
      skinBase: skinBase,
      skinHighlight: skinHighlight,
      headwearItem: headwearItem,
      accessoryItem: accessoryItem,
      showFineDetail: showFineDetail,
      isStanding: false,
    );

    // 6. Front Leg (phase = theta)
    _drawStrideLeg(
      canvas: canvas,
      s: s,
      hip: Offset(hipX + 1.2 * s, hipY),
      phi: theta,
      skinColor: skinBase,
      skinHighlight: skinHighlight,
      bottomsItem: bottomsItem,
      shoesItem: shoesItem,
      isBack: false,
      showFineDetail: showFineDetail,
    );

    // 7. Front Arm (phase = theta + pi — contralateral athletic balance)
    _drawStrideArm(
      canvas: canvas,
      s: s,
      shoulder: frontShoulder,
      phi: theta + math.pi,
      skinColor: skinBase,
      skinHighlight: skinHighlight,
      topItem: topItem,
      accessoryItem: accessoryItem,
      isBack: false,
      showFineDetail: showFineDetail,
    );
  }

  void _paintReadyStance({
    required Canvas canvas,
    required double s,
    required bool showStage,
    required bool showFineDetail,
    required Color skinBase,
    required Color skinHighlight,
    required Color skinBack,
    required WardrobeItem topItem,
    required WardrobeItem bottomsItem,
    required WardrobeItem shoesItem,
    required WardrobeItem headwearItem,
    required WardrobeItem accessoryItem,
  }) {
    final hipX = 50.0 * s;
    final hipY = 51.0 * s;
    final shoulderCenter = Offset(hipX, hipY - 23.0 * s);
    final headCenter = Offset(hipX, shoulderCenter.dy - 9.0 * s);

    if (showStage) {
      _drawTrackEnvironment(
        canvas: canvas,
        s: s,
        groundY: 88.0 * s,
        centerX: hipX,
        airborneFactor: 0.15,
        accentColor: shoesItem.accentColor != Colors.transparent
            ? shoesItem.accentColor
            : AppColors.accent,
        progress: 0.0,
        isRunning: false,
        showFineDetail: showFineDetail,
      );
    }

    // Back arm (left, slightly shadowed in 3/4 stance)
    _drawStandingArm(
      canvas: canvas,
      s: s,
      shoulder: Offset(
        shoulderCenter.dx - 11.2 * s,
        shoulderCenter.dy + 2.2 * s,
      ),
      sideDir: -1.0,
      skinColor: skinBack,
      topItem: topItem,
      accessoryItem: accessoryItem,
      isBack: true,
    );

    // Athletic stance legs (shoulder-width poised stance)
    _drawStandingLeg(
      canvas: canvas,
      s: s,
      hip: Offset(hipX - 6.8 * s, hipY),
      kneeOffsetX: -1.6 * s,
      ankleOffsetX: -2.6 * s,
      skinColor: skinBack,
      bottomsItem: bottomsItem,
      shoesItem: shoesItem,
      isBack: true,
    );
    _drawStandingLeg(
      canvas: canvas,
      s: s,
      hip: Offset(hipX + 6.8 * s, hipY),
      kneeOffsetX: 1.6 * s,
      ankleOffsetX: 2.6 * s,
      skinColor: skinBase,
      bottomsItem: bottomsItem,
      shoesItem: shoesItem,
      isBack: false,
    );

    // Upright athletic chest & waist
    _drawAthleticTorso(
      canvas: canvas,
      s: s,
      hip: Offset(hipX, hipY),
      shoulder: shoulderCenter,
      spineMidOffset: Offset.zero,
      leanAngle: 0.0,
      skinColor: skinBase,
      topItem: topItem,
      bottomsItem: bottomsItem,
      accessoryItem: accessoryItem,
      showFineDetail: showFineDetail,
      isStanding: true,
    );

    // Front right arm
    _drawStandingArm(
      canvas: canvas,
      s: s,
      shoulder: Offset(
        shoulderCenter.dx + 11.2 * s,
        shoulderCenter.dy + 2.2 * s,
      ),
      sideDir: 1.0,
      skinColor: skinBase,
      topItem: topItem,
      accessoryItem: accessoryItem,
      isBack: false,
    );

    // Poised athletic head portrait
    _drawProfileHead(
      canvas: canvas,
      s: s,
      shoulder: shoulderCenter,
      headCenter: headCenter,
      headTilt: 0.0,
      skinBase: skinBase,
      skinHighlight: skinHighlight,
      headwearItem: headwearItem,
      accessoryItem: accessoryItem,
      showFineDetail: showFineDetail,
      isStanding: true,
    );
  }

  void _drawTrackEnvironment({
    required Canvas canvas,
    required double s,
    required double groundY,
    required double centerX,
    required double airborneFactor,
    required Color accentColor,
    required double progress,
    required bool isRunning,
    required bool showFineDetail,
  }) {
    // 1. Soft atmospheric ground horizon glow
    final horizonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.transparent,
          AppColors.border.withValues(alpha: 0.45),
          accentColor.withValues(alpha: 0.35),
          AppColors.border.withValues(alpha: 0.45),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(8 * s, groundY - 0.5 * s, 84 * s, 1 * s))
      ..strokeWidth = 0.8 * s;
    canvas.drawLine(
      Offset(8 * s, groundY),
      Offset(92 * s, groundY),
      horizonPaint,
    );

    // 2. Dynamic ground contact shadow shrinking & fading during airborne float
    final shadowWidth = (30.0 - airborneFactor * 9.5) * s;
    final shadowHeight = (4.8 - airborneFactor * 1.6) * s;
    final shadowAlpha = 0.48 - airborneFactor * 0.24;
    final shadowRect = Rect.fromCenter(
      center: Offset(centerX, groundY + 1.0 * s),
      width: shadowWidth,
      height: shadowHeight,
    );
    final shadowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.black.withValues(alpha: shadowAlpha),
          Colors.black.withValues(alpha: shadowAlpha * 0.4),
          Colors.transparent,
        ],
      ).createShader(shadowRect);
    canvas.drawOval(shadowRect, shadowPaint);

    // 3. Smooth scrolling track surface dashes for velocity sense
    if (isRunning && showFineDetail) {
      final trackDashPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.0 * s;
      for (var i = 0; i < 4; i++) {
        final rawPos = ((1.0 - progress + i * 0.25) % 1.0);
        final dashX = (14.0 + rawPos * 72.0) * s;
        final edgeFade = math.sin(rawPos * math.pi).clamp(0.0, 1.0);
        trackDashPaint.color = accentColor.withValues(alpha: 0.36 * edgeFade);
        canvas.drawLine(
          Offset(dashX, groundY + 3.2 * s),
          Offset(dashX + 7.0 * s, groundY + 3.2 * s),
          trackDashPaint,
        );
      }
    }
  }

  void _drawVelocityWake({
    required Canvas canvas,
    required double s,
    required Offset shoulder,
    required Offset hip,
    required double progress,
    required Color accentColor,
  }) {
    final wakeColor = accentColor == Colors.transparent
        ? AppColors.accent
        : accentColor;
    for (var i = 0; i < 3; i++) {
      final phase = (progress * 2.0 + i * 0.33) % 1.0;
      final fade = math.sin(phase * math.pi).clamp(0.0, 1.0);
      final baseY = i == 0
          ? shoulder.dy - 4.0 * s
          : (i == 1 ? shoulder.dy + 8.5 * s : hip.dy + 3.0 * s);
      final startX =
          (i == 0 ? shoulder.dx - 11.0 * s : hip.dx - 14.0 * s) -
          phase * 14.0 * s;
      final len = (10.0 + (1.0 - i * 0.18) * 6.0) * s;
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            wakeColor.withValues(alpha: 0.24 * fade),
            Colors.transparent,
          ],
        ).createShader(Rect.fromLTWH(startX - len, baseY - 1, len, 2))
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.1 * s;
      canvas.drawLine(
        Offset(startX - len, baseY),
        Offset(startX, baseY),
        paint,
      );
    }
  }

  /// Draws a tapered sculptural limb segment with rounded joint ends.
  void _drawTaperedLimb({
    required Canvas canvas,
    required Offset start,
    required Offset end,
    required double rStart,
    required double rEnd,
    required Color color,
    Color? highlightColor,
    double calfCurve = 0.0,
  }) {
    final delta = end - start;
    final dist = delta.distance;
    if (dist < 0.01) return;

    final dir = delta / dist;
    final perp = Offset(-dir.dy, dir.dx);

    final s1 = start + perp * rStart;
    final s2 = start - perp * rStart;
    final e1 = end + perp * rEnd;
    final e2 = end - perp * rEnd;

    final mid = Offset((start.dx + end.dx) * 0.5, (start.dy + end.dy) * 0.5);
    final midCurveBack = mid - perp * ((rStart + rEnd) * 0.52 + calfCurve);

    final limbPath = Path()
      ..moveTo(s1.dx, s1.dy)
      ..lineTo(e1.dx, e1.dy)
      ..quadraticBezierTo(
        end.dx + dir.dx * rEnd * 0.9,
        end.dy + dir.dy * rEnd * 0.9,
        e2.dx,
        e2.dy,
      )
      ..quadraticBezierTo(midCurveBack.dx, midCurveBack.dy, s2.dx, s2.dy)
      ..quadraticBezierTo(
        start.dx - dir.dx * rStart * 0.9,
        start.dy - dir.dy * rStart * 0.9,
        s1.dx,
        s1.dy,
      )
      ..close();

    final rect = Rect.fromPoints(start, end).inflate(rStart + rEnd);
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          highlightColor ?? _tint(color, 0.14),
          color,
          _shade(color, 0.18),
        ],
      ).createShader(rect);

    canvas.drawPath(limbPath, fillPaint);

    if (highlightColor != null) {
      final rimPaint = Paint()
        ..color = highlightColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = (rEnd * 0.42).clamp(0.6, 2.0);
      canvas.drawLine(
        start + perp * (rStart * 0.72),
        end + perp * (rEnd * 0.72),
        rimPaint,
      );
    }
  }

  void _drawAthleticTorso({
    required Canvas canvas,
    required double s,
    required Offset hip,
    required Offset shoulder,
    required Offset spineMidOffset,
    required double leanAngle,
    required Color skinColor,
    required WardrobeItem topItem,
    required WardrobeItem bottomsItem,
    required WardrobeItem accessoryItem,
    required bool showFineDetail,
    required bool isStanding,
  }) {
    final topColor = topItem.primaryColor;
    final topAccent = topItem.accentColor;
    final bottomsColor = bottomsItem.primaryColor;
    final bottomsAccent = bottomsItem.accentColor;

    final dir = shoulder - hip;
    final len = dir.distance;
    final u = len > 0.01 ? dir / len : const Offset(0, -1); // bottom -> top
    final right = Offset(-u.dy, u.dx); // chest forward/right normal

    final waistCenter = hip + u * (len * 0.22) + spineMidOffset * 0.3;
    final chestCenter = hip + u * (len * 0.78);

    final hipHalfW = (isStanding ? 9.6 : 7.8) * s;
    final waistHalfW = (isStanding ? 8.2 : 6.8) * s;
    final chestHalfW = (isStanding ? 11.4 : 9.4) * s;

    // 1. Torso jersey contoured body
    final topPath = Path()
      ..moveTo(
        hip.dx - right.dx * (hipHalfW * 0.92),
        hip.dy - right.dy * (hipHalfW * 0.92),
      )
      ..quadraticBezierTo(
        waistCenter.dx - right.dx * waistHalfW,
        waistCenter.dy - right.dy * waistHalfW,
        shoulder.dx - right.dx * chestHalfW,
        shoulder.dy - right.dy * chestHalfW,
      )
      // Neckline scoop
      ..quadraticBezierTo(
        shoulder.dx + u.dx * 2.4 * s,
        shoulder.dy + u.dy * 2.4 * s,
        shoulder.dx + right.dx * (chestHalfW * 0.92),
        shoulder.dy + right.dy * (chestHalfW * 0.92),
      )
      // Athletic chest / ribcage curve down front
      ..quadraticBezierTo(
        chestCenter.dx + right.dx * (chestHalfW * 1.06),
        chestCenter.dy + right.dy * (chestHalfW * 1.06),
        hip.dx + right.dx * (hipHalfW * 0.95),
        hip.dy + right.dy * (hipHalfW * 0.95),
      )
      ..close();

    final torsoBounds = topPath.getBounds().inflate(2 * s);
    final torsoPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [_tint(topColor, 0.16), topColor, _shade(topColor, 0.28)],
      ).createShader(torsoBounds);
    canvas.drawPath(topPath, torsoPaint);

    // Collar trim & athletic chest/side graphic
    if (_isTankTop(topItem.id)) {
      // Exposed shoulder strap accent
      final collarPaint = Paint()
        ..color = topAccent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.6 * s;
      canvas.drawLine(
        shoulder - right * (chestHalfW * 0.45) + u * 0.8 * s,
        shoulder + right * (chestHalfW * 0.45) + u * 0.8 * s,
        collarPaint,
      );
    } else {
      final collarPaint = Paint()
        ..color = topAccent
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.4 * s;
      canvas.drawArc(
        Rect.fromCenter(center: shoulder, width: 7.5 * s, height: 3.6 * s),
        0.15,
        math.pi - 0.3,
        false,
        collarPaint,
      );
    }

    // Dynamic diagonal chest/side stripe
    final stripePaint = Paint()
      ..color = topAccent.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.7 * s;
    canvas.drawLine(
      chestCenter + right * (chestHalfW * 0.72),
      waistCenter + right * (waistHalfW * 0.76),
      stripePaint,
    );

    if (showFineDetail && _isLongSleeveTop(topItem.id)) {
      // Front half-zip / storm seam line
      final seamPaint = Paint()
        ..color = topAccent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * s;
      canvas.drawLine(shoulder, chestCenter + right * 1.2 * s, seamPaint);
    }

    // 2. Sculpted Shorts / Tights Waistband & Pelvis Wrap
    final shortsPath = Path()
      ..moveTo(
        hip.dx - right.dx * (hipHalfW * 0.96),
        hip.dy - right.dy * (hipHalfW * 0.96) - u.dy * 2.2 * s,
      )
      ..lineTo(
        hip.dx + right.dx * (hipHalfW * 0.98),
        hip.dy + right.dy * (hipHalfW * 0.98) - u.dy * 2.2 * s,
      )
      ..lineTo(
        hip.dx + right.dx * (hipHalfW * 1.08) - u.dx * 7.2 * s,
        hip.dy + right.dy * (hipHalfW * 1.08) - u.dy * 7.2 * s,
      )
      ..lineTo(
        hip.dx - right.dx * (hipHalfW * 1.04) - u.dx * 7.2 * s,
        hip.dy - right.dy * (hipHalfW * 1.04) - u.dy * 7.2 * s,
      )
      ..close();

    final shortsPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          _tint(bottomsColor, 0.14),
          bottomsColor,
          _shade(bottomsColor, 0.25),
        ],
      ).createShader(shortsPath.getBounds().inflate(2 * s));
    canvas.drawPath(shortsPath, shortsPaint);

    // Waistband highlight stripe
    final waistBandPaint = Paint()
      ..color = bottomsAccent.withValues(alpha: 0.78)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s;
    canvas.drawLine(
      hip - right * (hipHalfW * 0.92) + u * 1.5 * s,
      hip + right * (hipHalfW * 0.94) + u * 1.5 * s,
      waistBandPaint,
    );

    // 3. Torso Accessories (Waistpack / Finisher Medal / Scout Beacon)
    if (accessoryItem.id.contains('waistpack')) {
      final packPaint = Paint()
        ..color = accessoryItem.primaryColor
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(hip.dx, hip.dy - 1.0 * s);
      canvas.rotate(leanAngle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 14.5 * s,
            height: 4.5 * s,
          ),
          Radius.circular(2.2 * s),
        ),
        packPaint,
      );
      canvas.restore();
    } else if (accessoryItem.id.contains('medal')) {
      final ribbonPaint = Paint()
        ..color = accessoryItem.accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 * s;
      canvas.drawLine(
        shoulder + right * 2.0 * s,
        chestCenter + right * 3.0 * s,
        ribbonPaint,
      );
      canvas.drawCircle(
        chestCenter + right * 3.0 * s,
        2.6 * s,
        Paint()..color = accessoryItem.primaryColor,
      );
    } else if (accessoryItem.id.contains('beacon') && showFineDetail) {
      canvas.drawCircle(
        chestCenter + right * (chestHalfW * 0.68),
        1.8 * s,
        Paint()..color = accessoryItem.accentColor,
      );
    }
  }

  void _drawProfileHead({
    required Canvas canvas,
    required double s,
    required Offset shoulder,
    required Offset headCenter,
    required double headTilt,
    required Color skinBase,
    required Color skinHighlight,
    required WardrobeItem headwearItem,
    required WardrobeItem accessoryItem,
    required bool showFineDetail,
    required bool isStanding,
  }) {
    // 1. Tapered muscular neck
    _drawTaperedLimb(
      canvas: canvas,
      start: shoulder,
      end: Offset(headCenter.dx, headCenter.dy + 4.5 * s),
      rStart: 3.3 * s,
      rEnd: 2.7 * s,
      color: _shade(skinBase, 0.12),
    );

    canvas.save();
    canvas.translate(headCenter.dx, headCenter.dy);
    canvas.rotate(headTilt);

    final headW = 6.3 * s;
    final headH = 7.4 * s;

    // 2. Sculpted cranium & jaw silhouette
    final headRect = Rect.fromCenter(
      center: Offset.zero,
      width: headW * 2.0,
      height: headH * 2.0,
    );
    final headPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.35, -0.25),
        radius: 1.0,
        colors: [skinHighlight, skinBase, _shade(skinBase, 0.22)],
      ).createShader(headRect);

    if (isStanding) {
      canvas.drawOval(headRect, headPaint);
    } else {
      // Dynamic forward profile with subtle nose & chin contour
      final profilePath = Path()
        ..moveTo(-headW * 0.85, -headH * 0.25)
        ..quadraticBezierTo(-headW * 0.85, -headH * 1.02, 0, -headH * 1.0)
        ..quadraticBezierTo(
          headW * 0.92,
          -headH * 0.96,
          headW * 0.96,
          -headH * 0.2,
        )
        // Nose bridge
        ..lineTo(headW * 1.16, headH * 0.08)
        ..lineTo(headW * 0.95, headH * 0.22)
        // Lips / Chin / Jawline
        ..quadraticBezierTo(
          headW * 0.88,
          headH * 0.88,
          headW * 0.1,
          headH * 0.98,
        )
        ..quadraticBezierTo(
          -headW * 0.72,
          headH * 0.92,
          -headW * 0.85,
          -headH * 0.25,
        )
        ..close();
      canvas.drawPath(profilePath, headPaint);
    }

    // Subtle facial brow/eye dot for expression
    if (showFineDetail && !accessoryItem.id.contains('shades')) {
      final eyeX = isStanding ? headW * 0.36 : headW * 0.52;
      canvas.drawCircle(
        Offset(eyeX, -headH * 0.15),
        0.95 * s,
        Paint()..color = WardrobeColors.c_FF181B20,
      );
      if (isStanding) {
        canvas.drawCircle(
          Offset(-headW * 0.36, -headH * 0.15),
          0.95 * s,
          Paint()..color = WardrobeColors.c_FF181B20,
        );
      }
    }

    // 3. Natural sculpted athletic hair crown (never cuts across face!)
    final hairColor =
        avatar.bodyToneId.contains('alabaster') ||
            avatar.bodyToneId.contains('peach')
        ? WardrobeColors.c_FF382721
        : WardrobeColors.c_FF121417;
    final hairPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [_tint(hairColor, 0.14), hairColor],
      ).createShader(headRect);

    final hairPath = Path()
      ..moveTo(-headW * 0.96, -headH * 0.1)
      ..quadraticBezierTo(
        -headW * 1.05,
        -headH * 1.12,
        -headW * 0.1,
        -headH * 1.14,
      )
      ..quadraticBezierTo(
        headW * 0.95,
        -headH * 1.10,
        headW * 0.98,
        -headH * 0.56,
      )
      ..quadraticBezierTo(
        headW * 0.52,
        -headH * 0.72,
        -headW * 0.25,
        -headH * 0.56,
      )
      ..quadraticBezierTo(
        -headW * 0.72,
        -headH * 0.35,
        -headW * 0.65,
        headH * 0.12,
      )
      ..quadraticBezierTo(
        -headW * 0.90,
        headH * 0.08,
        -headW * 0.96,
        -headH * 0.1,
      )
      ..close();
    canvas.drawPath(hairPath, hairPaint);

    // 4. Sculpted Headwear Layer
    if (headwearItem.id.contains('cap') || headwearItem.id.contains('visor')) {
      final crownColor = headwearItem.primaryColor;
      final trimColor = headwearItem.accentColor;

      if (!headwearItem.id.contains('visor')) {
        // 6-panel athletic cap crown
        final crownPath = Path()
          ..moveTo(-headW * 1.02, -headH * 0.36)
          ..quadraticBezierTo(-headW * 0.92, -headH * 1.24, 0, -headH * 1.20)
          ..quadraticBezierTo(
            headW * 0.92,
            -headH * 1.18,
            headW * 1.02,
            -headH * 0.42,
          )
          ..quadraticBezierTo(0, -headH * 0.52, -headW * 1.02, -headH * 0.36)
          ..close();
        canvas.drawPath(
          crownPath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                _tint(crownColor, 0.18),
                crownColor,
                _shade(crownColor, 0.22),
              ],
            ).createShader(crownPath.getBounds()),
        );
      } else {
        // Open-top visor band cleanly hugging forehead
        final visorBand = Path()
          ..moveTo(-headW * 0.98, -headH * 0.36)
          ..quadraticBezierTo(0, -headH * 0.68, headW * 0.98, -headH * 0.42)
          ..lineTo(headW * 0.98, -headH * 0.62)
          ..quadraticBezierTo(0, -headH * 0.88, -headW * 0.98, -headH * 0.54)
          ..close();
        canvas.drawPath(visorBand, Paint()..color = crownColor);
      }

      // Curved sleek visor bill + contrast underbill edge
      final billPath = Path()
        ..moveTo(headW * 0.62, -headH * 0.44)
        ..quadraticBezierTo(
          headW * 1.48,
          -headH * 0.40,
          headW * 1.82,
          -headH * 0.20,
        )
        ..quadraticBezierTo(
          headW * 1.25,
          -headH * 0.22,
          headW * 0.65,
          -headH * 0.30,
        )
        ..close();
      canvas.drawPath(billPath, Paint()..color = crownColor);
      canvas.drawLine(
        Offset(headW * 0.70, -headH * 0.29),
        Offset(headW * 1.76, -headH * 0.19),
        Paint()
          ..color = trimColor
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 0.9 * s,
      );
    } else if (headwearItem.id.contains('headband') ||
        headwearItem.id.contains('crown')) {
      final bandPath = Path()
        ..moveTo(-headW * 0.98, -headH * 0.34)
        ..quadraticBezierTo(0, -headH * 0.58, headW * 0.98, -headH * 0.40)
        ..lineTo(headW * 0.96, -headH * 0.64)
        ..quadraticBezierTo(0, -headH * 0.84, -headW * 0.96, -headH * 0.58)
        ..close();
      canvas.drawPath(bandPath, Paint()..color = headwearItem.primaryColor);
      canvas.drawLine(
        Offset(-headW * 0.85, -headH * 0.44),
        Offset(headW * 0.88, -headH * 0.49),
        Paint()
          ..color = headwearItem.accentColor.withValues(alpha: 0.75)
          ..strokeWidth = 0.9 * s,
      );
    } else if (headwearItem.id.contains('beanie')) {
      final beanieColor = headwearItem.primaryColor;
      final beaniePath = Path()
        ..moveTo(-headW * 1.04, -headH * 0.24)
        ..quadraticBezierTo(
          -headW * 1.02,
          -headH * 1.38,
          -headW * 0.08,
          -headH * 1.32,
        )
        ..quadraticBezierTo(
          headW * 0.95,
          -headH * 1.28,
          headW * 1.02,
          -headH * 0.38,
        )
        ..quadraticBezierTo(0, -headH * 0.54, -headW * 1.04, -headH * 0.24)
        ..close();
      canvas.drawPath(
        beaniePath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_tint(beanieColor, 0.18), beanieColor],
          ).createShader(beaniePath.getBounds()),
      );
      canvas.drawLine(
        Offset(-headW * 0.96, -headH * 0.32),
        Offset(headW * 0.96, -headH * 0.40),
        Paint()
          ..color = headwearItem.accentColor
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.6 * s,
      );
    }

    // 5. Wrap-around Sport Sunglasses
    if (accessoryItem.id.contains('shades')) {
      final lensRect = Rect.fromLTWH(
        isStanding ? -headW * 0.68 : headW * 0.08,
        -headH * 0.34,
        isStanding ? headW * 1.36 : headW * 1.00,
        headH * 0.38,
      );
      final shadesPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _tint(accessoryItem.primaryColor, 0.35),
            accessoryItem.primaryColor,
            _shade(accessoryItem.primaryColor, 0.25),
          ],
        ).createShader(lensRect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(lensRect, Radius.circular(1.5 * s)),
        shadesPaint,
      );
      // Ear temple arm
      canvas.drawLine(
        Offset(-headW * 0.55, -headH * 0.18),
        Offset(lensRect.left + 1.0 * s, -headH * 0.20),
        Paint()
          ..color = accessoryItem.accentColor
          ..strokeWidth = 1.1 * s,
      );
    }

    canvas.restore();
  }

  void _drawStrideLeg({
    required Canvas canvas,
    required double s,
    required Offset hip,
    required double phi,
    required Color skinColor,
    required Color skinHighlight,
    required WardrobeItem bottomsItem,
    required WardrobeItem shoesItem,
    required bool isBack,
    required bool showFineDetail,
  }) {
    final thighLen = 17.5 * s;
    final calfLen = 16.5 * s;

    // Anatomically grounded thigh sweep & strictly posterior knee flexion
    final thighAngle = 0.10 + 0.72 * math.cos(phi);
    final kneeBend = (0.78 - 0.62 * math.sin(phi - 0.25)).clamp(0.14, 1.48);
    final calfAngle = thighAngle - kneeBend;
    final footPitch = (-calfAngle * 0.62 - 0.08).clamp(-0.35, 0.95);

    final knee = Offset(
      hip.dx + math.sin(thighAngle) * thighLen,
      hip.dy + math.cos(thighAngle) * thighLen,
    );
    final ankle = Offset(
      knee.dx + math.sin(calfAngle) * calfLen,
      knee.dy + math.cos(calfAngle) * calfLen,
    );

    final effectiveBottoms = isBack
        ? _shade(bottomsItem.primaryColor, 0.28)
        : bottomsItem.primaryColor;
    final bottomsAccent = isBack
        ? _shade(bottomsItem.accentColor, 0.25)
        : bottomsItem.accentColor;

    // 1. Calf segment (covered if full tights / track pants)
    if (_isFullTights(bottomsItem.id)) {
      _drawTaperedLimb(
        canvas: canvas,
        start: knee,
        end: ankle,
        rStart: 3.6 * s,
        rEnd: 2.3 * s,
        color: effectiveBottoms,
        highlightColor: isBack ? null : _tint(effectiveBottoms, 0.18),
        calfCurve: 1.0 * s,
      );
      if (showFineDetail) {
        canvas.drawLine(
          knee,
          ankle,
          Paint()
            ..color = bottomsAccent.withValues(alpha: 0.75)
            ..strokeCap = StrokeCap.round
            ..strokeWidth = 1.0 * s,
        );
      }
    } else {
      _drawTaperedLimb(
        canvas: canvas,
        start: knee,
        end: ankle,
        rStart: 3.4 * s,
        rEnd: 2.0 * s,
        color: skinColor,
        highlightColor: isBack ? null : skinHighlight,
        calfCurve: 1.1 * s,
      );
    }

    // 2. Thigh segment (covered partially by shorts or fully by tights)
    final coverageFrac = _isFullTights(bottomsItem.id)
        ? 1.0
        : (_isHalfTights(bottomsItem.id) ? 0.84 : 0.56);
    _drawTaperedLimb(
      canvas: canvas,
      start: hip,
      end: knee,
      rStart: 5.2 * s,
      rEnd: 3.4 * s,
      color: skinColor,
      highlightColor: isBack ? null : skinHighlight,
    );

    final legEnd = Offset.lerp(hip, knee, coverageFrac)!;
    _drawTaperedLimb(
      canvas: canvas,
      start: hip,
      end: legEnd,
      rStart: 5.6 * s,
      rEnd: (coverageFrac > 0.7 ? 3.8 : 4.6) * s,
      color: effectiveBottoms,
      highlightColor: isBack ? null : _tint(effectiveBottoms, 0.16),
    );

    // 3. Sculpted Modern Running Shoe
    _drawModernShoe(
      canvas: canvas,
      s: s,
      ankle: ankle,
      footPitch: footPitch,
      shoesItem: shoesItem,
      isBack: isBack,
      showFineDetail: showFineDetail,
    );
  }

  void _drawStandingLeg({
    required Canvas canvas,
    required double s,
    required Offset hip,
    required double kneeOffsetX,
    required double ankleOffsetX,
    required Color skinColor,
    required WardrobeItem bottomsItem,
    required WardrobeItem shoesItem,
    required bool isBack,
  }) {
    final knee = Offset(hip.dx + kneeOffsetX, hip.dy + 17.5 * s);
    final ankle = Offset(hip.dx + ankleOffsetX, knee.dy + 16.5 * s);

    final bottomsColor = isBack
        ? _shade(bottomsItem.primaryColor, 0.24)
        : bottomsItem.primaryColor;

    if (_isFullTights(bottomsItem.id)) {
      _drawTaperedLimb(
        canvas: canvas,
        start: knee,
        end: ankle,
        rStart: 3.6 * s,
        rEnd: 2.3 * s,
        color: bottomsColor,
        calfCurve: 0.7 * s,
      );
    } else {
      _drawTaperedLimb(
        canvas: canvas,
        start: knee,
        end: ankle,
        rStart: 3.4 * s,
        rEnd: 2.1 * s,
        color: skinColor,
        calfCurve: 0.7 * s,
      );
    }

    _drawTaperedLimb(
      canvas: canvas,
      start: hip,
      end: knee,
      rStart: 5.2 * s,
      rEnd: 3.4 * s,
      color: skinColor,
    );

    final coverageFrac = _isFullTights(bottomsItem.id)
        ? 1.0
        : (_isHalfTights(bottomsItem.id) ? 0.85 : 0.58);
    _drawTaperedLimb(
      canvas: canvas,
      start: hip,
      end: Offset.lerp(hip, knee, coverageFrac)!,
      rStart: 5.6 * s,
      rEnd: 4.5 * s,
      color: bottomsColor,
    );

    _drawModernShoe(
      canvas: canvas,
      s: s,
      ankle: ankle,
      footPitch: isBack ? -0.05 : 0.05,
      shoesItem: shoesItem,
      isBack: isBack,
      showFineDetail: true,
    );
  }

  void _drawModernShoe({
    required Canvas canvas,
    required double s,
    required Offset ankle,
    required double footPitch,
    required WardrobeItem shoesItem,
    required bool isBack,
    required bool showFineDetail,
  }) {
    final upperColor = isBack
        ? _shade(shoesItem.primaryColor, 0.28)
        : shoesItem.primaryColor;
    final soleColor = isBack
        ? _shade(shoesItem.accentColor, 0.24)
        : shoesItem.accentColor;

    canvas.save();
    canvas.translate(ankle.dx, ankle.dy);
    canvas.rotate(footPitch);

    // Sculpted upper shoe profile
    final upperPath = Path()
      ..moveTo(-2.6 * s, -0.4 * s)
      ..lineTo(-3.2 * s, 2.2 * s)
      ..lineTo(7.4 * s, 2.2 * s)
      ..quadraticBezierTo(9.0 * s, 1.0 * s, 7.6 * s, 0.2 * s)
      ..lineTo(2.4 * s, -1.2 * s)
      ..quadraticBezierTo(0.4 * s, -1.8 * s, -2.0 * s, -1.6 * s)
      ..close();

    canvas.drawPath(
      upperPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_tint(upperColor, 0.16), upperColor],
        ).createShader(upperPath.getBounds()),
    );

    // Cushioned rocker midsole
    final midsolePath = Path()
      ..moveTo(-3.4 * s, 2.0 * s)
      ..lineTo(8.2 * s, 1.9 * s)
      ..quadraticBezierTo(9.0 * s, 2.7 * s, 7.2 * s, 3.2 * s)
      ..lineTo(-2.8 * s, 3.3 * s)
      ..quadraticBezierTo(-3.8 * s, 2.8 * s, -3.4 * s, 2.0 * s)
      ..close();
    canvas.drawPath(midsolePath, Paint()..color = soleColor);

    // Speed accent swoosh/collar detail
    if (showFineDetail) {
      canvas.drawLine(
        Offset(-0.6 * s, 0.6 * s),
        Offset(5.4 * s, 1.1 * s),
        Paint()
          ..color = soleColor.withValues(alpha: 0.85)
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.0 * s,
      );
    }

    canvas.restore();
  }

  void _drawStrideArm({
    required Canvas canvas,
    required double s,
    required Offset shoulder,
    required double phi,
    required Color skinColor,
    required Color skinHighlight,
    required WardrobeItem topItem,
    required WardrobeItem accessoryItem,
    required bool isBack,
    required bool showFineDetail,
  }) {
    final upperLen = 13.0 * s;
    final foreLen = 11.5 * s;

    final upperAngle = -0.06 + 0.66 * math.cos(phi);
    final elbowFlex = 1.46 + 0.20 * math.cos(phi);
    final foreAngle = upperAngle + elbowFlex;

    final elbow = Offset(
      shoulder.dx + math.sin(upperAngle) * upperLen,
      shoulder.dy + math.cos(upperAngle) * upperLen,
    );
    final hand = Offset(
      elbow.dx + math.sin(foreAngle) * foreLen,
      elbow.dy + math.cos(foreAngle) * foreLen,
    );

    final topColor = isBack
        ? _shade(topItem.primaryColor, 0.28)
        : topItem.primaryColor;
    final topAccent = isBack
        ? _shade(topItem.accentColor, 0.24)
        : topItem.accentColor;

    // Upper Arm (skin + sleeve if not sleeveless singlet)
    _drawTaperedLimb(
      canvas: canvas,
      start: shoulder,
      end: elbow,
      rStart: 3.1 * s,
      rEnd: 2.3 * s,
      color: skinColor,
      highlightColor: isBack ? null : skinHighlight,
    );

    // Forearm
    _drawTaperedLimb(
      canvas: canvas,
      start: elbow,
      end: hand,
      rStart: 2.3 * s,
      rEnd: 1.5 * s,
      color: skinColor,
      highlightColor: isBack ? null : skinHighlight,
    );

    // Sleeves based on equipped garment silhouette
    if (_isLongSleeveTop(topItem.id)) {
      _drawTaperedLimb(
        canvas: canvas,
        start: shoulder,
        end: elbow,
        rStart: 3.6 * s,
        rEnd: 2.8 * s,
        color: topColor,
      );
      _drawTaperedLimb(
        canvas: canvas,
        start: elbow,
        end: Offset.lerp(elbow, hand, 0.92)!,
        rStart: 2.8 * s,
        rEnd: 1.9 * s,
        color: topColor,
      );
    } else if (!_isTankTop(topItem.id)) {
      // Athletic raglan short sleeve
      _drawTaperedLimb(
        canvas: canvas,
        start: shoulder,
        end: Offset.lerp(shoulder, elbow, 0.55)!,
        rStart: 3.6 * s,
        rEnd: 2.9 * s,
        color: topColor,
        highlightColor: isBack ? null : _tint(topColor, 0.16),
      );
    } else {
      // Exposed athletic shoulder deltoid strap cap
      canvas.drawCircle(shoulder, 3.2 * s, Paint()..color = skinColor);
      canvas.drawCircle(
        shoulder + Offset(0, -1.0 * s),
        2.0 * s,
        Paint()..color = topColor,
      );
    }

    // Runner fist/hand
    canvas.drawCircle(hand, 2.0 * s, Paint()..color = skinColor);

    // Wrist / Arm Accessories
    _drawArmAccessory(
      canvas: canvas,
      s: s,
      shoulder: shoulder,
      elbow: elbow,
      hand: hand,
      accessoryItem: accessoryItem,
      isBack: isBack,
      topAccent: topAccent,
      showFineDetail: showFineDetail,
    );
  }

  void _drawStandingArm({
    required Canvas canvas,
    required double s,
    required Offset shoulder,
    required double sideDir,
    required Color skinColor,
    required WardrobeItem topItem,
    required WardrobeItem accessoryItem,
    required bool isBack,
  }) {
    final elbow = Offset(
      shoulder.dx + sideDir * 3.0 * s,
      shoulder.dy + 12.0 * s,
    );
    final hand = Offset(shoulder.dx + sideDir * 4.0 * s, elbow.dy + 11.5 * s);
    final topColor = isBack
        ? _shade(topItem.primaryColor, 0.24)
        : topItem.primaryColor;

    _drawTaperedLimb(
      canvas: canvas,
      start: shoulder,
      end: elbow,
      rStart: 3.1 * s,
      rEnd: 2.3 * s,
      color: skinColor,
    );
    _drawTaperedLimb(
      canvas: canvas,
      start: elbow,
      end: hand,
      rStart: 2.3 * s,
      rEnd: 1.5 * s,
      color: skinColor,
    );

    if (_isLongSleeveTop(topItem.id)) {
      _drawTaperedLimb(
        canvas: canvas,
        start: shoulder,
        end: elbow,
        rStart: 3.5 * s,
        rEnd: 2.7 * s,
        color: topColor,
      );
      _drawTaperedLimb(
        canvas: canvas,
        start: elbow,
        end: Offset.lerp(elbow, hand, 0.90)!,
        rStart: 2.7 * s,
        rEnd: 1.9 * s,
        color: topColor,
      );
    } else if (!_isTankTop(topItem.id)) {
      _drawTaperedLimb(
        canvas: canvas,
        start: shoulder,
        end: Offset.lerp(shoulder, elbow, 0.56)!,
        rStart: 3.6 * s,
        rEnd: 2.9 * s,
        color: topColor,
      );
    }

    canvas.drawCircle(hand, 2.0 * s, Paint()..color = skinColor);
    _drawArmAccessory(
      canvas: canvas,
      s: s,
      shoulder: shoulder,
      elbow: elbow,
      hand: hand,
      accessoryItem: accessoryItem,
      isBack: isBack,
      topAccent: topItem.accentColor,
      showFineDetail: true,
    );
  }

  void _drawArmAccessory({
    required Canvas canvas,
    required double s,
    required Offset shoulder,
    required Offset elbow,
    required Offset hand,
    required WardrobeItem accessoryItem,
    required bool isBack,
    required Color topAccent,
    required bool showFineDetail,
  }) {
    if (isBack) return;
    if (accessoryItem.id.contains('watch')) {
      final wrist = Offset.lerp(elbow, hand, 0.78)!;
      canvas.drawCircle(
        wrist,
        2.2 * s,
        Paint()..color = accessoryItem.primaryColor,
      );
      if (showFineDetail) {
        canvas.drawCircle(
          wrist,
          1.2 * s,
          Paint()..color = accessoryItem.accentColor,
        );
      }
    } else if (accessoryItem.id.contains('armband') ||
        accessoryItem.id.contains('hr_strap')) {
      final bicepMid = Offset.lerp(shoulder, elbow, 0.65)!;
      canvas.drawCircle(
        bicepMid,
        2.7 * s,
        Paint()..color = accessoryItem.primaryColor,
      );
      canvas.drawCircle(
        bicepMid,
        1.2 * s,
        Paint()..color = accessoryItem.accentColor,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RunnerAvatarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isReadyPose != isReadyPose ||
      oldDelegate.avatar != avatar;
}
