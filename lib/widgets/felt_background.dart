import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Purple table felt: a soft center light, darker edges and fine fibre noise.
class FeltBackground extends StatelessWidget {
  const FeltBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: CustomPaint(painter: FeltPainter(), size: Size.infinite),
    );
  }
}

class FeltPainter extends CustomPainter {
  const FeltPainter();

  static const _noiseCount = 9000;
  static final Float32List _noise = () {
    final rnd = math.Random(7);
    return Float32List.fromList([for (var i = 0; i < _noiseCount * 2; i++) rnd.nextDouble()]);
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          Offset(size.width / 2, size.height * 0.42),
          size.longestSide * 0.75,
          const [Color(0xFF5E3D8A), Color(0xFF4A2F6E), Color(0xFF2A1844)],
          const [0, 0.5, 1],
        ),
    );

    final light = <Offset>[];
    final dark = <Offset>[];
    for (var i = 0; i < _noiseCount; i++) {
      final p = Offset(_noise[i * 2] * size.width, _noise[i * 2 + 1] * size.height);
      (i.isEven ? light : dark).add(p);
    }
    canvas.drawPoints(
      ui.PointMode.points,
      light,
      Paint()
        ..color = const Color(0x14FFFFFF)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPoints(
      ui.PointMode.points,
      dark,
      Paint()
        ..color = const Color(0x22000000)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(FeltPainter oldDelegate) => false;
}
