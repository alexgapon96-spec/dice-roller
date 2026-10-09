import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3, Vector3;

import 'geometry.dart';
import 'skins.dart';

const _speckDark = Color(0xB3252428);
const _speckLight = Color(0x99D4D2D9);
const _engraveColor = Color(0x99141317);

/// Camera distance from the die center, in die units (weak perspective).
const _cameraDistance = 6.0;

/// Light direction in view space (x right, y up, z towards the viewer).
final _light = Vector3(-0.35, 0.45, 1).normalized();

/// Half-way vector between light and view, for specular highlights.
final _halfway = (_light + Vector3(0, 0, 1)).normalized();

/// One die as it should appear on screen this frame.
class DieVisual {
  const DieVisual({
    required this.geometry,
    required this.rotation,
    required this.center,
    required this.radius,
    this.skin = DieSkin.granite,
    this.lift = 0,
    this.opacity = 1,
    this.glow,
  });

  final DieGeometry geometry;
  final Matrix3 rotation;
  final Offset center;

  /// Circumradius on screen, in logical pixels.
  final double radius;
  final DieSkin skin;

  /// 0 = resting on the felt, 1 = top of a bounce.
  final double lift;
  final double opacity;
  final Color? glow;
}

/// Software renderer for convex dice: back-face culling, flat shading, and
/// for translucent skins the back faces and inclusions seen through the body.
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
  /// shadow that fits it. Translucent dice let some light through.
  static void paintShadow(Canvas canvas, DieVisual d) {
    final r = d.radius;
    final offset = Offset(r * 0.08, r * 0.14) + Offset(r * 0.25, r * 0.4) * d.lift;
    final silhouette = Path();
    final project = _projector(d);
    for (final face in d.geometry.faces) {
      if (!_facesCamera(face, d.rotation)) continue;
      silhouette.addPath(_facePath(face, d.rotation, project), Offset.zero);
    }
    final density = 0.55 + 0.45 * d.skin.opacity;
    canvas.drawPath(
      silhouette.shift(offset),
      Paint()
        ..color = Color.fromRGBO(10, 0, 20, (0.5 - d.lift * 0.2) * d.opacity * density)
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
    final skin = d.skin;
    final rot = d.rotation;

    final faded = d.opacity < 1;
    if (faded) {
      canvas.saveLayer(
        Rect.fromCircle(center: d.center, radius: scale * 1.3),
        Paint()..color = Color.fromRGBO(0, 0, 0, d.opacity),
      );
    }

    final edgePaint = Paint()
      ..color = skin.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, scale * 0.012)
      ..strokeJoin = StrokeJoin.round;

    if (skin.translucent) {
      _paintBackFaces(canvas, d, project, scale);
      _paintInclusions(canvas, d, project, scale, (z) => 1);
    }

    final front = [
      for (final face in d.geometry.faces)
        if (_facesCamera(face, rot)) (face, _facePath(face, rot, project)),
    ];

    for (final (face, path) in front) {
      final n = rot.transformed(face.normal);
      final light = math.max(0.0, n.dot(_light));
      final brightness = 0.38 + 0.72 * light + 0.18 * math.pow(light, 12);
      canvas.drawPath(path, Paint()..color = _shade(skin.body, brightness, skin.opacity));

      final spec = math.pow(math.max(0.0, n.dot(_halfway)), 24) * skin.gloss;
      if (spec > 0.01) {
        canvas.drawPath(path, Paint()..color = Color.fromRGBO(255, 255, 255, spec.clamp(0.0, 0.6)));
      }
    }

    if (skin.translucent) {
      // Inclusions near the front read clearer through the surface than deep
      // ones: paint the near half again over the faces, fading with depth.
      _paintInclusions(canvas, d, project, scale, (z) => (z / 0.6).clamp(0.0, 1.0) * 0.65);
    }

    for (final (face, path) in front) {
      final c = rot.transformed(face.centroid);
      canvas.save();
      canvas.clipPath(path);
      if (skin.specks) _paintSpecks(canvas, face, rot, c, project, scale);
      for (final label in face.labels) {
        _paintLabel(canvas, label, rot, project, d.geometry.type, skin);
      }
      canvas.restore();

      canvas.drawPath(path, edgePaint);
    }

    if (faded) canvas.restore();
  }

  /// The far side of a translucent die, seen through the front faces.
  static void _paintBackFaces(Canvas canvas, DieVisual d, Offset Function(Vector3) project, double scale) {
    final skin = d.skin;
    final rot = d.rotation;
    // Back faces of a convex body tile its silhouette, so no sorting needed.
    final innerEdge = Paint()
      ..color = Color.lerp(skin.body, const Color(0xFFFFFFFF), 0.45)!.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.8, scale * 0.008);
    for (final face in d.geometry.faces) {
      if (_facesCamera(face, rot)) continue;
      final n = rot.transformed(face.normal);
      // Light entering through the front lights the inside of the back faces.
      final glowIn = math.max(0.0, -n.dot(_light));
      final path = _facePath(face, rot, project);
      canvas.drawPath(path, Paint()..color = _shade(skin.body, 0.32 + 0.4 * glowIn, 1));
      canvas.drawPath(path, innerEdge);
    }
  }

  /// Inclusions far to near, each at [alphaFor] its view-space depth z.
  static void _paintInclusions(
    Canvas canvas,
    DieVisual d,
    Offset Function(Vector3) project,
    double scale,
    double Function(double z) alphaFor,
  ) {
    final skin = d.skin;
    final rot = d.rotation;
    final items = inclusionsFor(d.geometry, skin);
    if (items.isEmpty) return;
    final rotated = [for (final i in items) (i, rot.transformed(i.position))]
      ..sort((a, b) => a.$2.z.compareTo(b.$2.z));
    for (final (inc, p) in rotated) {
      final alpha = alphaFor(p.z);
      if (alpha <= 0.01) continue;
      final u = rot.transformed(inc.u);
      final w = rot.transformed(inc.w);
      final n = u.cross(w);
      switch (skin.inclusions) {
        case InclusionKind.petals:
          _paintPetals(canvas, project, p, u, w, inc, n.dot(_light).abs(), alpha);
        case InclusionKind.shards:
          _paintShard(canvas, project, p, u, w, inc, n, alpha);
        case InclusionKind.glitter:
        case InclusionKind.dust:
          final sparkle = math.pow(n.dot(_halfway).abs(), 8).toDouble();
          final r = inc.size * scale * (0.6 + sparkle);
          canvas.drawCircle(
            project(p),
            r,
            Paint()..color = inc.color.withValues(alpha: (0.55 + 0.45 * sparkle) * alpha),
          );
        case InclusionKind.none:
      }
    }
  }

  /// A small flower: two crossed petals lying in the inclusion's plane.
  static void _paintPetals(
    Canvas canvas,
    Offset Function(Vector3) project,
    Vector3 p,
    Vector3 u,
    Vector3 w,
    Inclusion inc,
    double facing,
    double alpha,
  ) {
    final o = project(p);
    final a = project(p + u * inc.size) - o;
    final b = project(p + w * inc.size) - o;
    final paint = Paint()..color = _shade(inc.color, 0.75 + 0.45 * facing, 0.95 * alpha);
    for (final (long, short) in [(a, b * 0.42), (b, a * 0.42)]) {
      canvas.save();
      canvas.transform(Float64List.fromList([
        long.dx, long.dy, 0, 0, //
        short.dx, short.dy, 0, 0, //
        0, 0, 1, 0, //
        o.dx, o.dy, 0, 1,
      ]));
      canvas.drawCircle(Offset.zero, 1, paint);
      canvas.restore();
    }
  }

  /// A flat foil flake that flashes white when it catches the light.
  static void _paintShard(
    Canvas canvas,
    Offset Function(Vector3) project,
    Vector3 p,
    Vector3 u,
    Vector3 w,
    Inclusion inc,
    Vector3 n,
    double alpha,
  ) {
    final s = inc.size;
    final path = Path()
      ..addPolygon([
        project(p + u * s),
        project(p + w * s),
        project(p - (u + w) * (s * 0.7)),
      ], true);
    final glint = math.pow(n.dot(_halfway).abs(), 6).toDouble();
    final color = Color.lerp(_shade(inc.color, 0.6 + 0.5 * n.dot(_light).abs(), 1), const Color(0xFFFFFFFF), glint)!;
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.9 * alpha));
  }

  static void paint(Canvas canvas, DieVisual d) {
    paintGlow(canvas, d);
    paintShadow(canvas, d);
    paintDie(canvas, d);
  }

  static Color _shade(Color c, double k, double alpha) => Color.fromARGB(
        (alpha * 255).round().clamp(0, 255),
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
    DieSkin skin,
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
    final shadow = _text(label.value, size, _engraveColor, metallic: false);
    final text = _text(label.value, size, skin.number, metallic: skin.metallicNumbers);
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
          ..color = skin.number
          ..strokeWidth = size * 0.08
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  /// Inlaid-metal numbers get a light-to-dark sheen across the glyph.
  static TextPainter _text(int value, double size, Color color, {required bool metallic}) {
    final key = '$value|$size|${color.toARGB32()}|$metallic';
    return _textCache.putIfAbsent(key, () {
      final style = TextStyle(
        fontSize: size,
        fontWeight: FontWeight.w700,
        fontFamily: 'NotoSerif',
        height: 1,
      );
      final Paint fill = Paint();
      if (metallic) {
        fill.shader = ui.Gradient.linear(
          // Labels are drawn centred on the origin.
          Offset(0, -size / 2),
          Offset(0, size / 2),
          [
            Color.lerp(color, const Color(0xFFFFFFFF), 0.45)!,
            color,
            Color.lerp(color, const Color(0xFF000000), 0.35)!,
          ],
          [0, 0.45, 1],
        );
      } else {
        fill.color = color;
      }
      return TextPainter(
        text: TextSpan(text: '$value', style: style.copyWith(foreground: fill)),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }
}
