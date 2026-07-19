import 'dart:math' as math;

import 'package:flutter/material.dart';

enum NatureMotion {
  bounce,
  sway,
  spin,
  sweep,
  breathe,
  pop,
  dash,
  rise,
  glow,
  sparkle,
  float,
}

NatureMotion questNatureMotion(String? regionKey) => switch (regionKey) {
      'kitchen' || 'special_cooking' => NatureMotion.bounce,
      'laundry' => NatureMotion.spin,
      'bathroom' => NatureMotion.sparkle,
      'bedroom' || 'wellbeing' => NatureMotion.breathe,
      'living_room' || 'home_routine' => NatureMotion.sweep,
      'outdoor' || 'community' => NatureMotion.sway,
      'animal_care' => NatureMotion.bounce,
      'vehicle' => NatureMotion.sweep,
      'quick_daily' => NatureMotion.pop,
      'family_group' => NatureMotion.glow,
      _ => NatureMotion.pop,
    };

NatureMotion avatarNatureMotion(String? avatarKey) => switch (avatarKey) {
      'akatsuki_ninja' || 'ranger' => NatureMotion.dash,
      'warrior_queen' || 'guardian' || 'knight' => NatureMotion.glow,
      'totoro' || 'druid' || 'healer' => NatureMotion.breathe,
      'meerkat' || 'explorer' || 'scholar' => NatureMotion.pop,
      'mage' || 'star' || 'dragon' => NatureMotion.sparkle,
      'cook' || 'builder' => NatureMotion.bounce,
      _ => NatureMotion.pop,
    };

NatureMotion kingdomNatureMotion(String emoji) => switch (emoji) {
      '⛺' || '🏕️' => NatureMotion.sway,
      '🏘️' || '🏠' || '🏡' => NatureMotion.rise,
      '🏰' || '🛡️' => NatureMotion.glow,
      '👑' || '✨' => NatureMotion.sparkle,
      _ => NatureMotion.rise,
    };

class NatureAnimatedIcon extends StatefulWidget {
  const NatureAnimatedIcon({
    required this.child,
    required this.motion,
    this.duration = const Duration(milliseconds: 900),
    this.replayKey,
    super.key,
  });

  final Widget child;
  final NatureMotion motion;
  final Duration duration;

  /// Changing this value replays the entrance once, which is useful when the
  /// same navigation shell displays a different screen.
  final Object? replayKey;

  @override
  State<NatureAnimatedIcon> createState() => _NatureAnimatedIconState();
}

class _NatureAnimatedIconState extends State<NatureAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) _playOnce();
  }

  @override
  void didUpdateWidget(covariant NatureAnimatedIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.replayKey != widget.replayKey ||
        oldWidget.motion != widget.motion) {
      _started = false;
      _playOnce();
    }
  }

  void _playOnce() {
    _started = true;
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
      return;
    }
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sparkleColor = Theme.of(context).colorScheme.tertiary;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) {
          final presentation = _presentationFor(
            widget.motion,
            _controller.value,
          );
          final transformed = Transform(
            key: const ValueKey('nature-icon-transform'),
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translateByDouble(
                presentation.dx,
                presentation.dy,
                0,
                1,
              )
              ..rotateZ(presentation.rotation)
              ..scaleByDouble(
                presentation.scale,
                presentation.scale,
                1,
                1,
              ),
            child: Opacity(opacity: presentation.opacity, child: child),
          );

          if (widget.motion != NatureMotion.sparkle &&
              widget.motion != NatureMotion.glow) {
            return transformed;
          }

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              transformed,
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SparklePainter(
                      progress: _controller.value,
                      color: sparkleColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

_NaturePresentation _presentationFor(NatureMotion motion, double progress) {
  final settle = 1 - progress;
  final easeOut = Curves.easeOutCubic.transform(progress);
  final overshoot = Curves.easeOutBack.transform(progress);

  return switch (motion) {
    NatureMotion.bounce => _NaturePresentation(
        dy: -6 * math.sin(progress * math.pi),
        scale: 1 + 0.04 * math.sin(progress * math.pi),
      ),
    NatureMotion.sway => _NaturePresentation(
        rotation: math.sin(progress * math.pi * 4) * settle * 0.16,
      ),
    NatureMotion.spin => _NaturePresentation(
        rotation: math.pi * 2 * easeOut,
        scale: 0.9 + 0.1 * easeOut,
      ),
    NatureMotion.sweep => _NaturePresentation(
        dx: -12 * (1 - easeOut) + math.sin(progress * math.pi * 3) * 2,
        rotation: math.sin(progress * math.pi * 2) * settle * 0.1,
        opacity: 0.45 + 0.55 * easeOut,
      ),
    NatureMotion.breathe => _NaturePresentation(
        scale: 1 + 0.09 * math.sin(progress * math.pi),
      ),
    NatureMotion.pop => _NaturePresentation(
        scale: 0.68 + 0.32 * overshoot,
        opacity: 0.25 + 0.75 * easeOut,
      ),
    NatureMotion.dash => _NaturePresentation(
        dx: -18 * (1 - easeOut),
        scale: 0.9 + 0.1 * easeOut,
        opacity: 0.2 + 0.8 * easeOut,
      ),
    NatureMotion.rise => _NaturePresentation(
        dy: 14 * (1 - easeOut),
        scale: 0.8 + 0.2 * overshoot,
        opacity: 0.25 + 0.75 * easeOut,
      ),
    NatureMotion.glow => _NaturePresentation(
        scale: 1 + 0.07 * math.sin(progress * math.pi),
      ),
    NatureMotion.sparkle => _NaturePresentation(
        scale: 0.82 + 0.18 * overshoot,
        opacity: 0.35 + 0.65 * easeOut,
      ),
    NatureMotion.float => _NaturePresentation(
        dy: -5 * math.sin(progress * math.pi),
        rotation: math.sin(progress * math.pi * 2) * settle * 0.06,
      ),
  };
}

class _NaturePresentation {
  const _NaturePresentation({
    this.dx = 0,
    this.dy = 0,
    this.rotation = 0,
    this.scale = 1,
    this.opacity = 1,
  });

  final double dx;
  final double dy;
  final double rotation;
  final double scale;
  final double opacity;
}

class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final intensity = math.sin(progress * math.pi).clamp(0.0, 1.0);
    if (intensity <= 0.01) return;

    final paint = Paint()
      ..color = color.withValues(alpha: intensity * 0.9)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final radius = 2 + intensity * 2;
    final points = <Offset>[
      Offset(size.width * 0.12, size.height * 0.18),
      Offset(size.width * 0.86, size.height * 0.22),
      Offset(size.width * 0.18, size.height * 0.82),
      Offset(size.width * 0.82, size.height * 0.76),
    ];

    for (final point in points) {
      canvas
        ..drawLine(
          Offset(point.dx - radius, point.dy),
          Offset(point.dx + radius, point.dy),
          paint,
        )
        ..drawLine(
          Offset(point.dx, point.dy - radius),
          Offset(point.dx, point.dy + radius),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
