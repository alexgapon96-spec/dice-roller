import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart' show Matrix3, Vector3;

enum DieType {
  d4(4),
  d6(6),
  d8(8),
  d10(10),
  d12(12),
  d20(20);

  const DieType(this.sides);

  final int sides;

  String get label => 'd$sides';

  static DieType fromLabel(String? label) =>
      values.firstWhere((t) => t.label == label, orElse: () => d20);
}

/// A number printed on a face, positioned and oriented in die space.
class DieLabel {
  DieLabel(this.position, this.up, this.right, this.value, this.fontSize);

  final Vector3 position;
  final Vector3 up;
  final Vector3 right;
  final int value;

  /// In die units (the die's circumradius is 1).
  final double fontSize;
}

/// A granite speck in the face's local (right, up) coordinates.
class Speck {
  const Speck(this.u, this.v, this.radius, this.light);

  final double u;
  final double v;
  final double radius;
  final bool light;
}

class DieFace {
  DieFace(this.vertices, this.normal, this.centroid, this.inradius, this.circumradius);

  /// Counter-clockwise when seen from outside.
  final List<Vector3> vertices;
  final Vector3 normal;
  final Vector3 centroid;
  final double inradius;
  final double circumradius;

  /// Text frame: the direction a number's top points to.
  late Vector3 up;
  late Vector3 right;

  int value = 0;
  final List<DieLabel> labels = [];
  final List<Speck> specks = [];
}

/// Polyhedron for one die type, normalized to circumradius 1.
class DieGeometry {
  DieGeometry._(this.type, this.faces, this._vertexByValue);

  final DieType type;
  final List<DieFace> faces;

  /// d4 only: the vertex direction whose number is read when it points up.
  final Map<int, Vector3> _vertexByValue;

  static final _cache = <DieType, DieGeometry>{};

  factory DieGeometry.of(DieType type) => _cache.putIfAbsent(type, () => _build(type));

  /// Rotation that rests the die with [value] facing the camera (+Z) and its
  /// number upright (+Y), then turned by [yaw] around the view axis.
  Matrix3 restRotation(int value, {double yaw = 0}) {
    final Vector3 target;
    final Vector3 up;
    if (type == DieType.d4) {
      target = _vertexByValue[value]!;
      final helper = target.z.abs() < 0.9 ? Vector3(0, 0, 1) : Vector3(1, 0, 0);
      up = helper.cross(target).normalized();
    } else {
      final face = faces.firstWhere((f) => f.value == value);
      target = face.normal;
      up = face.up;
    }
    final right = up.cross(target);
    final m = Matrix3.columns(right, up, target)..transpose();
    return Matrix3.rotationZ(yaw).multiplied(m);
  }

  static DieGeometry _build(DieType type) {
    var polys = switch (type) {
      DieType.d4 => _tetrahedron(),
      DieType.d6 => _cube(),
      DieType.d8 => _octahedron(),
      DieType.d10 => _trapezohedron(),
      DieType.d12 => _dodecahedron(),
      DieType.d20 => _icosahedron(),
    };
    var maxR = 0.0;
    for (final p in polys) {
      for (final v in p) {
        maxR = math.max(maxR, v.length);
      }
    }
    polys = [
      for (final p in polys) [for (final v in p) v / maxR],
    ];
    final faces = polys.map(_makeFace).toList();
    final vertexByValue = <int, Vector3>{};

    for (final f in faces) {
      final Vector3 anchor = switch (type) {
        DieType.d6 => (f.vertices[0] + f.vertices[1]) / 2,
        DieType.d10 => f.vertices.reduce((a, b) => a.z.abs() >= b.z.abs() ? a : b),
        _ => f.vertices[0],
      };
      _setFrame(f, anchor);
    }

    if (type == DieType.d4) {
      final verts = <Vector3>[];
      for (final f in faces) {
        for (final v in f.vertices) {
          if (!verts.any((w) => (w - v).length < 1e-6)) verts.add(v);
        }
      }
      for (var i = 0; i < verts.length; i++) {
        vertexByValue[i + 1] = verts[i].normalized();
      }
      for (final f in faces) {
        for (final v in f.vertices) {
          final value = verts.indexWhere((w) => (w - v).length < 1e-6) + 1;
          // Close enough to the corner to read as "its" number, far enough
          // from the edges not to be clipped.
          final pos = f.centroid + (v - f.centroid) * 0.44;
          final up = _inPlane(v - f.centroid, f.normal);
          f.labels.add(DieLabel(pos, up, up.cross(f.normal), value, f.inradius * 0.85));
        }
      }
    } else {
      final n = faces.length;
      var k = 1;
      for (final f in faces) {
        if (f.value != 0) continue;
        f.value = k;
        faces.firstWhere((g) => g.normal.dot(f.normal) < -0.999).value = n + 1 - k;
        k++;
      }
      final scale = switch (type) {
        DieType.d6 => 1.05,
        DieType.d8 => 1.05,
        DieType.d10 => 1.15,
        DieType.d12 => 0.9,
        _ => 0.95,
      };
      for (final f in faces) {
        var pos = f.centroid;
        if (type == DieType.d10) {
          // The kite's wide half sits away from the apex; numbers live there.
          pos = f.centroid - f.up * (f.inradius * 0.25);
        }
        f.labels.add(DieLabel(pos, f.up, f.right, f.value, f.inradius * scale));
      }
    }

    for (var i = 0; i < faces.length; i++) {
      final f = faces[i];
      final rnd = math.Random(type.sides * 97 + i);
      final r = f.circumradius;
      final count = (r * r * 260).round();
      for (var s = 0; s < count; s++) {
        final a = rnd.nextDouble() * math.pi * 2;
        final d = math.sqrt(rnd.nextDouble()) * r;
        f.specks.add(Speck(
          math.cos(a) * d,
          math.sin(a) * d,
          0.004 + rnd.nextDouble() * 0.012,
          rnd.nextDouble() < 0.45,
        ));
      }
    }

    return DieGeometry._(type, faces, vertexByValue);
  }

  static Vector3 _inPlane(Vector3 v, Vector3 normal) =>
      (v - normal * v.dot(normal)).normalized();

  static void _setFrame(DieFace f, Vector3 anchor) {
    f.up = _inPlane(anchor - f.centroid, f.normal);
    f.right = f.up.cross(f.normal);
  }

  static DieFace _makeFace(List<Vector3> pts) {
    final c = pts.fold(Vector3.zero(), (a, b) => a + b) / pts.length.toDouble();
    final approx = c.normalized();
    final a = (pts[0] - c).normalized();
    final b = approx.cross(a);
    double angle(Vector3 p) => math.atan2((p - c).dot(b), (p - c).dot(a));
    final sorted = [...pts]..sort((p, q) => angle(p).compareTo(angle(q)));
    var n = (sorted[1] - sorted[0]).cross(sorted[2] - sorted[0]).normalized();
    if (n.dot(c) < 0) n = -n;
    var inr = double.infinity;
    var circ = 0.0;
    for (var i = 0; i < sorted.length; i++) {
      final e0 = sorted[i];
      final e1 = sorted[(i + 1) % sorted.length];
      final edge = e1 - e0;
      inr = math.min(inr, (c - e0).cross(edge).length / edge.length);
      circ = math.max(circ, (e0 - c).length);
    }
    return DieFace(sorted, n, c, inr, circ);
  }

  static List<List<Vector3>> _tetrahedron() {
    final v = [
      Vector3(1, 1, 1),
      Vector3(1, -1, -1),
      Vector3(-1, 1, -1),
      Vector3(-1, -1, 1),
    ];
    return [
      for (var skip = 0; skip < 4; skip++) [for (var i = 0; i < 4; i++) if (i != skip) v[i]],
    ];
  }

  static List<List<Vector3>> _cube() {
    final verts = [
      for (final x in [-1.0, 1.0])
        for (final y in [-1.0, 1.0])
          for (final z in [-1.0, 1.0]) Vector3(x, y, z),
    ];
    return [
      for (var axis = 0; axis < 3; axis++)
        for (final s in [-1.0, 1.0]) verts.where((v) => v[axis] == s).toList(),
    ];
  }

  static List<List<Vector3>> _octahedron() => [
        for (final sx in [-1.0, 1.0])
          for (final sy in [-1.0, 1.0])
            for (final sz in [-1.0, 1.0]) [Vector3(sx, 0, 0), Vector3(0, sy, 0), Vector3(0, 0, sz)],
      ];

  /// Pentagonal trapezohedron (d10) with planar kite faces.
  static List<List<Vector3>> _trapezohedron() {
    const h = 1.15;
    final c36 = math.cos(math.pi / 5);
    final a = h * (1 - c36) / (1 + c36);
    Vector3 ring(int i, double z) {
      final ang = i * math.pi / 5;
      return Vector3(math.cos(ang), math.sin(ang), z);
    }

    Vector3 up(int j) => ring(2 * j, a);
    Vector3 low(int j) => ring(2 * j + 1, -a);
    final top = Vector3(0, 0, h);
    final bottom = Vector3(0, 0, -h);
    return [
      for (var j = 0; j < 5; j++) [top, up(j), low(j), up(j + 1)],
      for (var j = 0; j < 5; j++) [bottom, low(j), up(j + 1), low(j + 1)],
    ];
  }

  static List<Vector3> _icosaVertices() {
    final p = (1 + math.sqrt(5)) / 2;
    return [
      for (final a in [-1.0, 1.0])
        for (final b in [-p, p]) ...[Vector3(0, a, b), Vector3(a, b, 0), Vector3(b, 0, a)],
    ];
  }

  static List<List<int>> _icosaFaceIndices(List<Vector3> v) {
    bool edge(int i, int j) => ((v[i] - v[j]).length - 2).abs() < 1e-6;
    return [
      for (var i = 0; i < v.length; i++)
        for (var j = i + 1; j < v.length; j++)
          if (edge(i, j))
            for (var k = j + 1; k < v.length; k++)
              if (edge(i, k) && edge(j, k)) [i, j, k],
    ];
  }

  static List<List<Vector3>> _icosahedron() {
    final v = _icosaVertices();
    return [
      for (final f in _icosaFaceIndices(v)) [for (final i in f) v[i]],
    ];
  }

  /// Dual of the icosahedron: one pentagon per icosahedron vertex.
  static List<List<Vector3>> _dodecahedron() {
    final v = _icosaVertices();
    final faces = _icosaFaceIndices(v);
    Vector3 center(List<int> f) => (v[f[0]] + v[f[1]] + v[f[2]]) / 3;
    return [
      for (var i = 0; i < v.length; i++) [for (final f in faces) if (f.contains(i)) center(f)],
    ];
  }
}
