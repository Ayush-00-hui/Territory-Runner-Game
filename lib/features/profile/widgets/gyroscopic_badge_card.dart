import 'package:flutter/material.dart';

import '../../../ui/ui.dart';

/// Interactive 3D Trophy / Citadel card with gyroscopic perspective tilt and specular metallic gleam.
class GyroscopicBadgeCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final String? tierLabel;

  const GyroscopicBadgeCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.accentColor = AppColors.gold,
    this.tierLabel,
  });

  @override
  State<GyroscopicBadgeCard> createState() => _GyroscopicBadgeCardState();
}

class _GyroscopicBadgeCardState extends State<GyroscopicBadgeCard>
    with SingleTickerProviderStateMixin {
  double _rotateX = 0.0;
  double _rotateY = 0.0;

  late final AnimationController _resetController;
  late Animation<double> _animX;
  late Animation<double> _animY;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _rotateY += details.delta.dx * 0.005;
      _rotateX -= details.delta.dy * 0.005;
      _rotateX = _rotateX.clamp(-0.35, 0.35);
      _rotateY = _rotateY.clamp(-0.35, 0.35);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _animX = Tween<double>(begin: _rotateX, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
    );
    _animY = Tween<double>(begin: _rotateY, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: Curves.easeOutBack),
    );

    _resetController.reset();
    _resetController.forward();
    _resetController.addListener(() {
      setState(() {
        _rotateX = _animX.value;
        _rotateY = _animY.value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final lightOffset = (_rotateY * 1.5).clamp(-0.8, 0.8);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform(
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0015) // Perspective distortion
          ..rotateX(_rotateX)
          ..rotateY(_rotateY),
        alignment: Alignment.center,
        child: Container(
          width: 140.0,
          padding: const EdgeInsets.all(AppSpacing.s16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: widget.accentColor.withValues(alpha: 0.6),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.accentColor.withValues(alpha: 0.2),
                blurRadius: 18.0,
                offset: Offset(-_rotateY * 20.0, _rotateX * 20.0),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Specular Light Sweep Shimmer
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18.0),
                      gradient: LinearGradient(
                        begin: Alignment(-1.0 + lightOffset, -1.0),
                        end: Alignment(1.0 + lightOffset, 1.0),
                        colors: const [
                          AppColors.surface2,
                          AppColors.textPrimary,
                          AppColors.surface2,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              // Content Body
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.tierLabel != null) ...[
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.s6,
                          vertical: 2.0,
                        ),
                        decoration: BoxDecoration(
                          color: widget.accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          widget.tierLabel!.toUpperCase(),
                          style: AppText.caption.copyWith(
                            color: widget.accentColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4.0),
                  ],
                  Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.accentColor.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      widget.icon,
                      color: widget.accentColor,
                      size: 26.0,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s10),
                  Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: AppText.labelLarge.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: AppText.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
