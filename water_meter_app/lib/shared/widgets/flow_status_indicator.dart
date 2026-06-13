import 'package:flutter/material.dart';

/// Animated faucet / flow indicator for live water telemetry.
class FlowStatusIndicator extends StatefulWidget {
  const FlowStatusIndicator({
    super.key,
    required this.isFlowing,
    this.size = 32,
    this.activeColor,
    this.idleColor,
  });

  final bool isFlowing;
  final double size;
  final Color? activeColor;
  final Color? idleColor;

  @override
  State<FlowStatusIndicator> createState() => _FlowStatusIndicatorState();
}

class _FlowStatusIndicatorState extends State<FlowStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant FlowStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFlowing != widget.isFlowing) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isFlowing) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller
        ..stop()
        ..reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = widget.activeColor ?? scheme.primary;
    final idle = widget.idleColor ?? scheme.outline;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: widget.isFlowing
          ? AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _FlowingTapPainter(
                    progress: _controller.value,
                    color: active,
                  ),
                  child: const SizedBox.expand(),
                );
              },
            )
          : CustomPaint(
              painter: _IdleTapPainter(color: idle),
              child: const SizedBox.expand(),
            ),
    );
  }
}

class _IdleTapPainter extends CustomPainter {
  _IdleTapPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.07
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final bodyTop = h * 0.18;
    final spoutY = h * 0.52;

    // Tap body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, bodyTop, w * 0.32, h * 0.2),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, stroke);

    // Spout arm
    canvas.drawLine(
      Offset(w * 0.5, bodyTop + h * 0.2),
      Offset(w * 0.5, spoutY),
      stroke,
    );

    // Closed spout tip
    canvas.drawCircle(Offset(w * 0.5, spoutY + h * 0.03), w * 0.05, stroke);

    // Handle (off position)
    canvas.drawLine(
      Offset(w * 0.66, bodyTop + h * 0.1),
      Offset(w * 0.78, bodyTop + h * 0.02),
      stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _IdleTapPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _FlowingTapPainter extends CustomPainter {
  _FlowingTapPainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.07
      ..strokeCap = StrokeCap.round;

    final fill = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final bodyTop = h * 0.14;

    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, bodyTop, w * 0.32, h * 0.18),
      Radius.circular(w * 0.06),
    );
    canvas.drawRRect(body, fill);
    canvas.drawRRect(body, stroke);

    // Spout
    canvas.drawLine(
      Offset(w * 0.5, bodyTop + h * 0.18),
      Offset(w * 0.5, h * 0.48),
      stroke,
    );

    // Handle (open)
    canvas.drawLine(
      Offset(w * 0.66, bodyTop + h * 0.09),
      Offset(w * 0.8, bodyTop + h * 0.16),
      stroke,
    );

    // Stream line
    final streamPaint = Paint()
      ..color = color.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.05
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.5, h * 0.5),
      Offset(w * 0.5, h * 0.62),
      streamPaint,
    );

    _drawDrop(
      canvas,
      Offset(w * 0.5, h * (0.64 + _dropOffset(0))),
      w * 0.09,
      _dropOpacity(0),
      color,
    );
    _drawDrop(
      canvas,
      Offset(w * 0.44, h * (0.72 + _dropOffset(0.35))),
      w * 0.07,
      _dropOpacity(0.35),
      color,
    );
    _drawDrop(
      canvas,
      Offset(w * 0.56, h * (0.78 + _dropOffset(0.7))),
      w * 0.06,
      _dropOpacity(0.7),
      color,
    );
  }

  double _dropOffset(double phase) {
    final t = (progress + phase) % 1.0;
    return t * 0.14;
  }

  double _dropOpacity(double phase) {
    final t = (progress + phase) % 1.0;
    if (t < 0.15) return t / 0.15;
    if (t > 0.85) return (1.0 - t) / 0.15;
    return 1.0;
  }

  void _drawDrop(Canvas canvas, Offset center, double radius, double opacity, Color color) {
    if (opacity <= 0) return;
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(
        center.dx + radius,
        center.dy,
        center.dx,
        center.dy + radius * 1.2,
      )
      ..quadraticBezierTo(
        center.dx - radius,
        center.dy,
        center.dx,
        center.dy - radius,
      )
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: opacity.clamp(0.0, 1.0))
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _FlowingTapPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

bool isWaterFlowing({
  required bool valveOff,
  required double flowRateLpm,
  String status = 'idle',
}) {
  if (valveOff) return false;
  return flowRateLpm > 0.2 || status == 'flowing';
}
