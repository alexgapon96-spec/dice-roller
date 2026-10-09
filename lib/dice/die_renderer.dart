import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3, Vector3;

import 'geometry.dart';

const _granite = Color(0xFF7C7A83);
const _edge = Color(0xFF2E2D33);
const _speckDark = Color(0xB3252428);
const _speckLight = Color(0x99D4D2D9);
const _numberColor = Color(0xFFF4F4F4);
const _engraveColor = Color(0x99141317);

/// Camera distance from the die center, in die units (weak perspective).
const _cameraDistance = 6.0;

/// Light direction in view space (x right, y up, z towards the viewer).
final _light = Vector3(-0.35, 0.45, 1).normalized();

/// One die as it should appear on screen this frame.
class DieVisual {
  const DieVisual({
    required this.geometry,
    required this.rotation,
    required this.center,
    required this.radius,
    this.lift = 0,
    this.opacity = 1,
    this.glow,
  });

  final DieGeometry geometry;
  final Matrix3 rotation;
  final Offset center;

  /// Circumradius on screen, in logical pixels.
  final double radius;

  /// 0 = resting on the felt, 1 = top of a bounce.
  final double lift;
  final double opacity;
  final Color? glow;
}

/// Software renderer for convex dice: back-face culling, flat shading,
/// granite specks and numbers mapped onto each face.
class DieRenderer {
  static final _textCache = <String, TextPainter>{};

  static void paintGlow(Canvas canvas, DieVisual d) {
    final glow = d.glow;
    if (glow == null) return;
    final r = d.radius * 1.75;
    canvas.drawCircle(
      d.center,
      r,
      Paint()
        ..shader = ui.Gradient.radial(
          d.center,
          r,
          [glow.withValues(alpha: 0.75), glow.withValues(alpha: 0.28), glow.withValues(alpha: 0)],
          [0.3, 0.62, 1],
        ),
    );
  }

  /// Soft shadow cast by the die's actual silhouette, so every shape gets a
  /// shadow that fits it.
  static void paintShadow(Canvas canvas, DieVisual d) {
    final r = d.radius;
    final offset = Offset(r * 0.08, r * 0.14) + Offset(r * 0.25, r * 0.4) * d.lift;
    final silhouette = Path();
    final project = _projector(d);
    for (final face in d.geometry.faces) {
      if (!_facesCamera(face, d.rotation)) continue;
      silhouette.addPath(_facePath(face, d.rotation, project), Offset.zero);
    }
    canvas.drawPath(
      silhouette.shift(offset),
      Paint()
        ..color = Color.fromRGBO(10, 0, 20, (0.5 - d.lift * 0.2) * d.opacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.1),
    );
  }

  static Offset Function(Vector3) _projector(DieVisual d) {
    final scale = d.radius * (1 + d.lift * 0.18);
    return (p) {
      final s = _cameraDistance / (_cameraDistance - p.z);
      return d.center + Offset(p.x * s, -p.y * s) * scale;
    };
  }

  static bool _facesCamera(DieFace face, Matrix3 rot) {
    final c = rot.transformed(face.centroid);
    final n = rot.transformed(face.normal);
    return n.dot(Vector3(-c.x, -c.y, _cameraDistance - c.z)) > 0;
  }

  static Path _facePath(DieFace face, Matrix3 rot, Offset Function(Vector3) project) {
    final path = Path();
    for (var i = 0; i < face.vertices.length; i++) {
      final p = project(rot.transformed(face.vertices[i]));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  static void paintDie(Canvas canvas, DieVisual d) {
    final scale = d.radius * (1 + d.lift * 0.18);
    final project = _projector(d);

    final faded = d.opacity < 1;
    if (faded) {
      canvas.saveLayer(
        Rect.fromCircle(center: d.center, radius: scale * 1.3),
        Paint()..color = Color.fromRGBO(0, 0, 0, d.opacity),
      );
    }

    final rot = d.rotation;
    final edgePaint = Paint()
      ..color = _edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, scale * 0.012)
      ..strokeJoin = StrokeJoin.round;

    for (final face in d.geometry.faces) {
      if (!_facesCamera(face, rot)) continue;
      final c = rot.transformed(face.centroid);
      final n = rot.transformed(face.normal);
      final path = _facePath(face, rot, project);

      final light = math.max(0.0, n.dot(_light));
      final brightness = 0.38 + 0.72 * light + 0.18 * math.pow(light, 12);
      canvas.drawPath(path, Paint()..color = _shade(_granite, brightness));

      canvas.save();
      canvas.clipPath(path);
      _paintSpecks(canvas, face, rot, c, project, scale);
      for (final label in face.labels) {
        _paintLabel(canvas, label, rot, project, d.geometry.type);
      }
      canvas.restore();

      canvas.drawPath(path, edgePaint);
    }

    if (faded) canvas.restore();
  }

  static void paint(Canvas canvas, DieVisual d) {
    paintGlow(canvas, d);
    paintShadow(canvas, d);
    paintDie(canvas, d);
  }

  static Color _shade(Color c, double k) => Color.fromARGB(
        255,
        (c.r * 255 * k).round().clamp(0, 255),
        (c.g * 255 * k).round().clamp(0, 255),
        (c.b * 255 * k).round().clamp(0, 255),
      );

  static void _paintSpecks(
    Canvas canvas,
    DieFace face,
    Matrix3 rot,
    Vector3 centroid,
    Offset Function(Vector3) project,
    double scale,
  ) {
    final o = project(centroid);
    final ex = project(centroid + rot.transformed(face.right)) - o;
    final ey = project(centroid + rot.transformed(face.up)) - o;
    final dark = Paint()..color = _speckDark;
    final light = Paint()..color = _speckLight;
    for (final s in face.specks) {
      canvas.drawCircle(o + ex * s.u + ey * s.v, s.radius * scale, s.light ? light : dark);
    }
  }

  static void _paintLabel(
    Canvas canvas,
    DieLabel label,
    Matrix3 rot,
    Offset Function(Vector3) project,
    DieType type,
  ) {
    // Text is laid out in units of 1/100 die unit, then mapped onto the face.
    const unit = 0.01;
    final p = rot.transformed(label.position);
    final o = project(p);
    final ex = (project(p + rot.transformed(label.right) * unit) - o);
    final ey = (project(p + rot.transformed(label.up) * unit) - o);

    canvas.save();
    canvas.transform(Float64List.fromList([
      ex.dx, ex.dy, 0, 0, //
      -ey.dx, -ey.dy, 0, 0, //
      0, 0, 1, 0, //
      o.dx, o.dy, 0, 1,
    ]));

    final size = (label.fontSize * 100).roundToDouble();
    final underline = type.sides >= 8 && (label.value == 6 || label.value == 9);
    final shadow = _text(label.value, size, _engraveColor);
    final text = _text(label.value, size, _numberColor);
    final at = Offset(-text.width / 2, -text.height / 2);
    shadow.paint(canvas, at + Offset(0, size * 0.05));
    text.paint(canvas, at);
    if (underline) {
      final y = at.dy + text.height * 0.86;
      final w = text.width * 0.7;
      canvas.drawLine(
        Offset(-w / 2, y),
        Offset(w / 2, y),
        Paint()
          ..color = _numberColor
          ..strokeWidth = size * 0.08
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  static TextPainter _text(int value, double size, Color color) {
    final key = '$value|$size|${color.toARGB32()}';
    return _textCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: '$value',
          style: TextStyle(
            fontSize: size,
            color: color,
            fontWeight: FontWeight.w700,
            fontFamily: 'NotoSerif',
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}
