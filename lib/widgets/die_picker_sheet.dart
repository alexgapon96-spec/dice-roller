import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3;

import '../dice/die_renderer.dart';
import '../dice/geometry.dart';
import '../feedback/roll_feedback.dart';
import '../settings.dart';

const sheetColor = Color(0xFF2A1A40);

/// Settings sheet: vibration and sound toggles, then the six dice.
/// Resolves to the picked die type, or null if dismissed.
Future<DieType?> showDiePicker(BuildContext context, AppSettings settings) {
  return showModalBottomSheet<DieType>(
    context: context,
    backgroundColor: sheetColor,
    showDragHandle: true,
    // Keeps the dice tiles phone-sized in wide desktop browser windows.
    constraints: const BoxConstraints(maxWidth: 440),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (RollFeedback.hapticsSupported) ...[
                    _Toggle(
                      icon: Icons.vibration,
                      label: 'Vibration',
                      on: settings.vibrationOn,
                      onTap: () => settings.vibrationOn = !settings.vibrationOn,
                    ),
                    const SizedBox(width: 20),
                  ],
                  _Toggle(
                    icon: Icons.volume_up_outlined,
                    label: 'Sound',
                    on: settings.soundOn,
                    onTap: () => settings.soundOn = !settings.soundOn,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final type in DieType.values)
                    _DieTile(
                      type: type,
                      selected: type == settings.dieType,
                      onTap: () => Navigator.of(context).pop(type),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Round icon button; when off, the icon dims and gets crossed out.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.on, required this.onTap});

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  static const _onColor = Color(0xFFE8E0F2);
  static const _offColor = Color(0xFF8D7FA6);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      label: label,
      child: Tooltip(
        message: '$label ${on ? 'on' : 'off'}',
        child: Material(
          color: const Color(0xFF3A2756),
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: 26, color: on ? _onColor : _offColor),
                  if (!on)
                    Transform.rotate(
                      angle: -math.pi / 4,
                      child: Container(
                        width: 36,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: _onColor,
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

class _DieTile extends StatelessWidget {
  const _DieTile({required this.type, required this.selected, required this.onTap});

  final DieType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFF6A4A96) : const Color(0xFF3A2756),
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
              Expanded(child: CustomPaint(painter: _DieIconPainter(type), size: Size.infinite)),
              const SizedBox(height: 6),
              Text(
                type.label,
                style: const TextStyle(color: Color(0xFFE8E0F2), fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DieIconPainter extends CustomPainter {
  _DieIconPainter(this.type);

  final DieType type;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = DieGeometry.of(type);
    // Tilted a little so the die reads as a solid, not a flat outline.
    final rotation = Matrix3.rotationX(-0.45).multiplied(geometry.restRotation(type.sides, yaw: 0.25));
    DieRenderer.paintDie(
      canvas,
      DieVisual(
        geometry: geometry,
        rotation: rotation,
        center: size.center(Offset.zero),
        radius: size.shortestSide * 0.46,
      ),
    );
  }

  @override
  bool shouldRepaint(_DieIconPainter oldDelegate) => oldDelegate.type != type;
}
