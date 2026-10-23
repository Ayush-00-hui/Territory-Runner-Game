import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../ui/ui.dart';

/// 3-Slide Vector Onboarding Experience with Charcoal + Ember athletic styling.
/// Educates the athlete on loop-based enclosure, rival attack radar, and AI telemetry.
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;
  final bool autoAnimate;

  const OnboardingScreen({
    super.key,
    required this.onCompleted,
    this.autoAnimate = true,
  });

  static const String prefsKeyCompleted = 'has_completed_onboarding';

  /// Utility to check whether onboarding has already been completed
  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(prefsKeyCompleted) ?? false;
  }

  /// Utility to reset onboarding state (e.g. for testing or re-run from settings)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefsKeyCompleted);
  }

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    if (widget.autoAnimate) {
      _pulseController.repeat();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.prefsKeyCompleted, true);
    widget.onCompleted();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // Header: Brand & Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s20,
                vertical: AppSpacing.s12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.accentContainer,
                            borderRadius: AppRadius.br8,
                            border: Border.all(
                              color: AppColors.accent.withValues(alpha: 0.5),
                              width: 1.0,
                            ),
                          ),
                          child: const Icon(
                            Icons.terrain_rounded,
                            color: AppColors.accent,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s10),
                        Flexible(
                          child: Text(
                            'TERRITORY RUNNER',
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label.copyWith(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_currentPage < 2)
                    GestureDetector(
                      onTap: _completeOnboarding,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s10,
                          vertical: AppSpacing.s6,
                        ),
                        child: Text(
                          'SKIP',
                          style: AppText.label.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 28),
                ],
              ),
            ),

            // Page Content Carousel
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                children: [
                  _SlideView(
                    badge: '01 / RUN & CLAIM',
                    title: 'Run & Claim Real-World Territory',
                    description: 'Lace up and run organic loops through city streets. When your GPS path intersects and closes, the enclosed territory is instantly claimed on the global grid.',
                    illustration: _RunAndClaimGraphic(pulse: _pulseController),
                    statusPillText: 'Territory claimed • 14,250 m²',
                    statusPillIcon: Icons.check_circle_rounded,
                  ),
                  _SlideView(
                    badge: '02 / RIVALRY & LEAGUES',
                    title: 'Defend & Compete in Real-Time',
                    description: 'Rival runners will challenge your territory. Get alerts, defend your areas, compete with runners, and fight for weekly league promotion.',
                    illustration: _DefendAndCompeteGraphic(
                      pulse: _pulseController,
                    ),
                    statusPillText: 'Active radar • 3 runners nearby',
                    statusPillIcon: Icons.radar_rounded,
                  ),
                  _SlideView(
                    badge: '03 / RUN STATS & COACH',
                    title: 'Sub-Meter Precision & AI Coaching',
                    description: 'Precise GPS filtering, elevation splits, audio tips from your AI coach, and post-run share cards ready for your squad.',
                    illustration: _AthleticPrecisionGraphic(
                      pulse: _pulseController,
                    ),
                    statusPillText: 'AI coach: "Split ahead of target pace"',
                    statusPillIcon: Icons.insights_rounded,
                  ),
                ],
              ),
            ),

            // Bottom Navigation Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s24,
                AppSpacing.s12,
                AppSpacing.s24,
                AppSpacing.s24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Smooth Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = _currentPage == index;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.accent
                              : AppColors.disabled,
                          borderRadius: AppRadius.brFull,
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppSpacing.s20),

                  // Action Button
                  if (_currentPage < 2)
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Previous',
                            onPressed: _currentPage > 0
                                ? () => _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.s12),
                        Expanded(
                          flex: 2,
                          child: PrimaryButton(
                            label: 'Next',
                            icon: Icons.arrow_forward_rounded,
                            onPressed: _nextPage,
                          ),
                        ),
                      ],
                    )
                  else
                    PrimaryButton(
                      label: 'Get started',
                      icon: Icons.bolt_rounded,
                      onPressed: _completeOnboarding,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final String badge;
  final String title;
  final String description;
  final Widget illustration;
  final String statusPillText;
  final IconData statusPillIcon;

  const _SlideView({
    required this.badge,
    required this.title,
    required this.description,
    required this.illustration,
    required this.statusPillText,
    required this.statusPillIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s24),
      child: Column(
        children: [
          // Graphic Canvas Container
          Expanded(
            flex: 5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    illustration,
                    Positioned(
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: AppRadius.brFull,
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                          boxShadow: AppElevation.floating,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              statusPillIcon,
                              size: 14,
                              color: AppColors.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              statusPillText,
                              style: AppText.labelSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontSize: 10,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Text Content Container
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentContainer,
                      borderRadius: AppRadius.br8,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      badge,
                      style: AppText.label.copyWith(
                        color: AppColors.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppText.headingMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: AppText.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// VECTOR ILLUSTRATIONS (Charcoal + Ember tokens, no external image assets)
// ---------------------------------------------------------------------------

class _RunAndClaimGraphic extends StatelessWidget {
  final Animation<double> pulse;

  const _RunAndClaimGraphic({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(280, 220),
          painter: _RunAndClaimPainter(progress: pulse.value),
        );
      },
    );
  }
}

class _RunAndClaimPainter extends CustomPainter {
  final double progress;

  _RunAndClaimPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 10);

    // 1. Draw subtle city gridlines
    final gridPaint = Paint()
      ..color = AppColors.borderSubtle
      ..strokeWidth = 1.0;

    for (double x = 20; x < size.width; x += 35) {
      canvas.drawLine(Offset(x, 10), Offset(x, size.height - 20), gridPaint);
    }
    for (double y = 20; y < size.height - 20; y += 35) {
      canvas.drawLine(Offset(20, y), Offset(size.width - 20, y), gridPaint);
    }

    // 2. Closed Loop Polygon (Sector)
    final polyPath = Path()
      ..moveTo(center.dx - 80, center.dy - 30)
      ..lineTo(center.dx - 10, center.dy - 70)
      ..lineTo(center.dx + 70, center.dy - 40)
      ..lineTo(center.dx + 85, center.dy + 40)
      ..lineTo(center.dx + 15, center.dy + 65)
      ..lineTo(center.dx - 70, center.dy + 45)
      ..close();

    // Territory Fill with Ember breathing pulse
    final alpha = 0.15 + 0.08 * math.sin(progress * math.pi * 2);
    final fillPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;
    canvas.drawPath(polyPath, fillPaint);

    // Territory Border
    final borderPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(polyPath, borderPaint);

    // 3. Runner Waypoint Ripple
    final runnerPos = Offset(center.dx + 70, center.dy - 40);
    final rippleRadius = 8.0 + 12.0 * progress;
    final rippleAlpha = (1.0 - progress).clamp(0.0, 1.0) * 0.6;

    final ripplePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: rippleAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(runnerPos, rippleRadius, ripplePaint);

    // Runner core dot
    final dotPaint = Paint()..color = AppColors.accent;
    canvas.drawCircle(runnerPos, 5.0, dotPaint);

    final dotCenterPaint = Paint()..color = AppColors.onAccent;
    canvas.drawCircle(runnerPos, 2.5, dotCenterPaint);
  }

  @override
  bool shouldRepaint(covariant _RunAndClaimPainter oldDelegate) => true;
}

class _DefendAndCompeteGraphic extends StatelessWidget {
  final Animation<double> pulse;

  const _DefendAndCompeteGraphic({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(280, 220),
          painter: _DefendAndCompetePainter(progress: pulse.value),
        );
      },
    );
  }
}

class _DefendAndCompetePainter extends CustomPainter {
  final double progress;

  _DefendAndCompetePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 10);

    // 1. Concentric radar rings
    final ringPaint = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (final r in [30.0, 60.0, 90.0]) {
      canvas.drawCircle(center, r, ringPaint);
    }

    // Crosshairs
    canvas.drawLine(
      Offset(center.dx - 95, center.dy),
      Offset(center.dx + 95, center.dy),
      ringPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 95),
      Offset(center.dx, center.dy + 95),
      ringPaint,
    );

    // 2. Rotating radar sweep beam
    final sweepAngle = progress * math.pi * 2;
    final sweepPaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final sweepPath = Path()
      ..moveTo(center.dx, center.dy)
      ..arcTo(
        Rect.fromCircle(center: center, radius: 90),
        sweepAngle - math.pi / 4,
        math.pi / 4,
        false,
      )
      ..close();
    canvas.drawPath(sweepPath, sweepPaint);

    final beamLinePaint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.7)
      ..strokeWidth = 1.5;
    canvas.drawLine(
      center,
      Offset(
        center.dx + 90 * math.cos(sweepAngle),
        center.dy + 90 * math.sin(sweepAngle),
      ),
      beamLinePaint,
    );

    // 3. Central Defense Shield
    final shieldPaint = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 22, shieldPaint);

    final shieldBorder = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, 22, shieldBorder);

    // 4. Rival Threat Blips
    final rival1 = Offset(center.dx + 48, center.dy - 38);
    final rival2 = Offset(center.dx - 55, center.dy + 42);

    final rivalPaint = Paint()..color = AppColors.error;
    canvas.drawCircle(rival1, 4.0, rivalPaint);
    canvas.drawCircle(rival2, 4.0, rivalPaint);

    final pingPaint = Paint()
      ..color = AppColors.error.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(rival1, 8.0, pingPaint);
    canvas.drawCircle(rival2, 8.0, pingPaint);
  }

  @override
  bool shouldRepaint(covariant _DefendAndCompetePainter oldDelegate) => true;
}

class _AthleticPrecisionGraphic extends StatelessWidget {
  final Animation<double> pulse;

  const _AthleticPrecisionGraphic({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(280, 220),
          painter: _AthleticPrecisionPainter(progress: pulse.value),
        );
      },
    );
  }
}

class _AthleticPrecisionPainter extends CustomPainter {
  final double progress;

  _AthleticPrecisionPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 10);

    // 1. Cadence / Pace HUD Gauge Arc
    final trackPaint = Paint()
      ..color = AppColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 75),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      trackPaint,
    );

    // Animated Active Pace Sweep
    final activeAngle = math.pi * 1.1 + 0.15 * math.sin(progress * math.pi * 2);
    final activePaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 75),
      math.pi * 0.75,
      activeAngle,
      false,
      activePaint,
    );

    // 2. Center Telemetry Card
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 90, height: 50),
      const Radius.circular(10),
    );
    final cardBg = Paint()..color = AppColors.surface;
    final cardBorder = Paint()
      ..color = AppColors.borderSubtle
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(cardRect, cardBg);
    canvas.drawRRect(cardRect, cardBorder);

    // 3. Audio / Waveform Bars for AI Coach
    final barPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final barHeights = [10.0, 22.0, 16.0, 28.0, 18.0, 12.0];
    final startX = center.dx - 22;
    for (int i = 0; i < barHeights.length; i++) {
      final h =
          barHeights[i] * (0.7 + 0.3 * math.sin(progress * math.pi * 2 + i));
      final x = startX + i * 9.0;
      canvas.drawLine(
        Offset(x, center.dy + h / 2),
        Offset(x, center.dy - h / 2),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AthleticPrecisionPainter oldDelegate) => true;
}
