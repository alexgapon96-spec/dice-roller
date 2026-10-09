import 'package:flutter/material.dart';

import 'dice/die_renderer.dart';
import 'dice/geometry.dart';
import 'dice/roll.dart';
import 'feedback/roll_feedback.dart';
import 'settings.dart';
import 'widgets/die_picker_sheet.dart';
import 'widgets/felt_background.dart';
import 'widgets/roll_mode_selector.dart';

const _gold = Color(0xFFE8B84E);
const _red = Color(0xFFE24B4A);

const _rollMs = 1200;

/// Landings before the last one, with how hard each is. The last landing is
/// the end of the animation, where the dice settle.
final _impacts = [
  (ms: DieRoll.landings[0] * _rollMs, strength: 1.0),
  (ms: DieRoll.landings[1] * _rollMs, strength: 0.6),
];

/// Phones play audio ~100+ ms after it is started, so sounds are started this
/// much early to land with the impact on screen. Haptics have no such lag.
const _soundLeadMs = 120;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, required this.feedback});

  final AppSettings settings;
  final RollFeedback feedback;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _roll = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _rollMs),
    value: 1,
  )
    ..addListener(_onRollTick)
    ..addStatusListener(_onRollStatus);

  late DieType _type = widget.settings.dieType;
  RollMode _mode = RollMode.normal;
  late List<DieRoll> _dice = _cleanTable();
  bool _hasResult = false;
  Crit _crit = Crit.none;
  double _lastMs = _rollMs.toDouble();

  bool get _rolling => _roll.isAnimating;

  @override
  void dispose() {
    _roll.dispose();
    super.dispose();
  }

  /// One die per roll in the current mode, each showing its maximum.
  List<DieRoll> _cleanTable() {
    final geometry = DieGeometry.of(_type);
    final count = _mode == RollMode.normal ? 1 : 2;
    return [for (var i = 0; i < count; i++) DieRoll.resting(geometry, _type.sides)];
  }

  void _resetTable() {
    _dice = _cleanTable();
    _hasResult = false;
    _roll.value = 1;
  }

  void _setDieType(DieType type) {
    widget.settings.dieType = type;
    setState(() {
      _type = type;
      _resetTable();
    });
  }

  void _setMode(RollMode mode) {
    if (_rolling || mode == _mode) return;
    setState(() {
      _mode = mode;
      _resetTable();
    });
  }

  void _rollDice() {
    if (_rolling) return;
    final geometry = DieGeometry.of(_type);
    setState(() {
      _dice = [for (var i = 0; i < _dice.length; i++) DieRoll.random(geometry)];
      _hasResult = true;
      _crit = _critOf(_dice);
    });
    widget.feedback.rollStarted();
    _lastMs = 0;
    _roll.forward(from: 0);
  }

  void _onRollTick() {
    final now = _roll.value * _rollMs;
    final before = _lastMs;
    bool reached(double at) => before < at && now >= at;
    final feedback = widget.feedback;
    for (final i in _impacts) {
      if (reached(i.ms - _soundLeadMs)) feedback.knockSound(i.strength);
      if (reached(i.ms)) feedback.knockHaptic();
    }
    if (reached(_rollMs - _soundLeadMs.toDouble())) feedback.settleSound(_crit);
    _lastMs = now;
  }

  void _onRollStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && _hasResult) widget.feedback.settleHaptic(_crit);
  }

  /// Crit of the counted die (d20 only). Counted dice that tie share a value.
  Crit _critOf(List<DieRoll> dice) {
    if (_type != DieType.d20) return Crit.none;
    final value = dice[countedDice(dice, _mode).first].value;
    return switch (value) {
      20 => Crit.success,
      1 => Crit.fail,
      _ => Crit.none,
    };
  }

  Future<void> _openSettings() async {
    if (_rolling) return;
    final picked = await showDiePicker(context, widget.settings);
    if (picked == null || picked == _type) return;
    _setDieType(picked);
  }

  /// Screen centers and radius for the dice currently shown.
  ({List<Offset> centers, double radius}) _layout(Size size) {
    final center = Offset(size.width / 2, size.height * 0.46);
    if (_dice.length == 1) {
      return (centers: [center], radius: (size.width * 0.34).clamp(0, size.height * 0.26));
    }
    final dx = size.width * 0.24;
    return (
      centers: [center - Offset(dx, 0), center + Offset(dx, 0)],
      radius: (size.width * 0.2).clamp(0, size.height * 0.16),
    );
  }

  void _onTapUp(TapUpDetails details, Size size) {
    final layout = _layout(size);
    final hit = layout.centers.any((c) => (details.localPosition - c).distance <= layout.radius * 1.25);
    if (hit) _rollDice();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: FeltBackground()),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (d) => _onTapUp(d, size),
                  child: AnimatedBuilder(
                    animation: _roll,
                    builder: (context, _) => CustomPaint(
                      size: size,
                      painter: _DiceScenePainter(_visuals(size)),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton(
                  onPressed: _openSettings,
                  tooltip: 'Settings',
                  iconSize: 30,
                  color: const Color(0xFFD9CDEA),
                  icon: const Icon(Icons.settings_outlined),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: ConstrainedBox(
                  // Phone-width on desktop browsers instead of stretching edge to edge.
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: RollModeSelector(mode: _mode, onChanged: _setMode),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<DieVisual> _visuals(Size size) {
    final t = _roll.value;
    final settled = !_rolling;
    final layout = _layout(size);
    final counted = countedDice(_dice, _mode);
    return [
      for (var i = 0; i < _dice.length; i++)
        DieVisual(
          geometry: _dice[i].geometry,
          rotation: _dice[i].rotationAt(t),
          center: layout.centers[i] + _dice[i].offsetAt(t) * layout.radius,
          radius: layout.radius,
          lift: _dice[i].liftAt(t),
          opacity: settled && !counted.contains(i) ? 0.35 : 1,
          glow: settled && _hasResult && counted.contains(i) ? _critGlow(_dice[i]) : null,
        ),
    ];
  }

  Color? _critGlow(DieRoll die) {
    if (_type != DieType.d20) return null;
    return switch (die.value) {
      20 => _gold,
      1 => _red,
      _ => null,
    };
  }
}

class _DiceScenePainter extends CustomPainter {
  _DiceScenePainter(this.dice);

  final List<DieVisual> dice;

  @override
  void paint(Canvas canvas, Size size) {
    for (final d in dice) {
      DieRenderer.paintGlow(canvas, d);
    }
    for (final d in dice) {
      DieRenderer.paintShadow(canvas, d);
    }
    for (final d in dice) {
      DieRenderer.paintDie(canvas, d);
    }
  }

  @override
  bool shouldRepaint(_DiceScenePainter oldDelegate) => true;
}
