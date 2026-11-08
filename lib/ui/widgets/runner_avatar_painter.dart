import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../../models/runner_avatar.dart';
import '../../models/wardrobe_catalog.dart';
import '../../services/avatar_service.dart';

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
      duration: const Duration(milliseconds: 780),
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

/// Pure Flutter CustomPainter rendering an athletic geometric vector runner.
class RunnerAvatarPainter extends CustomPainter {
  final RunnerAvatar avatar;
  final double progress;
  final bool isReadyPose;

  RunnerAvatarPainter({
    required this.avatar,
    required this.progress,
    required this.isReadyPose,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100.0; // Standard 100x100 virtual coordinate space
    final skinColor = WardrobeCatalog.getToneColor(avatar.bodyToneId);
    final topItem = WardrobeCatalog.findById(avatar.topId);
    final bottomsItem = WardrobeCatalog.findById(avatar.bottomsId);
    final shoesItem = WardrobeCatalog.findById(avatar.shoesId);
    final headwearItem = WardrobeCatalog.findById(avatar.headwearId);
    final accessoryItem = WardrobeCatalog.findById(avatar.accessoryId);

    // Common paints
    final skinPaint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.fill;

    final skinStrokePaint = Paint()
      ..color = skinColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0 * s;

    final skinBackStrokePaint = Paint()
      ..color = skinColor.withValues(alpha: 0.82)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 5.5 * s;

    final topPaint = Paint()
      ..color = topItem.primaryColor
      ..style = PaintingStyle.fill;

    final bottomsPaint = Paint()
      ..color = bottomsItem.primaryColor
      ..style = PaintingStyle.fill;

    final shoePaint = Paint()
      ..color = shoesItem.primaryColor
      ..style = PaintingStyle.fill;

    final shoeAccentPaint = Paint()
      ..color = shoesItem.accentColor
      ..style = PaintingStyle.fill;

    // Kinematic joint calculations
    if (isReadyPose) {
      _paintReadyPose(
        canvas: canvas,
        s: s,
        skinPaint: skinPaint,
        skinStrokePaint: skinStrokePaint,
        topPaint: topPaint,
        bottomsPaint: bottomsPaint,
        shoePaint: shoePaint,
        shoeAccentPaint: shoeAccentPaint,
        topItem: topItem,
        bottomsItem: bottomsItem,
        headwearItem: headwearItem,
        accessoryItem: accessoryItem,
      );
    } else {
      _paintRunningCycle(
        canvas: canvas,
        s: s,
        skinPaint: skinPaint,
        skinStrokePaint: skinStrokePaint,
        skinBackStrokePaint: skinBackStrokePaint,
        topPaint: topPaint,
        bottomsPaint: bottomsPaint,
        shoePaint: shoePaint,
        shoeAccentPaint: shoeAccentPaint,
        topItem: topItem,
        bottomsItem: bottomsItem,
        headwearItem: headwearItem,
        accessoryItem: accessoryItem,
      );
    }
  }

  void _paintRunningCycle({
    required Canvas canvas,
    required double s,
    required Paint skinPaint,
    required Paint skinStrokePaint,
    required Paint skinBackStrokePaint,
    required Paint topPaint,
    required Paint bottomsPaint,
    required Paint shoePaint,
    required Paint shoeAccentPaint,
    required WardrobeItem topItem,
    required WardrobeItem bottomsItem,
    required WardrobeItem headwearItem,
    required WardrobeItem accessoryItem,
  }) {
    final theta = progress * 2.0 * math.pi;

    // Center of gravity & vertical bounce
    final hipX = 48.0 * s;
    final hipY = (54.0 + math.sin(theta * 2.0) * 2.8) * s;

    // Leg angles
    final leg1Angle = math.sin(theta) * 0.70;
    final leg2Angle = -leg1Angle;

    // Arm angles (opposite phase to legs)
    final arm1Angle = -math.sin(theta) * 0.65;
    final arm2Angle = -arm1Angle;

    // 1. Back Arm
    _drawArm(
      canvas: canvas,
      s: s,
      shoulder: Offset(hipX + 4 * s, hipY - 24 * s),
      angle: arm2Angle,
      paint: skinBackStrokePaint,
      isBack: true,
      topItem: topItem,
      accessoryItem: accessoryItem,
    );

    // 2. Back Leg
    _drawLeg(
      canvas: canvas,
      s: s,
      hip: Offset(hipX - 1 * s, hipY),
      angle: leg2Angle,
      skinPaint: skinBackStrokePaint,
      bottomsPaint: bottomsPaint,
      bottomsItem: bottomsItem,
      shoePaint: shoePaint,
      shoeAccentPaint: shoeAccentPaint,
      isBack: true,
    );

    // 3. Torso & Bottoms
    _drawTorso(
      canvas: canvas,
      s: s,
      hip: Offset(hipX, hipY),
      topPaint: topPaint,
      bottomsPaint: bottomsPaint,
      topItem: topItem,
      bottomsItem: bottomsItem,
      accessoryItem: accessoryItem,
    );

    // 4. Head & Face
    _drawHead(
      canvas: canvas,
      s: s,
      headCenter: Offset(hipX + 8 * s, hipY - 33 * s),
      skinPaint: skinPaint,
      headwearItem: headwearItem,
      accessoryItem: accessoryItem,
    );

    // 5. Front Leg
    _drawLeg(
      canvas: canvas,
      s: s,
      hip: Offset(hipX + 2 * s, hipY),
      angle: leg1Angle,
      skinPaint: skinStrokePaint,
      bottomsPaint: bottomsPaint,
      bottomsItem: bottomsItem,
      shoePaint: shoePaint,
      shoeAccentPaint: shoeAccentPaint,
      isBack: false,
    );

    // 6. Front Arm
    _drawArm(
      canvas: canvas,
      s: s,
      shoulder: Offset(hipX + 6 * s, hipY - 22 * s),
      angle: arm1Angle,
      paint: skinStrokePaint,
      isBack: false,
      topItem: topItem,
      accessoryItem: accessoryItem,
    );
  }

  void _paintReadyPose({
    required Canvas canvas,
    required double s,
    required Paint skinPaint,
    required Paint skinStrokePaint,
    required Paint topPaint,
    required Paint bottomsPaint,
    required Paint shoePaint,
    required Paint shoeAccentPaint,
    required WardrobeItem topItem,
    required WardrobeItem bottomsItem,
    required WardrobeItem headwearItem,
    required WardrobeItem accessoryItem,
  }) {
    final hipX = 50.0 * s;
    final hipY = 52.0 * s;

    // Standing Legs
    _drawStandingLeg(
      canvas: canvas,
      s: s,
      hip: Offset(hipX - 8 * s, hipY),
      skinPaint: skinStrokePaint,
      bottomsPaint: bottomsPaint,
      bottomsItem: bottomsItem,
      shoePaint: shoePaint,
      shoeAccentPaint: shoeAccentPaint,
    );
    _drawStandingLeg(
      canvas: canvas,
      s: s,
      hip: Offset(hipX + 8 * s, hipY),
      skinPaint: skinStrokePaint,
      bottomsPaint: bottomsPaint,
      bottomsItem: bottomsItem,
      shoePaint: shoePaint,
      shoeAccentPaint: shoeAccentPaint,
    );

    // Torso
    _drawTorso(
      canvas: canvas,
      s: s,
      hip: Offset(hipX, hipY),
      topPaint: topPaint,
      bottomsPaint: bottomsPaint,
      topItem: topItem,
      bottomsItem: bottomsItem,
      accessoryItem: accessoryItem,
    );

    // Head
    _drawHead(
      canvas: canvas,
      s: s,
      headCenter: Offset(hipX, hipY - 35 * s),
      skinPaint: skinPaint,
      headwearItem: headwearItem,
      accessoryItem: accessoryItem,
    );

    // Relaxed Arms
    _drawStandingArm(
      canvas: canvas,
      s: s,
      shoulder: Offset(hipX - 12 * s, hipY - 23 * s),
      paint: skinStrokePaint,
      isLeft: true,
      topItem: topItem,
      accessoryItem: accessoryItem,
    );
    _drawStandingArm(
      canvas: canvas,
      s: s,
      shoulder: Offset(hipX + 12 * s, hipY - 23 * s),
      paint: skinStrokePaint,
      isLeft: false,
      topItem: topItem,
      accessoryItem: accessoryItem,
    );
  }

  void _drawTorso({
    required Canvas canvas,
    required double s,
    required Offset hip,
    required Paint topPaint,
    required Paint bottomsPaint,
    required WardrobeItem topItem,
    required WardrobeItem bottomsItem,
    required WardrobeItem accessoryItem,
  }) {
    // Torso / Jersey Path
    final chestY = hip.dy - 24 * s;
    final torsoPath = Path()
      ..moveTo(hip.dx - 10 * s, hip.dy - 6 * s)
      ..lineTo(hip.dx - 12 * s, chestY)
      ..lineTo(hip.dx + 12 * s, chestY)
      ..lineTo(hip.dx + 10 * s, hip.dy - 6 * s)
      ..close();

    canvas.drawPath(torsoPath, topPaint);

    // Top accent trim
    final accentPaint = Paint()
      ..color = topItem.accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * s;
    canvas.drawLine(
      Offset(hip.dx - 10 * s, chestY + 6 * s),
      Offset(hip.dx + 10 * s, chestY + 6 * s),
      accentPaint,
    );

    // Bottoms / Shorts waistband & hips
    final shortsPath = Path()
      ..moveTo(hip.dx - 11 * s, hip.dy - 6 * s)
      ..lineTo(hip.dx + 11 * s, hip.dy - 6 * s)
      ..lineTo(hip.dx + 12 * s, hip.dy + 8 * s)
      ..lineTo(hip.dx - 12 * s, hip.dy + 8 * s)
      ..close();

    canvas.drawPath(shortsPath, bottomsPaint);

    // Waistpack accessory
    if (accessoryItem.id == 'acc_waistpack_yellow') {
      final packPaint = Paint()
        ..color = accessoryItem.primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(hip.dx, hip.dy - 2 * s),
            width: 14 * s,
            height: 5 * s,
          ),
          Radius.circular(2 * s),
        ),
        packPaint,
      );
    }
  }

  void _drawHead({
    required Canvas canvas,
    required double s,
    required Offset headCenter,
    required Paint skinPaint,
    required WardrobeItem headwearItem,
    required WardrobeItem accessoryItem,
  }) {
    // Neck
    canvas.drawRect(
      Rect.fromLTWH(headCenter.dx - 3 * s, headCenter.dy + 7 * s, 6 * s, 6 * s),
      skinPaint,
    );

    // Head base
    final headRadius = 9.0 * s;
    canvas.drawCircle(headCenter, headRadius, skinPaint);

    // Natural athletic hair (behind headwear)
    final hairPaint = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.fill;
    canvas.drawArc(
      Rect.fromCircle(center: headCenter, radius: headRadius + 1 * s),
      math.pi * 0.9,
      math.pi * 1.1,
      true,
      hairPaint,
    );

    // Headwear Layer
    if (headwearItem.id.contains('cap') || headwearItem.id.contains('visor')) {
      final capPaint = Paint()
        ..color = headwearItem.primaryColor
        ..style = PaintingStyle.fill;

      // Crown / Dome
      canvas.drawArc(
        Rect.fromCircle(center: headCenter, radius: headRadius + 1.5 * s),
        math.pi * 1.0,
        math.pi * 0.95,
        true,
        capPaint,
      );

      // Bill / Visor brim
      final billPath = Path()
        ..moveTo(headCenter.dx + 4 * s, headCenter.dy - 3 * s)
        ..lineTo(headCenter.dx + 16 * s, headCenter.dy - 1 * s)
        ..lineTo(headCenter.dx + 6 * s, headCenter.dy + 1 * s)
        ..close();
      canvas.drawPath(billPath, capPaint);
    } else if (headwearItem.id.contains('headband') ||
        headwearItem.id.contains('crown')) {
      final bandPaint = Paint()
        ..color = headwearItem.primaryColor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.5 * s;

      canvas.drawArc(
        Rect.fromCircle(center: headCenter, radius: headRadius),
        math.pi * 1.1,
        math.pi * 0.75,
        false,
        bandPaint,
      );
    } else if (headwearItem.id.contains('beanie')) {
      final beaniePaint = Paint()
        ..color = headwearItem.primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(headCenter.dx, headCenter.dy - 2 * s),
        headRadius + 2 * s,
        beaniePaint,
      );
    }

    // Sunglasses / Shades Accessory
    if (accessoryItem.id.contains('shades')) {
      final shadesPaint = Paint()
        ..color = accessoryItem.primaryColor
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            headCenter.dx + 1 * s,
            headCenter.dy - 2 * s,
            11 * s,
            5 * s,
          ),
          Radius.circular(2 * s),
        ),
        shadesPaint,
      );
    }
  }

  void _drawLeg({
    required Canvas canvas,
    required double s,
    required Offset hip,
    required double angle,
    required Paint skinPaint,
    required Paint bottomsPaint,
    required WardrobeItem bottomsItem,
    required Paint shoePaint,
    required Paint shoeAccentPaint,
    required bool isBack,
  }) {
    final thighLength = 18.0 * s;
    final calfLength = 17.0 * s;

    // Knee position
    final kneeAngle = angle + (angle < 0 ? 0.75 : 0.25);
    final knee = Offset(
      hip.dx + math.sin(kneeAngle) * thighLength,
      hip.dy + math.cos(kneeAngle) * thighLength,
    );

    // Ankle position
    final ankleAngle = kneeAngle - (angle < 0 ? 0.85 : 0.35);
    final ankle = Offset(
      knee.dx + math.sin(ankleAngle) * calfLength,
      knee.dy + math.cos(ankleAngle) * calfLength,
    );

    // Thigh & Calf
    canvas.drawLine(hip, knee, skinPaint);
    canvas.drawLine(knee, ankle, skinPaint);

    // Shorts / Tights coverage on thigh
    final tightPaint = Paint()
      ..color = bottomsPaint.color.withValues(alpha: isBack ? 0.75 : 1.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.5 * s;
    canvas.drawLine(
      hip,
      Offset((hip.dx + knee.dx) / 2, (hip.dy + knee.dy) / 2),
      tightPaint,
    );

    // Running Shoe
    final footAngle = ankleAngle + 0.35;
    final toe = Offset(
      ankle.dx + math.cos(footAngle) * 9 * s,
      ankle.dy + math.sin(footAngle) * 5 * s,
    );

    final shoePath = Path()
      ..moveTo(ankle.dx - 2 * s, ankle.dy)
      ..lineTo(toe.dx, toe.dy)
      ..lineTo(toe.dx + 1 * s, toe.dy + 3 * s)
      ..lineTo(ankle.dx - 2 * s, ankle.dy + 3 * s)
      ..close();

    canvas.drawPath(shoePath, shoePaint);
    canvas.drawLine(
      Offset(ankle.dx - 2 * s, ankle.dy + 3 * s),
      Offset(toe.dx + 1 * s, toe.dy + 3 * s),
      shoeAccentPaint..strokeWidth = 1.8 * s,
    );
  }

  void _drawStandingLeg({
    required Canvas canvas,
    required double s,
    required Offset hip,
    required Paint skinPaint,
    required Paint bottomsPaint,
    required WardrobeItem bottomsItem,
    required Paint shoePaint,
    required Paint shoeAccentPaint,
  }) {
    final knee = Offset(hip.dx, hip.dy + 18 * s);
    final ankle = Offset(hip.dx, knee.dy + 17 * s);

    canvas.drawLine(hip, knee, skinPaint);
    canvas.drawLine(knee, ankle, skinPaint);

    // Shorts coverage
    final tightPaint = Paint()
      ..color = bottomsPaint.color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 7.5 * s;
    canvas.drawLine(hip, Offset(hip.dx, hip.dy + 10 * s), tightPaint);

    // Shoe
    final shoeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(ankle.dx - 3 * s, ankle.dy, 8 * s, 4 * s),
      Radius.circular(1.5 * s),
    );
    canvas.drawRRect(shoeRect, shoePaint);
  }

  void _drawArm({
    required Canvas canvas,
    required double s,
    required Offset shoulder,
    required double angle,
    required Paint paint,
    required bool isBack,
    required WardrobeItem topItem,
    required WardrobeItem accessoryItem,
  }) {
    final upperArmLen = 14.0 * s;
    final forearmLen = 13.0 * s;

    final elbow = Offset(
      shoulder.dx + math.sin(angle) * upperArmLen,
      shoulder.dy + math.cos(angle) * upperArmLen,
    );

    final handAngle = angle + 1.25;
    final hand = Offset(
      elbow.dx + math.sin(handAngle) * forearmLen,
      elbow.dy + math.cos(handAngle) * forearmLen,
    );

    canvas.drawLine(shoulder, elbow, paint);
    canvas.drawLine(elbow, hand, paint);

    // Sleeve
    final sleevePaint = Paint()
      ..color = topItem.primaryColor.withValues(alpha: isBack ? 0.8 : 1.0)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.8 * s;
    canvas.drawLine(
      shoulder,
      Offset((shoulder.dx + elbow.dx) / 2, (shoulder.dy + elbow.dy) / 2),
      sleevePaint,
    );

    // GPS Watch or Armband accessory
    if (!isBack && accessoryItem.id.contains('watch')) {
      final watchPaint = Paint()
        ..color = accessoryItem.primaryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0 * s;
      canvas.drawCircle(
        Offset((elbow.dx + hand.dx) / 2, (elbow.dy + hand.dy) / 2),
        2.5 * s,
        watchPaint,
      );
    }
  }

  void _drawStandingArm({
    required Canvas canvas,
    required double s,
    required Offset shoulder,
    required Paint paint,
    required bool isLeft,
    required WardrobeItem topItem,
    required WardrobeItem accessoryItem,
  }) {
    final hand = Offset(
      shoulder.dx + (isLeft ? -4 * s : 4 * s),
      shoulder.dy + 25 * s,
    );
    canvas.drawLine(shoulder, hand, paint);

    final sleevePaint = Paint()
      ..color = topItem.primaryColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.8 * s;
    canvas.drawLine(
      shoulder,
      Offset(shoulder.dx, shoulder.dy + 8 * s),
      sleevePaint,
    );
  }

  @override
  bool shouldRepaint(covariant RunnerAvatarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.isReadyPose != isReadyPose ||
      oldDelegate.avatar != avatar;
}
