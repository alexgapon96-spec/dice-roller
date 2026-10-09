// Renders the app icon PNGs with the same renderer the app uses.
//
//   flutter test tool/icon/render_icon_test.dart
//   dart run flutter_launcher_icons
//
// Writes assets/icon/{icon,foreground,background}.png.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:dice_roller/dice/die_renderer.dart';
import 'package:dice_roller/dice/geometry.dart';
import 'package:dice_roller/widgets/felt_background.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _size = 1024.0;
const _gold = Color(0xFFE8B84E);

void main() {
  testWidgets('render app icon', (tester) async {
    await tester.runAsync(() async {
      // flutter_test only has a placeholder font; load the one the app bundles.
      final font = File('assets/fonts/NotoSerif-Bold.ttf').readAsBytesSync();
      await (FontLoader('NotoSerif')..addFont(Future.value(ByteData.sublistView(font)))).load();

      final geometry = DieGeometry.of(DieType.d20);
      final rotation = geometry.restRotation(20);
      DieVisual die(double radius) => DieVisual(
            geometry: geometry,
            rotation: rotation,
            center: const Offset(_size / 2, _size / 2),
            radius: radius,
            glow: _gold,
          );

      Directory('assets/icon').createSync(recursive: true);

      // iOS and legacy Android: everything on one opaque square.
      await _save('assets/icon/icon.png', (canvas) {
        const FeltPainter().paint(canvas, const Size(_size, _size));
        DieRenderer.paintGlow(canvas, die(_size * 0.3));
        DieRenderer.paint(canvas, die(_size * 0.3));
      });

      // Android adaptive icon: the launcher masks to ~66% of the canvas.
      await _save('assets/icon/foreground.png', (canvas) {
        DieRenderer.paintGlow(canvas, die(_size * 0.31));
        DieRenderer.paint(canvas, die(_size * 0.31));
      });
      await _save('assets/icon/background.png', (canvas) {
        const FeltPainter().paint(canvas, const Size(_size, _size));
      });
    });
  });
}

Future<void> _save(String path, void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder));
  final image = await recorder.endRecording().toImage(_size.toInt(), _size.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  File(path).writeAsBytesSync(png!.buffer.asUint8List());
}
