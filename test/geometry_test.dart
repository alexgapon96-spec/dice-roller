import 'package:dice_roller/dice/geometry.dart';
import 'package:dice_roller/dice/roll.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

void main() {
  for (final type in DieType.values) {
    group(type.label, () {
      final geo = DieGeometry.of(type);

      test('has the right number of planar, outward faces', () {
        final expectedFaces = type == DieType.d4 ? 4 : type.sides;
        expect(geo.faces, hasLength(expectedFaces));
        for (final f in geo.faces) {
          expect(f.normal.dot(f.centroid), greaterThan(0));
          for (final v in f.vertices) {
            expect((v - f.centroid).dot(f.normal).abs(), lessThan(1e-6));
          }
        }
      });

      test('every value 1..N appears', () {
        final values = type == DieType.d4
            ? {for (final f in geo.faces) for (final l in f.labels) l.value}
            : {for (final f in geo.faces) f.value};
        expect(values, {for (var v = 1; v <= type.sides; v++) v});
      });

      test('rest pose turns each value towards the camera, upright', () {
        for (var v = 1; v <= type.sides; v++) {
          final m = geo.restRotation(v);
          if (type == DieType.d4) {
            // The top vertex points at the camera; its number is on the three
            // faces around it.
            final top = geo.faces
                .expand((f) => f.labels)
                .where((l) => l.value == v)
                .map((l) => m.transformed(l.position));
            for (final p in top) {
              expect(p.z, greaterThan(0));
            }
          } else {
            final face = geo.faces.firstWhere((f) => f.value == v);
            final n = m.transformed(face.normal);
            final up = m.transformed(face.up);
            expect((n - Vector3(0, 0, 1)).length, lessThan(1e-6));
            expect((up - Vector3(0, 1, 0)).length, lessThan(1e-6));
          }
        }
      });
    });
  }

  test('opposite faces sum to N + 1', () {
    for (final type in DieType.values.where((t) => t != DieType.d4)) {
      final faces = DieGeometry.of(type).faces;
      for (final f in faces) {
        final opp = faces.firstWhere((g) => g.normal.dot(f.normal) < -0.999);
        expect(f.value + opp.value, type.sides + 1, reason: type.label);
      }
    }
  });

  test('rolls settle exactly on the rest pose', () {
    final geo = DieGeometry.of(DieType.d20);
    for (var i = 0; i < 50; i++) {
      final roll = DieRoll.random(geo);
      final face = geo.faces.firstWhere((f) => f.value == roll.value);
      final n = roll.rotationAt(1).transformed(face.normal);
      expect(n.z, closeTo(1, 1e-9));
      expect(roll.offsetAt(1), Offset.zero);
      expect(roll.liftAt(1), closeTo(0, 1e-9));
    }
  });

  test('the die is on the felt at every landing and still after the last', () {
    final roll = DieRoll.random(DieGeometry.of(DieType.d20));
    for (final t in DieRoll.landings) {
      expect(roll.liftAt(t), closeTo(0, 1e-9), reason: 'landing at $t');
    }
    expect(roll.liftAt(0.5), greaterThan(0));
    final last = DieRoll.landings.last;
    final rest = roll.rotationAt(last);
    final end = roll.rotationAt(1);
    for (var i = 0; i < 9; i++) {
      expect(rest.storage[i], closeTo(end.storage[i], 1e-9));
    }
    expect(roll.offsetAt(last), roll.offsetAt(1));
  });

  test('advantage counts the higher die, disadvantage the lower, ties both', () {
    final geo = DieGeometry.of(DieType.d20);
    final a = DieRoll.resting(geo, 17);
    final b = DieRoll.resting(geo, 6);
    expect(countedDice([a, b], RollMode.advantage), {0});
    expect(countedDice([a, b], RollMode.disadvantage), {1});
    expect(countedDice([a, DieRoll.resting(geo, 17)], RollMode.advantage), {0, 1});
    expect(countedDice([a], RollMode.normal), {0});
  });

  test('random rolls are roughly uniform', () {
    final geo = DieGeometry.of(DieType.d6);
    final counts = List.filled(7, 0);
    const n = 60000;
    for (var i = 0; i < n; i++) {
      counts[DieRoll.random(geo).value]++;
    }
    for (var v = 1; v <= 6; v++) {
      expect((counts[v] / n - 1 / 6).abs(), lessThan(0.01), reason: 'value $v');
    }
    expect(counts[0], 0);
  });
}
