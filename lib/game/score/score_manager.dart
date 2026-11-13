import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../audio/sound_manager.dart';
import '../components/kendo_fighter.dart';

class ScoreManager {
  static final ValueNotifier<int> winsNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> lossesNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> streakNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<int> bossWinsNotifier = ValueNotifier<int>(0);
  static final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(false);
  static final ValueNotifier<bool> debugEnabledNotifier = ValueNotifier<bool>(false);

  static const String defaultPlayerName = '剣士';
  static const String bossName = '師範';
  static const List<String> defaultCpuNames = [
    '佐藤',
    '鈴木',
    '高橋',
    '田中',
    '渡辺',
  ];
  static const int maxCpuNamesCount = 10;

  static final ValueNotifier<String> playerNameNotifier =
      ValueNotifier<String>(defaultPlayerName);
  static final ValueNotifier<List<String>> cpuNamesNotifier =
      ValueNotifier<List<String>>(List<String>.from(defaultCpuNames));

  static String? _lastSelectedCpuName;
  static final math.Random _random = math.Random();

  static const String _keyWins = 'kewpie_wins';
  static const String _keyLosses = 'kewpie_losses';
  static const String _keyStreak = 'kewpie_streak';
  static const String _keyBossWins = 'kewpie_boss_wins';
  static const String _keyGuardDuration = 'kewpie_guard_duration';
  static const String _keySoundEnabled = 'kewpie_sound_enabled';
  static const String _keyDebugEnabled = 'kewpie_debug_enabled';
  static const String _keyPlayerName = 'kewpie_player_name';
  static const String _keyCpuNames = 'kewpie_cpu_names';

  /// 10連勝（10の倍数の連勝）達成時にボスバトル（師範戦）を発動する判定
  static bool get isBossMatchTriggered =>
      streakNotifier.value > 0 && streakNotifier.value % 10 == 0;

  static Future<void> loadScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      winsNotifier.value = prefs.getInt(_keyWins) ?? 0;
      lossesNotifier.value = prefs.getInt(_keyLosses) ?? 0;
      streakNotifier.value = prefs.getInt(_keyStreak) ?? 0;
      bossWinsNotifier.value = prefs.getInt(_keyBossWins) ?? 0;

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

      final savedPlayerName = prefs.getString(_keyPlayerName);
      if (savedPlayerName != null && savedPlayerName.trim().isNotEmpty) {
        playerNameNotifier.value = _normalizeZekkenName(savedPlayerName);
      } else {
        playerNameNotifier.value = defaultPlayerName;
      }

      final savedCpuNames = prefs.getStringList(_keyCpuNames);
      if (savedCpuNames != null && savedCpuNames.isNotEmpty) {
        final cleaned = savedCpuNames
            .map(_normalizeZekkenName)
            .where((e) => e.isNotEmpty)
            .take(maxCpuNamesCount)
            .toList();
        cpuNamesNotifier.value =
            cleaned.isNotEmpty ? cleaned : List<String>.from(defaultCpuNames);
      } else {
        cpuNamesNotifier.value = List<String>.from(defaultCpuNames);
      }
    } catch (e) {
      debugPrint('ScoreManager load warning: $e');
    }
  }

  static String _normalizeZekkenName(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final runes = trimmed.runes.toList();
    if (runes.length > 3) {
      return String.fromCharCodes(runes.take(3));
    }
    return trimmed;
  }

  static Future<void> setPlayerName(String name) async {
    final normalized = _normalizeZekkenName(name);
    final finalName = normalized.isEmpty ? defaultPlayerName : normalized;
    playerNameNotifier.value = finalName;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyPlayerName, finalName);
    } catch (e) {
      debugPrint('ScoreManager setPlayerName warning: $e');
    }
  }

  static Future<void> setCpuNames(List<String> names) async {
    final cleaned = names
        .map(_normalizeZekkenName)
        .where((e) => e.isNotEmpty)
        .take(maxCpuNamesCount)
        .toList();
    final finalList =
        cleaned.isEmpty ? List<String>.from(defaultCpuNames) : cleaned;
    cpuNamesNotifier.value = finalList;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyCpuNames, finalList);
    } catch (e) {
      debugPrint('ScoreManager setCpuNames warning: $e');
    }
  }

  /// 登録されている相手の名前からランダムで1つを選択する。
  /// 複数名定義されている場合は、前回選択された名前と連続しないように選択する。
  static String pickRandomCpuName({String? previousName}) {
    final list = cpuNamesNotifier.value;
    if (list.isEmpty) {
      _lastSelectedCpuName = defaultCpuNames.first;
      return defaultCpuNames.first;
    }
    if (list.length == 1) {
      _lastSelectedCpuName = list.first;
      return list.first;
    }

    final avoidName = previousName ?? _lastSelectedCpuName;
    final candidates = list.where((name) => name != avoidName).toList();
    final pool = candidates.isNotEmpty ? candidates : list;
    final chosen = pool[_random.nextInt(pool.length)];
    _lastSelectedCpuName = chosen;
    return chosen;
  }

  static void resetLastSelectedCpuName() {
    _lastSelectedCpuName = null;
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

  static Future<void> recordWin({bool isBossVictory = false}) async {
    winsNotifier.value += 1;
    streakNotifier.value += 1;
    if (isBossVictory) {
      bossWinsNotifier.value += 1;
    }
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
    bossWinsNotifier.value = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyWins);
      await prefs.remove(_keyLosses);
      await prefs.remove(_keyStreak);
      await prefs.remove(_keyBossWins);
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
      await prefs.setInt(_keyBossWins, bossWinsNotifier.value);
    } catch (e) {
      debugPrint('ScoreManager save warning: $e');
    }
  }
}
