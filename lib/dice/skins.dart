import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

import 'geometry.dart';

/// What is embedded inside a translucent die.
enum InclusionKind {
  none,

  /// Small blue flowers: two crossed petals each.
  petals,

  /// Flat foil flakes that glint as they turn.
  shards,

  /// Tiny iridescent sparkles.
  glitter,

  /// Fine gold dust.
  dust,
}

/// Look of a die: body material, numbers and inclusions.
class DieSkin {
  const DieSkin({
    required this.id,
    required this.name,
    required this.body,
    required this.edge,
    required this.number,
    this.opacity = 1,
    this.specks = false,
    this.inclusions = InclusionKind.none,
    this.inclusionColors = const [],
    this.gloss = 0.2,
  });

  final String id;
  final String name;

  /// Mid-tone body colour; faces are shaded from it.
  final Color body;
  final Color edge;
  final Color number;

  /// Alpha of the faces facing the camera; below 1 the inside shows through.
  final double opacity;

  /// Granite-style specks on the surface.
  final bool specks;
  final InclusionKind inclusions;
  final List<Color> inclusionColors;

  /// Strength of the specular highlight on faces turned towards the light.
  final double gloss;

  bool get translucent => opacity < 1;

  /// White numbers are painted flat; coloured ones look like inlaid metal.
  bool get metallicNumbers => number != granite.number;

  static const granite = DieSkin(
    id: 'granite',
    name: 'Granite',
    body: Color(0xFF7C7A83),
    edge: Color(0xFF2E2D33),
    number: Color(0xFFF4F4F4),
    specks: true,
    gloss: 0.18,
  );

  static const all = [
    granite,
    DieSkin(
      id: 'moonpetal',
      name: 'Moonpetal',
      body: Color(0xFFF1E2EE),
      edge: Color(0xFFB9A3B8),
      number: Color(0xFFD4AF37),
      opacity: 0.58,
      inclusions: InclusionKind.petals,
      inclusionColors: [Color(0xFF14248A), Color(0xFF1D36B0), Color(0xFF0E1A66)],
      gloss: 0.35,
    ),
    DieSkin(
      id: 'ocean',
      name: 'Ocean Shards',
      body: Color(0xFF2A82CC),
      edge: Color(0xFF0F3F73),
      number: Color(0xFFEF8A2B),
      opacity: 0.74,
      inclusions: InclusionKind.shards,
      inclusionColors: [Color(0xFFBFE9FF), Color(0xFFE8F8FF), Color(0xFF5FC2FF), Color(0xFF0D3C70)],
      gloss: 0.45,
    ),
    DieSkin(
      id: 'amethyst',
      name: 'Amethyst',
      body: Color(0xFF8A52CF),
      edge: Color(0xFF4A2088),
      number: Color(0xFFE3B742),
      opacity: 0.6,
      gloss: 0.75,
    ),
    DieSkin(
      id: 'opal',
      name: 'Opal Frost',
      body: Color(0xFFECE7F6),
      edge: Color(0xFFB8AECF),
      number: Color(0xFF3FB8C4),
      opacity: 0.7,
      inclusions: InclusionKind.glitter,
      inclusionColors: [
        Color(0xFFFF9AD5),
        Color(0xFF8DE9F2),
        Color(0xFFC6A8FF),
        Color(0xFFFFFFFF),
        Color(0xFFFFE08A),
      ],
      gloss: 0.4,
    ),
    DieSkin(
      id: 'starry',
      name: 'Starry Night',
      body: Color(0xFF222A55),
      edge: Color(0xFF0E1230),
      number: Color(0xFFE3B742),
      opacity: 0.78,
      inclusions: InclusionKind.dust,
      inclusionColors: [Color(0xFFF0C95A), Color(0xFFFFE6A0), Color(0xFFD9A938)],
      gloss: 0.5,
    ),
    DieSkin(
      id: 'emerald',
      name: 'Emerald',
      body: Color(0xFF1FA85A),
      edge: Color(0xFF0B5A2E),
      number: Color(0xFFE3B742),
      opacity: 0.58,
      gloss: 0.8,
    ),
    DieSkin(
      id: 'ruby',
      name: 'Ruby',
      body: Color(0xFFD42530),
      edge: Color(0xFF7A0C14),
      number: Color(0xFFE3B742),
      opacity: 0.58,
      gloss: 0.8,
    ),
  ];

  static DieSkin byId(String? id) => all.firstWhere((s) => s.id == id, orElse: () => granite);
}

/// One thing embedded in a die, in die space.
class Inclusion {
  const Inclusion(this.position, this.u, this.w, this.size, this.color);

  final Vector3 position;

  /// Two unit axes spanning the inclusion's plane (its normal is u × w).
  final Vector3 u;
  final Vector3 w;
  final double size;
  final Color color;
}

/// Inclusions for a die/skin pair, spread evenly through the die's inside:
/// a jittered 3D grid, clipped to the polyhedron with a margin from the faces.
List<Inclusion> inclusionsFor(DieGeometry geometry, DieSkin skin) {
  final key = '${geometry.type.label}|${skin.id}';
  return _inclusionCache.putIfAbsent(key, () => _generate(geometry, skin));
}

final _inclusionCache = <String, List<Inclusion>>{};

List<Inclusion> _generate(DieGeometry geometry, DieSkin skin) {
  final (step, size, margin) = switch (skin.inclusions) {
    InclusionKind.none => (0.0, 0.0, 0.0),
    InclusionKind.petals => (0.34, 0.11, 0.12),
    InclusionKind.shards => (0.17, 0.045, 0.06),
    InclusionKind.glitter => (0.14, 0.024, 0.04),
    InclusionKind.dust => (0.12, 0.018, 0.04),
  };
  if (step == 0) return const [];
  final rnd = math.Random(geometry.type.sides * 31 + skin.inclusions.index);
  final out = <Inclusion>[];
  bool inside(Vector3 p) => geometry.faces.every((f) => (p - f.centroid).dot(f.normal) < -margin);

  // Cell centres symmetric about the die centre, so no half gets more.
  final cells = (1 / step).ceil();
  final coords = [for (var i = -cells; i < cells; i++) (i + 0.5) * step];
  for (final x in coords) {
    for (final y in coords) {
      for (final z in coords) {
        final p = Vector3(
          x + (rnd.nextDouble() - 0.5) * step * 0.8,
          y + (rnd.nextDouble() - 0.5) * step * 0.8,
          z + (rnd.nextDouble() - 0.5) * step * 0.8,
        );
        if (!inside(p)) continue;
        final u = _randomUnit(rnd);
        final w = u.cross(_randomUnit(rnd))..normalize();
        out.add(Inclusion(
          p,
          u,
          w,
          size * (0.7 + rnd.nextDouble() * 0.6),
          skin.inclusionColors[rnd.nextInt(skin.inclusionColors.length)],
        ));
      }
    }
  }
  return out;
}

Vector3 _randomUnit(math.Random rnd) {
  final z = rnd.nextDouble() * 2 - 1;
  final a = rnd.nextDouble() * math.pi * 2;
  final r = math.sqrt(1 - z * z);
  return Vector3(r * math.cos(a), r * math.sin(a), z);
}
