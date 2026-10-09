import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dice/geometry.dart';
import 'dice/skins.dart';

/// User preferences that survive app restarts.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs)
      : _dieType = DieType.fromLabel(_prefs.getString(_dieKey)),
        _soundOn = _prefs.getBool(_soundKey) ?? true,
        _vibrationOn = _prefs.getBool(_vibrationKey) ?? true,
        _skinId = _prefs.getString(_skinKey);

  static const _dieKey = 'die_type';
  static const _soundKey = 'sound_on';
  static const _vibrationKey = 'vibration_on';
  static const _skinKey = 'skin';

  static Future<AppSettings> load() async => AppSettings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;
  DieType _dieType;
  bool _soundOn;
  bool _vibrationOn;
  String? _skinId;

  DieType get dieType => _dieType;
  bool get soundOn => _soundOn;
  bool get vibrationOn => _vibrationOn;

  static bool get skinsEnabled => kIsWeb;

  /// Skins are a web-only feature for now; other builds always use Granite.
  DieSkin get skin => skinsEnabled ? DieSkin.byId(_skinId) : DieSkin.granite;

  set skin(DieSkin value) {
    _skinId = value.id;
    _prefs.setString(_skinKey, value.id);
    notifyListeners();
  }

  set dieType(DieType value) {
    if (value == _dieType) return;
    _dieType = value;
    _prefs.setString(_dieKey, value.label);
    notifyListeners();
  }

  set soundOn(bool value) {
    _soundOn = value;
    _prefs.setBool(_soundKey, value);
    notifyListeners();
  }

  set vibrationOn(bool value) {
    _vibrationOn = value;
    _prefs.setBool(_vibrationKey, value);
    notifyListeners();
  }
}
