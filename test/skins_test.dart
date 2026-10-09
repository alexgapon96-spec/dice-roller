import 'package:dice_roller/dice/geometry.dart';
import 'package:dice_roller/dice/skins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('skin ids are unique and unknown ids fall back to granite', () {
    final ids = DieSkin.all.map((s) => s.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    expect(DieSkin.byId('ruby').name, 'Ruby');
    expect(DieSkin.byId('nope'), DieSkin.granite);
    expect(DieSkin.byId(null), DieSkin.granite);
  });

  final withInclusions = DieSkin.all.where((s) => s.inclusions != InclusionKind.none);

  for (final skin in withInclusions) {
    group(skin.name, () {
      for (final type in DieType.values) {
        test('${type.label}: inclusions sit inside the die', () {
          final geo = DieGeometry.of(type);
          final items = inclusionsFor(geo, skin);
          expect(items, isNotEmpty);
          for (final i in items) {
            for (final f in geo.faces) {
              expect((i.position - f.centroid).dot(f.normal), lessThan(0));
            }
          }
        });
      }

      test('d20: inclusions are spread evenly, not clumped', () {
        final items = inclusionsFor(DieGeometry.of(DieType.d20), skin);
        // Jittered grid: no two closer than a fraction of the grid step, and
        // every octant of the die gets a fair share.
        var closest = double.infinity;
        for (var a = 0; a < items.length; a++) {
          for (var b = a + 1; b < items.length; b++) {
            final d = (items[a].position - items[b].position).length;
            if (d < closest) closest = d;
          }
        }
        expect(closest, greaterThan(0.01));
        final octants = List.filled(8, 0);
        for (final i in items) {
          final p = i.position;
          octants[(p.x > 0 ? 1 : 0) + (p.y > 0 ? 2 : 0) + (p.z > 0 ? 4 : 0)]++;
        }
        final mean = items.length / 8;
        for (final n in octants) {
          // Few large items (petals) get an absolute allowance instead.
          final slack = (mean * 0.4).clamp(3.0, double.infinity);
          expect(n, inInclusiveRange(mean - slack, mean + slack));
        }
      });
    });
  }
}
