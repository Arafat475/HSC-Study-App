import 'package:flutter/material.dart';
import '../main.dart';

/// Faint perspective-free grid + soft glow blobs, used behind the Timer and
/// Chapters screens for a cyberpunk feel without being distracting.
class NeonGridBackground extends StatelessWidget {
  final Widget child;

  const NeonGridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF15121F), kBackgroundColor],
              ),
            ),
            child: CustomPaint(painter: _GridPainter()),
          ),
        ),
        // Soft glow blobs, purely decorative.
        Positioned(
          top: -60,
          right: -40,
          child: _GlowBlob(color: kPrimaryColor.withOpacity(0.18), size: 220),
        ),
        Positioned(
          bottom: -50,
          left: -50,
          child: _GlowBlob(color: kAccentColor.withOpacity(0.14), size: 200),
        ),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Color color;
  final double size;

  const _GlowBlob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0)],
          ),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF8B7CF6).withOpacity(0.05)
      ..strokeWidth = 1;

    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
