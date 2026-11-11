import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../components/kendo_fighter.dart';

class ScoreManager {
  static final ValueNotifier<int> winsNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> lossesNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);

  static const String _keyWins = 'kewpie_wins';
  static const String _keyLosses = 'kewpie_losses';
  static const String _keyStreak = 'kewpie_streak';
  static const String _keyGuardDuration = 'kewpie_guard_duration';

  static Future<void> loadScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      winsNotifier.value = prefs.getInt(_keyWins) ?? 0;
      lossesNotifier.value = prefs.getInt(_keyLosses) ?? 0;
      streakNotifier.value = prefs.getInt(_keyStreak) ?? 0;
      final savedDuration = prefs.getDouble(_keyGuardDuration) ?? 0.4;
      KendoFighter.guardActiveDuration = savedDuration.clamp(0.2, 1.0);
    } catch (e) {
      debugPrint('ScoreManager load warning: $e');
    }
  }

  static Future<void> setGuardDuration(double duration) async {
    final clamped = duration.clamp(0.2, 1.0);
    KendoFighter.guardActiveDuration = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_keyGuardDuration, clamped);
    } catch (e) {
      debugPrint('ScoreManager setGuardDuration warning: $e');
    }
  }

  static Future<void> recordWin() async {
    winsNotifier.value += 1;
    streakNotifier.value += 1;
    await _save();
  }

  static Future<void> recordLoss() async {
    lossesNotifier.value += 1;
    streakNotifier.value = 0;
    await _save();
  }

  static Future<void> clearScore() async {
    winsNotifier.value = 0;
    lossesNotifier.value = 0;
    streakNotifier.value = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyWins);
      await prefs.remove(_keyLosses);
      await prefs.remove(_keyStreak);
    } catch (e) {
      debugPrint('ScoreManager clear warning: $e');
    }
  }

  static Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyWins, winsNotifier.value);
      await prefs.setInt(_keyLosses, lossesNotifier.value);
      await prefs.setInt(_keyStreak, streakNotifier.value);
    } catch (e) {
      debugPrint('ScoreManager save warning: $e');
    }
  }
}
