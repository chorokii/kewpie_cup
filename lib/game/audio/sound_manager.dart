import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundManager {
  /// 効果音の有効フラグ（初期値: 切 = false）
  static bool isEnabled = false;

  static AudioPlayer? _guardPlayer;
  static AudioPlayer? _hitPlayer;

  static const String _guardAssetPath = 'audio/sfx/guard.mp3';
  static const String _hitAssetPath = 'audio/sfx/hit.mp3';

  static Future<void> init() async {
    if (!isEnabled) return;
    try {
      _guardPlayer ??= AudioPlayer();
      _hitPlayer ??= AudioPlayer();
      await _guardPlayer!.setReleaseMode(ReleaseMode.stop);
      await _hitPlayer!.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('SoundManager init warning: $e');
    }
  }

  /// チャージ音（無効化維持）
  static Future<void> playCharge() async {
    return;
  }

  static Future<void> stopCharge() async {
    return;
  }

  /// 防御音（assets/audio/sfx/guard.mp3 を再生）
  static void playGuard() {
    if (!isEnabled) return;
    _playAsset(_guardPlayer, _guardAssetPath, isGuard: true);
  }

  /// 打撃音（assets/audio/sfx/hit.mp3 を再生）
  static void playHit() {
    if (!isEnabled) return;
    _playAsset(_hitPlayer, _hitAssetPath, isGuard: false);
  }

  static Future<void> _playAsset(
    AudioPlayer? player,
    String assetPath, {
    required bool isGuard,
  }) async {
    if (!isEnabled) return;
    try {
      AudioPlayer targetPlayer;
      if (player != null) {
        targetPlayer = player;
      } else {
        targetPlayer = AudioPlayer();
        if (isGuard) {
          _guardPlayer = targetPlayer;
        } else {
          _hitPlayer = targetPlayer;
        }
      }
      await targetPlayer.stop();
      await targetPlayer.play(AssetSource(assetPath));
    } catch (e) {
      debugPrint('SoundManager playback warning ($assetPath): $e');
    }
  }

  /// リソース解放
  static void dispose() {
    try {
      _guardPlayer?.dispose();
      _hitPlayer?.dispose();
    } catch (e) {
      debugPrint('SoundManager dispose warning: $e');
    } finally {
      _guardPlayer = null;
      _hitPlayer = null;
    }
  }
}
