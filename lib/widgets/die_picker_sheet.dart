import 'package:flutter/material.dart';

import '../dice/geometry.dart';
import '../feedback/roll_feedback.dart';
import '../settings.dart';
import 'picker_tiles.dart';

export 'picker_tiles.dart' show sheetColor;

/// Native-app settings sheet: vibration and sound toggles, then the six dice.
/// Resolves to the picked die type, or null if dismissed. (The web uses the
/// toolbar in web_toolbar.dart instead.)
Future<DieType?> showDiePicker(BuildContext context, AppSettings settings) {
  return showModalBottomSheet<DieType>(
    context: context,
    backgroundColor: sheetColor,
    showDragHandle: true,
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
                    ToggleIconButton(
                      icon: Icons.vibration,
                      label: 'Vibration',
                      on: settings.vibrationOn,
                      onTap: () => settings.vibrationOn = !settings.vibrationOn,
                    ),
                    const SizedBox(width: 20),
                  ],
                  ToggleIconButton(
                    icon: Icons.volume_up_outlined,
                    label: 'Sound',
                    on: settings.soundOn,
                    onTap: () => settings.soundOn = !settings.soundOn,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              pickerGrid(diceTiles(settings, (type) => Navigator.of(context).pop(type))),
            ],
          ),
        ),
      ),
    ),
  );
}
