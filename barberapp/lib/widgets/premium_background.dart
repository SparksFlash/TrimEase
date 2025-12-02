import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Reusable premium animated background with drifting luminous blobs.
/// Wrap any page body with [PremiumBackground] to apply consistent styling.
class PremiumBackground extends StatefulWidget {
  final Widget? child;
  final bool showBadge;
  final Duration duration;

  const PremiumBackground({
    Key? key,
    this.child,
    this.showBadge = true,
    this.duration = const Duration(seconds: 22),
  }) : super(key: key);

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _PremiumPainter(
                  progress: _ctrl.value,
                  dark: Theme.of(context).brightness == Brightness.dark,
                ),
              ),
            ),
            if (widget.showBadge)
              Positioned(
                top: 10,
                right: 12,
                child: Transform.translate(
                  offset: Offset(0, math.sin(_ctrl.value * 2 * math.pi) * 5),
                  child: Icon(
                    Icons.workspace_premium,
                    color: Colors.amber.shade400,
                    size: 30,
                  ),
                ),
              ),
            if (widget.child != null) widget.child!,
          ],
        );
      },
    );
  }
}

class _PremiumPainter extends CustomPainter {
  final double progress;
  final bool dark;
  _PremiumPainter({required this.progress, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final shader = LinearGradient(
      colors:
          dark
              ? [const Color(0xFF0C1114), const Color(0xFF1E262C)]
              : [const Color(0xFFFDFDFE), const Color(0xFFE4F2FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);

    final centerGlow = RadialGradient(
      colors:
          dark
              ? [Colors.white.withOpacity(0.06), Colors.transparent]
              : [Colors.white.withOpacity(0.14), Colors.transparent],
      radius: 0.85,
    ).createShader(
      Rect.fromCircle(
        center: Offset(size.width * 0.55, size.height * 0.35),
        radius: size.shortestSide * 0.65,
      ),
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = centerGlow
        ..blendMode = BlendMode.plus,
    );

    final t = progress;
    final blobPaint = Paint()..style = PaintingStyle.fill;

    void blob({
      required Offset c,
      required double r,
      required List<Color> colors,
      BlendMode mode = BlendMode.screen,
    }) {
      final rect = Rect.fromCircle(center: c, radius: r);
      blobPaint.shader = RadialGradient(
        colors: colors,
        stops: const [0.0, 1.0],
      ).createShader(rect);
      final path = Path();
      const segs = 42;
      for (int i = 0; i <= segs; i++) {
        final ang = (i / segs) * math.pi * 2;
        final wobble = math.sin(ang * 3 + t * math.pi * 2) * (r * 0.12);
        final dx = c.dx + (r + wobble) * math.cos(ang);
        final dy = c.dy + (r + wobble) * math.sin(ang);
        if (i == 0) {
          path.moveTo(dx, dy);
        } else {
          path.lineTo(dx, dy);
        }
      }
      path.close();
      canvas.drawPath(path, blobPaint..blendMode = mode);
      if (!dark) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0
            ..color = Colors.white.withOpacity(0.12)
            ..blendMode = BlendMode.overlay,
        );
      }
    }

    final w = size.width;
    final h = size.height;

    blob(
      c: Offset(w * 0.24 + math.sin(t * 2 * math.pi) * 26, h * 0.32),
      r: 120 + math.sin(t * 2 * math.pi) * 10,
      colors: [
        (dark ? Colors.cyanAccent : Colors.blueAccent).withOpacity(0.85),
        (dark ? Colors.teal : Colors.indigo).withOpacity(0.22),
      ],
    );
    blob(
      c: Offset(
        w * 0.72 + math.cos(t * 2 * math.pi) * 30,
        h * 0.30 + math.sin(t * 2 * math.pi) * 18,
      ),
      r: 105 + math.cos(t * 2 * math.pi) * 8,
      colors: [
        (dark ? Colors.orangeAccent : Colors.pinkAccent).withOpacity(0.80),
        (dark ? Colors.deepOrange : Colors.purple).withOpacity(0.25),
      ],
    );
    blob(
      c: Offset(
        w * 0.50 + math.sin(t * 2 * math.pi) * 22,
        h * 0.58 + math.cos(t * 2 * math.pi) * 24,
      ),
      r: 150 + math.sin(t * 2 * math.pi) * 14,
      colors: [
        (dark ? Colors.amberAccent : Colors.amber).withOpacity(0.75),
        (dark ? Colors.yellowAccent : Colors.orangeAccent).withOpacity(0.24),
      ],
    );
    blob(
      c: Offset(w * 0.35, h * 0.75),
      r: 180,
      colors: [
        (dark ? Colors.blueGrey : Colors.lightBlueAccent).withOpacity(0.16),
        Colors.transparent,
      ],
      mode: BlendMode.plus,
    );
    blob(
      c: Offset(w * 0.8, h * 0.65),
      r: 160,
      colors: [
        (dark ? Colors.deepPurpleAccent : Colors.pinkAccent).withOpacity(0.15),
        Colors.transparent,
      ],
      mode: BlendMode.plus,
    );
  }

  @override
  bool shouldRepaint(covariant _PremiumPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.dark != dark;
}
