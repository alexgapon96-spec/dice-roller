import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../settings.dart';

enum Crit { none, success, fail }

/// Knock sounds and haptics that accompany a roll.
class RollFeedback {
  RollFeedback(this._settings);

  final AppSettings _settings;
  final _rng = math.Random();
  final _knocks = <AudioPool>[];
  final _settles = <AudioPool>[];
  final _critSuccess = <AudioPool>[];
  final _critFail = <AudioPool>[];
  bool _muted = false;

  static const _ringer = MethodChannel('dice_roller/ringer');

  /// Paths relative to `assets/`, as audioplayers expects.
  static const knockAssets = ['sounds/knock_1.wav', 'sounds/knock_2.wav', 'sounds/knock_3.wav'];
  static const settleAssets = ['sounds/settle_1.wav', 'sounds/settle_2.wav'];
  static const critSuccessAsset = 'sounds/crit_success.wav';
  static const critFailAsset = 'sounds/crit_fail.wav';

  /// Loads the sounds. Failures only disable sound, never the app.
  Future<void> init() async {
    try {
      // Ambient on iOS obeys the silent switch and mixes with other audio;
      // on Android, game sounds shouldn't steal focus from music.
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        android: const AudioContextAndroid(
          usageType: AndroidUsageType.game,
          contentType: AndroidContentType.sonification,
          audioFocus: AndroidAudioFocus.none,
        ),
      ));
      Future<AudioPool> pool(String path) =>
          AudioPool.createFromAsset(
            path: path,
            maxPlayers: 4,
            minPlayers: 2,
            playerMode: PlayerMode.lowLatency,
          );
      for (final a in knockAssets) {
        _knocks.add(await pool(a));
      }
      for (final a in settleAssets) {
        _settles.add(await pool(a));
      }
      _critSuccess.add(await pool(critSuccessAsset));
      _critFail.add(await pool(critFailAsset));
    } catch (e) {
      debugPrint('Sound disabled: $e');
    }
  }

  /// Whether this device can vibrate for us: phones, and Android browsers
  /// (iOS Safari and desktops can't).
  static bool get hapticsSupported => switch (defaultTargetPlatform) {
        TargetPlatform.android => true,
        TargetPlatform.iOS => !kIsWeb,
        _ => false,
      };

  /// Call when a roll starts: Android media volume ignores silent mode, so
  /// the ringer mode decides whether we play. Browsers can't see it.
  Future<void> rollStarted() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _muted = await _ringer.invokeMethod<bool>('isSilent') ?? false;
    } on PlatformException {
      _muted = false;
    }
  }

  /// The dice hit the felt mid-roll; [strength] (0..1) shrinks with each
  /// bounce.
  void knockSound(double strength) => _play(_knocks, 0.35 + 0.55 * strength);

  void knockHaptic() {
    if (_settings.vibrationOn) HapticFeedback.lightImpact();
  }

  /// The dice come to rest; a crit adds its own sting on top.
  void settleSound(Crit crit) {
    _play(_settles, 0.6);
    switch (crit) {
      case Crit.success:
        _play(_critSuccess, 0.9);
      case Crit.fail:
        _play(_critFail, 0.9);
      case Crit.none:
    }
  }

  void settleHaptic(Crit crit) {
    if (!_settings.vibrationOn) return;
    if (crit == Crit.none) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
      Timer(const Duration(milliseconds: 140), HapticFeedback.heavyImpact);
    }
  }

  void _play(List<AudioPool> sounds, double volume) {
    if (!_settings.soundOn || _muted || sounds.isEmpty) return;
    sounds[_rng.nextInt(sounds.length)].start(volume: volume);
  }
}
