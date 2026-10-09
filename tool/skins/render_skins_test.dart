// Renders every skin on the felt into one preview sheet, for design review.
//
//   flutter test tool/skins/render_skins_test.dart
//
// Writes build/skins_preview.png.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dice_roller/dice/die_renderer.dart';
import 'package:dice_roller/dice/geometry.dart';
import 'package:dice_roller/dice/skins.dart';
import 'package:dice_roller/widgets/felt_background.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3;

const _cell = 420.0;
const _cols = 4;

void main() {
  testWidgets('render skins preview', (tester) async {
    await tester.runAsync(() async {
      final font = File('assets/fonts/NotoSerif-Bold.ttf').readAsBytesSync();
      await (FontLoader('NotoSerif')..addFont(Future.value(ByteData.sublistView(font)))).load();

      final skins = DieSkin.all;
      final rows = (skins.length / _cols).ceil();
      final size = Size(_cell * _cols, _cell * rows);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const FeltPainter().paint(canvas, size);

      final d20 = DieGeometry.of(DieType.d20);
      final d6 = DieGeometry.of(DieType.d6);
      for (var i = 0; i < skins.length; i++) {
        final origin = Offset((i % _cols) * _cell, (i ~/ _cols) * _cell);
        // A d20 at rest, slightly tilted so the inside and side faces show,
        // plus a small d6 to check another shape.
        DieRenderer.paint(
          canvas,
          DieVisual(
            geometry: d20,
            rotation: Matrix3.rotationX(-0.35).multiplied(d20.restRotation(20, yaw: 0.2)),
            center: origin + const Offset(_cell * 0.42, _cell * 0.42),
            radius: _cell * 0.3,
            skin: skins[i],
          ),
        );
        DieRenderer.paint(
          canvas,
          DieVisual(
            geometry: d6,
            rotation: Matrix3.rotationX(-0.5).multiplied(d6.restRotation(6, yaw: 0.5)),
            center: origin + const Offset(_cell * 0.8, _cell * 0.78),
            radius: _cell * 0.13,
            skin: skins[i],
          ),
        );
        final name = TextPainter(
          text: TextSpan(
            text: skins[i].name,
            style: const TextStyle(fontFamily: 'NotoSerif', fontSize: 26, color: Color(0xFFE8E0F2)),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        name.paint(canvas, origin + Offset(24, _cell - 50));
      }

      final image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      Directory('build').createSync(recursive: true);
      File('build/skins_preview.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
