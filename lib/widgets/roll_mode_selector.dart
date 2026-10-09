import 'package:flutter/material.dart';

import '../dice/roll.dart';

/// Pill-shaped segmented control: Disadvantage · Normal · Advantage.
class RollModeSelector extends StatelessWidget {
  const RollModeSelector({super.key, required this.mode, required this.onChanged});

  final RollMode mode;
  final ValueChanged<RollMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF2F1D48),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          for (final m in RollMode.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: m == mode ? const Color(0xFF6A4A96) : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    m.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: m == mode ? FontWeight.w600 : FontWeight.w500,
                      color: m == mode ? Colors.white : const Color(0xFFBFB0D6),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
