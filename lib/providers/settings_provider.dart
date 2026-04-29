import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';

enum SpeedUnit {
  kmh,
  mph;

  String get label => switch (this) {
        SpeedUnit.kmh => 'km/h',
        SpeedUnit.mph => 'mph',
      };

  double fromKmh(double kmh) => switch (this) {
        SpeedUnit.kmh => kmh,
        SpeedUnit.mph => kmh * 0.621371,
      };

  String formatFromKmh(double kmh) => '${fromKmh(kmh).round()} $label';

  static SpeedUnit fromName(String? name) {
    return SpeedUnit.values.firstWhere(
      (unit) => unit.name == name,
      orElse: () => SpeedUnit.kmh,
    );
  }
}

class SettingsProvider extends ChangeNotifier {
  static const _kProximity = 'proximity_threshold';
  static const _kNotifications = 'notifications_enabled';
  static const _kSpeedUnit = 'speed_unit';

  double _proximityThreshold = SupabaseConfig.proximityThresholdMeters;
  bool _notificationsEnabled = true;
  SpeedUnit _speedUnit = SpeedUnit.kmh;

  double get proximityThreshold => _proximityThreshold;
  bool get notificationsEnabled => _notificationsEnabled;
  SpeedUnit get speedUnit => _speedUnit;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _proximityThreshold =
        prefs.getDouble(_kProximity) ?? SupabaseConfig.proximityThresholdMeters;
    _notificationsEnabled = prefs.getBool(_kNotifications) ?? true;
    _speedUnit = SpeedUnit.fromName(prefs.getString(_kSpeedUnit));
    notifyListeners();
  }

  Future<void> setProximityThreshold(double value) async {
    _proximityThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kProximity, value);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNotifications, value);
    notifyListeners();
  }

  Future<void> setSpeedUnit(SpeedUnit value) async {
    _speedUnit = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSpeedUnit, value.name);
    notifyListeners();
  }
}
