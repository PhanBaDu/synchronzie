import 'package:flutter/cupertino.dart';

class CircularProgressRing extends StatelessWidget {
  final double size;
  final double progress; // 0..1
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const CircularProgressRing({
    super.key,
    required this.size,
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CircularProgressPainter(
          progress: progress,
          trackColor: trackColor,
          progressColor: progressColor,
          strokeWidth: strokeWidth,
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  final double progress; // 0..1
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    // Draw full track
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -90 * 3.1415926535 / 180,
      360 * 3.1415926535 / 180,
      false,
      trackPaint,
    );

    // Draw progress arc
    final sweep = (progress.clamp(0.0, 1.0)) * 360 * 3.1415926535 / 180;
    if (sweep > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -90 * 3.1415926535 / 180,
        sweep,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
