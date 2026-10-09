import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix3, Quaternion, Vector3;

import 'geometry.dart';

enum RollMode {
  disadvantage('Disadvantage'),
  normal('Normal'),
  advantage('Advantage');

  const RollMode(this.label);

  final String label;
}

final _rng = math.Random.secure();

/// One die's roll: the result plus the path it tumbles along to get there.
class DieRoll {
  DieRoll._(this.geometry, this.value, this._rest, this._axis, this._turn, this._spin, this._from);

  /// A die lying still with [value] up, as shown before the first roll.
  factory DieRoll.resting(DieGeometry geometry, int value) => DieRoll._(
        geometry,
        value,
        geometry.restRotation(value),
        Vector3(1, 0, 0),
        0,
        0,
        Offset.zero,
      );

  /// A fresh roll with a uniformly random result.
  factory DieRoll.random(DieGeometry geometry) {
    final value = _rng.nextInt(geometry.type.sides) + 1;
    final yaw = (_rng.nextDouble() - 0.5) * 0.5;
    final heading = _rng.nextDouble() * math.pi * 2;
    // Unit vector the die travels along, in screen space (y down).
    final dir = Offset(math.cos(heading), math.sin(heading));
    // Rolling across the table (z towards the camera) turns around z × direction.
    final axis = Vector3(dir.dy, dir.dx, 0)..normalize();
    return DieRoll._(
      geometry,
      value,
      geometry.restRotation(value, yaw: yaw),
      axis,
      math.pi * (3 + _rng.nextDouble() * 2),
      (_rng.nextDouble() - 0.5) * math.pi,
      -dir * 1.6,
    );
  }

  final DieGeometry geometry;
  final int value;
  final Matrix3 _rest;
  final Vector3 _axis;
  final double _turn;
  final double _spin;

  /// Start offset from the resting spot, in die radii.
  final Offset _from;

  /// Moments (as animation progress) the die touches the felt. It drops from
  /// the hand, hops twice, and the last landing is where it stops: tumbling
  /// and sliding end exactly there, so nothing moves after the final knock.
  static const landings = [0.38, 0.72, 1.0];

  /// Height of the drop, then of each hop, 0..1.
  static const _heights = [0.7, 0.4, 0.12];

  // Quadratic rather than cubic ease-out: the die still turns a little during
  // the last hop instead of creeping on after it looks settled.
  static const _ease = Curves.easeOutQuad;

  Matrix3 rotationAt(double t) {
    final left = 1 - _ease.transform(t);
    if (left == 0) return _rest;
    final tumble = Quaternion.axisAngle(_axis, -_turn * left).asRotationMatrix();
    return Matrix3.rotationZ(_spin * left).multiplied(tumble).multiplied(_rest);
  }

  /// Offset from the resting spot, in die radii.
  Offset offsetAt(double t) => _from * (1 - _ease.transform(t));

  /// Height above the felt, 0..1: a falling half-parabola, then one parabolic
  /// hop between each pair of [landings].
  double liftAt(double t) {
    if (t <= landings[0]) {
      final s = t / landings[0];
      return _heights[0] * (1 - s * s);
    }
    for (var i = 1; i < landings.length; i++) {
      if (t <= landings[i]) {
        final s = (t - landings[i - 1]) / (landings[i] - landings[i - 1]);
        return _heights[i] * 4 * s * (1 - s);
      }
    }
    return 0;
  }
}

/// Indices of the dice whose value counts for [mode]. Ties count both.
Set<int> countedDice(List<DieRoll> dice, RollMode mode) {
  if (dice.length < 2 || mode == RollMode.normal) {
    return {for (var i = 0; i < dice.length; i++) i};
  }
  final values = dice.map((d) => d.value).toList();
  final target = mode == RollMode.advantage ? values.reduce(math.max) : values.reduce(math.min);
  return {
    for (var i = 0; i < values.length; i++)
      if (values[i] == target) i,
  };
}
