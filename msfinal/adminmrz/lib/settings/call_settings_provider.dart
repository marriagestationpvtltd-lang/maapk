import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available ringtone options bundled with the app.
class RingtoneTone {
  final String id;
  final String label;
  final String asset; // relative to assets/
  const RingtoneTone({required this.id, required this.label, required this.asset});
}

class CallSettingsProvider extends ChangeNotifier {
  static const _keyToneId         = 'call_tone_id';
  static const _keyRepeatInterval = 'call_repeat_interval';

  static const List<RingtoneTone> availableTones = [
    RingtoneTone(
      id: 'classic',
      label: 'Classic Ring (440 + 480 Hz)',
      asset: 'audio/ring_classic.wav',
    ),
    RingtoneTone(
      id: 'soft',
      label: 'Soft Professional (800 + 1000 Hz)',
      asset: 'audio/ring_soft.wav',
    ),
    RingtoneTone(
      id: 'modern',
      label: 'Modern Double-Beep',
      asset: 'audio/ring_modern.wav',
    ),
    RingtoneTone(
      id: 'default',
      label: 'Original Tone',
      asset: 'audio/outcall.mp3',
    ),
  ];

  String _selectedToneId       = 'classic';
  int    _repeatIntervalSeconds = 3;

  String get selectedToneId        => _selectedToneId;
  int    get repeatIntervalSeconds => _repeatIntervalSeconds;

  RingtoneTone get selectedTone =>
      availableTones.firstWhere(
        (t) => t.id == _selectedToneId,
        orElse: () => availableTones.first,
      );

  CallSettingsProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedToneId        = prefs.getString(_keyToneId)         ?? 'classic';
    _repeatIntervalSeconds = prefs.getInt(_keyRepeatInterval)    ?? 3;
    notifyListeners();
  }

  Future<void> setTone(String toneId) async {
    _selectedToneId = toneId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToneId, toneId);
  }

  Future<void> setRepeatInterval(int seconds) async {
    _repeatIntervalSeconds = seconds.clamp(1, 30);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyRepeatInterval, _repeatIntervalSeconds);
  }
}
