import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/sound_manager.dart';
import '../components/kendo_fighter.dart';

class ScoreManager {
  static final ValueNotifier<int> winsNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> lossesNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> debugEnabledNotifier = ValueNotifier<bool>(false);

  static const String _keyWins = 'kewpie_wins';
  static const String _keyLosses = 'kewpie_losses';
  static const String _keyStreak = 'kewpie_streak';
  static const String _keyGuardDuration = 'kewpie_guard_duration';
  static const String _keySoundEnabled = 'kewpie_sound_enabled';
  static const String _keyDebugEnabled = 'kewpie_debug_enabled';

  static Future<void> loadScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      winsNotifier.value = prefs.getInt(_keyWins) ?? 0;
      lossesNotifier.value = prefs.getInt(_keyLosses) ?? 0;
      streakNotifier.value = prefs.getInt(_keyStreak) ?? 0;

      final savedDuration = prefs.getDouble(_keyGuardDuration) ?? 0.4;
      KendoFighter.guardActiveDuration = savedDuration.clamp(0.2, 1.0);

      final savedSound = prefs.getBool(_keySoundEnabled) ?? false;
      soundEnabledNotifier.value = savedSound;
      SoundManager.isEnabled = savedSound;
      if (savedSound) {
        try {
          await SoundManager.init();
        } catch (e) {
          debugPrint('ScoreManager load sound init warning: $e');
        }
      }

      final savedDebug = prefs.getBool(_keyDebugEnabled) ?? false;
      debugEnabledNotifier.value = savedDebug;
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

  static Future<void> setSoundEnabled(bool enabled) async {
    soundEnabledNotifier.value = enabled;
    SoundManager.isEnabled = enabled;
    if (enabled) {
      try {
        await SoundManager.init();
      } catch (e) {
        debugPrint('ScoreManager setSoundEnabled sound init warning: $e');
      }
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keySoundEnabled, enabled);
    } catch (e) {
      debugPrint('ScoreManager setSoundEnabled warning: $e');
    }
  }

  static Future<void> setDebugEnabled(bool enabled) async {
    debugEnabledNotifier.value = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyDebugEnabled, enabled);
    } catch (e) {
      debugPrint('ScoreManager setDebugEnabled warning: $e');
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
