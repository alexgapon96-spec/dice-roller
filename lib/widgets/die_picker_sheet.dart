import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3;

import '../dice/die_renderer.dart';
import '../dice/geometry.dart';
import '../dice/skins.dart';
import '../feedback/roll_feedback.dart';
import '../settings.dart';

const sheetColor = Color(0xFF2A1A40);
const _tileColor = Color(0xFF3A2756);
const _selectedColor = Color(0xFF6A4A96);
const _labelColor = Color(0xFFE8E0F2);

/// Settings sheet: vibration and sound toggles, then the dice (and, on the
/// web, a Skins tab). Resolves to the picked die type, or null if dismissed.
Future<DieType?> showDiePicker(BuildContext context, AppSettings settings) {
  return showModalBottomSheet<DieType>(
    context: context,
    backgroundColor: sheetColor,
    showDragHandle: true,
    // Keeps the tiles phone-sized in wide desktop browser windows.
    constraints: const BoxConstraints(maxWidth: 440),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _SettingsSheet(settings: settings),
  );
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.settings});

  final AppSettings settings;

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  bool _skinsTab = false;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return SafeArea(
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
              if (AppSettings.skinsEnabled) ...[
                _Tabs(
                  skins: _skinsTab,
                  onChanged: (skins) => setState(() => _skinsTab = skins),
                ),
                const SizedBox(height: 16),
              ],
              if (_skinsTab) _skinGrid(settings) else _diceGrid(context, settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diceGrid(BuildContext context, AppSettings settings) => _grid([
        for (final type in DieType.values)
          _Tile(
            label: type.label,
            painter: _DieIconPainter(type, settings.skin),
            selected: type == settings.dieType,
            onTap: () => Navigator.of(context).pop(type),
          ),
      ]);

  /// Picking a skin applies it at once and keeps the sheet open for comparing.
  Widget _skinGrid(AppSettings settings) => _grid([
        for (final skin in DieSkin.all)
          _Tile(
            label: skin.name,
            painter: _DieIconPainter(DieType.d20, skin),
            selected: skin.id == settings.skin.id,
            onTap: () => settings.skin = skin,
          ),
      ]);

  Widget _grid(List<Widget> tiles) => GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.95,
        physics: const NeverScrollableScrollPhysics(),
        children: tiles,
      );
}

/// Pill with two tabs, Dice · Skins, styled like the roll mode selector.
class _Tabs extends StatelessWidget {
  const _Tabs({required this.skins, required this.onChanged});

  final bool skins;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool value) {
      final selected = skins == value;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: selected ? _selectedColor : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected ? Colors.white : const Color(0xFFBFB0D6),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 42,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _tileColor, borderRadius: BorderRadius.circular(21)),
      child: Row(children: [tab('Dice', false), tab('Skins', true)]),
    );
  }
}

/// Round icon button; when off, the icon dims and gets crossed out.
class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.on, required this.onTap});

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  static const _offColor = Color(0xFF8D7FA6);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: on,
      label: label,
      child: Tooltip(
        message: '$label ${on ? 'on' : 'off'}',
        child: Material(
          color: _tileColor,
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
                  Icon(icon, size: 26, color: on ? _labelColor : _offColor),
                  if (!on)
                    Transform.rotate(
                      angle: -math.pi / 4,
                      child: Container(
                        width: 36,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: _labelColor,
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

/// Grid tile: a die drawn by [painter] above a label.
class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.painter, required this.selected, required this.onTap});

  final String label;
  final CustomPainter painter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _selectedColor : _tileColor,
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
                style: const TextStyle(color: _labelColor, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DieIconPainter extends CustomPainter {
  _DieIconPainter(this.type, this.skin);

  final DieType type;
  final DieSkin skin;

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
        skin: skin,
      ),
    );
  }

  @override
  bool shouldRepaint(_DieIconPainter oldDelegate) => oldDelegate.type != type || oldDelegate.skin != skin;
}
