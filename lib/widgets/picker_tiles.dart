import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3;

import '../dice/die_renderer.dart';
import '../dice/geometry.dart';
import '../dice/skins.dart';
import '../settings.dart';

const sheetColor = Color(0xFF2A1A40);
const tileColor = Color(0xFF3A2756);
const selectedColor = Color(0xFF6A4A96);
const labelColor = Color(0xFFE8E0F2);
const mutedLabelColor = Color(0xFFBFB0D6);

/// 3-column grid of tiles, sized by its content.
Widget pickerGrid(List<Widget> tiles) => GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      physics: const NeverScrollableScrollPhysics(),
      children: tiles,
    );

/// The six dice, drawn in the current skin.
List<Widget> diceTiles(AppSettings settings, ValueChanged<DieType> onPick) => [
      for (final type in DieType.values)
        PickerTile(
          label: type.label,
          painter: DieIconPainter(type, settings.skin),
          selected: type == settings.dieType,
          onTap: () => onPick(type),
        ),
    ];

/// Every skin as a d20; tapping one applies it straight away.
List<Widget> skinTiles(AppSettings settings) => [
      for (final skin in DieSkin.all)
        PickerTile(
          label: skin.name,
          painter: DieIconPainter(DieType.d20, skin),
          selected: skin.id == settings.skin.id,
          onTap: () => settings.skin = skin,
        ),
    ];

/// Grid tile: a die drawn by [painter] above a label.
class PickerTile extends StatelessWidget {
  const PickerTile({
    super.key,
    required this.label,
    required this.painter,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final CustomPainter painter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : tileColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: selected ? const BorderSide(color: Color(0xFFD9CDEA), width: 1.5) : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
          child: Column(
            children: [
              Expanded(child: CustomPaint(painter: painter, size: Size.infinite)),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A die at rest, tilted a little so it reads as a solid, not a flat outline.
class DieIconPainter extends CustomPainter {
  DieIconPainter(this.type, this.skin);

  final DieType type;
  final DieSkin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = DieGeometry.of(type);
    final rotation = Matrix3.rotationX(-0.45).multiplied(geometry.restRotation(type.sides, yaw: 0.25));
    DieRenderer.paintDie(
      canvas,
      DieVisual(
        geometry: geometry,
        rotation: rotation,
        center: size.center(Offset.zero),
        radius: size.shortestSide * 0.46,
        skin: skin,
      ),
    );
  }

  @override
  bool shouldRepaint(DieIconPainter oldDelegate) => oldDelegate.type != type || oldDelegate.skin != skin;
}

/// Round icon button; when off, the icon dims and gets crossed out.
class ToggleIconButton extends StatelessWidget {
  const ToggleIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.on,
    required this.onTap,
    this.size = 56,
  });

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;
  final double size;

  static const _offColor = Color(0xFF8D7FA6);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      label: label,
      child: Tooltip(
        message: '$label ${on ? 'on' : 'off'}',
        child: Material(
          color: tileColor,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: size * 0.46, color: on ? labelColor : _offColor),
                  if (!on)
                    Transform.rotate(
                      angle: -math.pi / 4,
                      child: Container(
                        width: size * 0.64,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: labelColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
