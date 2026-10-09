import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dice/geometry.dart';
import '../feedback/roll_feedback.dart';
import '../settings.dart';
import 'picker_tiles.dart';

enum _Panel { none, dice, skins }

/// Top-right controls of the web version: vibration (phones), sound, and the
/// Dice and Skins pickers. On wide screens a picker drops down from its
/// button, which turns into the panel's ✕; on narrow screens it slides up
/// from the bottom instead.
class WebToolbar extends StatefulWidget {
  const WebToolbar({
    super.key,
    required this.settings,
    required this.onPickDie,
    required this.busy,
  });

  final AppSettings settings;
  final ValueChanged<DieType> onPickDie;

  /// True while dice roll; the toolbar ignores taps then.
  final bool Function() busy;

  @override
  State<WebToolbar> createState() => _WebToolbarState();
}

class _WebToolbarState extends State<WebToolbar> {
  /// Below this width pickers open as bottom sheets, as on phones.
  static const _narrowWidth = 600.0;
  static const _panelWidth = 372.0;

  final _diceLink = LayerLink();
  final _skinsLink = LayerLink();
  _Panel _open = _Panel.none;

  void _close() => setState(() => _open = _Panel.none);

  void _toggle(_Panel panel, bool narrow) {
    if (widget.busy()) return;
    if (narrow) {
      _showSheet(panel);
    } else {
      setState(() => _open = _open == panel ? _Panel.none : panel);
    }
  }

  void _pickDie(DieType type) {
    widget.onPickDie(type);
    _close();
  }

  Future<void> _showSheet(_Panel panel) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: _PanelBody(
            panel: panel,
            settings: widget.settings,
            onClose: () => Navigator.of(context).pop(),
            onPickDie: (type) {
              Navigator.of(context).pop();
              widget.onPickDie(type);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < _narrowWidth;
      // A drop-down left open while the window shrinks would float oddly.
      final open = narrow ? _Panel.none : _open;
      return ListenableBuilder(
        listenable: settings,
        builder: (context, _) {
          final skin = settings.skin;
          final buttonSize = narrow ? 40.0 : 44.0;
          return Stack(
            children: [
              if (open != _Panel.none)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _close,
                    child: const ColoredBox(color: Color(0x40000000)),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (narrow && RollFeedback.hapticsSupported) ...[
                          ToggleIconButton(
                            icon: Icons.vibration,
                            label: 'Vibration',
                            size: buttonSize,
                            on: settings.vibrationOn,
                            onTap: () => settings.vibrationOn = !settings.vibrationOn,
                          ),
                          const SizedBox(width: 8),
                        ],
                        ToggleIconButton(
                          icon: Icons.volume_up_outlined,
                          label: 'Sound',
                          size: buttonSize,
                          on: settings.soundOn,
                          onTap: () => settings.soundOn = !settings.soundOn,
                        ),
                        const SizedBox(width: 8),
                        CompositedTransformTarget(
                          link: _diceLink,
                          child: _PickerButton(
                            semantic: 'Dice',
                            label: settings.dieType.label,
                            painter: DieIconPainter(settings.dieType, skin),
                            height: buttonSize,
                            onTap: () => _toggle(_Panel.dice, narrow),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: CompositedTransformTarget(
                            link: _skinsLink,
                            child: _PickerButton(
                              semantic: 'Skin',
                              label: skin.name,
                              painter: DieIconPainter(DieType.d20, skin),
                              height: buttonSize,
                              onTap: () => _toggle(_Panel.skins, narrow),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (open != _Panel.none)
                Positioned(
                  left: 0,
                  top: 0,
                  child: CompositedTransformFollower(
                    link: open == _Panel.dice ? _diceLink : _skinsLink,
                    // The panel's top-right corner sits on the button's, so
                    // its ✕ lands where the button was.
                    targetAnchor: Alignment.topRight,
                    followerAnchor: Alignment.topRight,
                    child: _DropDown(
                      key: ValueKey(open),
                      width: _panelWidth,
                      onClose: _close,
                      child: _PanelBody(
                        panel: open,
                        settings: settings,
                        onClose: _close,
                        onPickDie: _pickDie,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
    });
  }
}

/// Pill button showing the current choice: `◆ d20 ▾`.
class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.semantic,
    required this.label,
    required this.painter,
    required this.height,
    required this.onTap,
  });

  final String semantic;
  final String label;
  final CustomPainter painter;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$semantic: $label',
      excludeSemantics: true,
      child: Material(
        color: tileColor,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(dimension: height * 0.6, child: CustomPaint(painter: painter)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: labelColor, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Icon(Icons.expand_more, size: 18, color: mutedLabelColor),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Panel card that fades and grows in from its top-right corner, and closes
/// on Esc.
class _DropDown extends StatelessWidget {
  const _DropDown({super.key, required this.width, required this.onClose, required this.child});

  final double width;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
          onClose();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.scale(scale: 0.94 + 0.06 * t, alignment: Alignment.topRight, child: child),
        ),
        child: SizedBox(
          width: width,
          child: Material(
            color: sheetColor,
            elevation: 12,
            shadowColor: Colors.black,
            borderRadius: BorderRadius.circular(20),
            child: Padding(padding: const EdgeInsets.all(12), child: child),
          ),
        ),
      ),
    );
  }
}

/// Title + ✕, then the Dice or Skins grid.
class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.panel,
    required this.settings,
    required this.onClose,
    required this.onPickDie,
  });

  final _Panel panel;
  final AppSettings settings;
  final VoidCallback onClose;
  final ValueChanged<DieType> onPickDie;

  @override
  Widget build(BuildContext context) {
    final dice = panel == _Panel.dice;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  dice ? 'Dice' : 'Skins',
                  style: const TextStyle(color: mutedLabelColor, fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              const Spacer(),
              Tooltip(
                message: 'Close',
                child: Material(
                  color: selectedColor,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onClose,
                    child: const SizedBox.square(
                      dimension: 36,
                      child: Icon(Icons.close, size: 20, color: labelColor),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          pickerGrid(dice ? diceTiles(settings, onPickDie) : skinTiles(settings)),
        ],
      ),
    );
  }
}
