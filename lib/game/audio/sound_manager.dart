import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class SoundManager {
  /// 効果音の有効フラグ（初期値: 切 = false）
  static bool isEnabled = false;

  static AudioPlayer? _guardPlayer;
  static AudioPlayer? _hitPlayer;

  static Uint8List? _guardWavBytes;
  static Uint8List? _hitWavBytes;

  static Future<void> init() async {
    _guardWavBytes ??= _generateGuardWav();
    _hitWavBytes ??= _generateHitWav();
    try {
      _guardPlayer ??= AudioPlayer();
      _hitPlayer ??= AudioPlayer();
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

  /// 防御音（竹刀で受け止める硬質な音）
  static void playGuard() {
    if (!isEnabled) return;
    _playBytes(_guardPlayer, _guardWavBytes ??= _generateGuardWav());
  }

  /// 打撃音（面を捉える鋭い竹刀の打突音）
  static void playHit() {
    if (!isEnabled) return;
    _playBytes(_hitPlayer, _hitWavBytes ??= _generateHitWav());
  }

  static Future<void> _playBytes(AudioPlayer? player, Uint8List bytes) async {
    try {
      final targetPlayer = player ?? AudioPlayer();
      await targetPlayer.stop();
      await targetPlayer.play(BytesSource(bytes));
    } catch (e) {
      debugPrint('SoundManager playback warning: $e');
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

  /// 防御音WAV生成（約110ms: 竹刀同士がぶつかる「カンッ」という中〜高域の硬質な響き）
  static Uint8List _generateGuardWav() {
    const int sampleRate = 44100;
    const double duration = 0.11;
    final int numSamples = (sampleRate * duration).toInt();
    final Float64List samples = Float64List(numSamples);
    final math.Random rand = math.Random(42);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      final double env = math.exp(-t * 32.0);
      // 竹の共鳴周波数成分（520Hz + 1040Hz + 1680Hz）＋初期アタックノイズ
      final double tone1 = math.sin(2.0 * math.pi * 520.0 * t);
      final double tone2 = math.sin(2.0 * math.pi * 1040.0 * t) * 0.6;
      final double tone3 = math.sin(2.0 * math.pi * 1680.0 * t) * 0.35;
      final double noise = (rand.nextDouble() * 2.0 - 1.0) * math.exp(-t * 80.0) * 0.5;
      samples[i] = ((tone1 + tone2 + tone3 + noise) * 0.45 * env).clamp(-1.0, 1.0);
    }

    return _encodePcm16Wav(samples, sampleRate);
  }

  /// 打撃音WAV生成（約160ms: 面を強く叩く「パシッ／パーン！」という鋭いアタック＋胴鳴り）
  static Uint8List _generateHitWav() {
    const int sampleRate = 44100;
    const double duration = 0.16;
    final int numSamples = (sampleRate * duration).toInt();
    final Float64List samples = Float64List(numSamples);
    final math.Random rand = math.Random(108);

    for (int i = 0; i < numSamples; i++) {
      final double t = i / sampleRate;
      // 強い初期スナップ（打突の瞬間）と竹刀のしなり音
      final double snapEnv = math.exp(-t * 45.0);
      final double bodyEnv = math.exp(-t * 18.0);
      final double freq = 320.0 + 480.0 * math.exp(-t * 40.0);
      final double bodyTone = math.sin(2.0 * math.pi * freq * t) * bodyEnv;
      final double highCrack = math.sin(2.0 * math.pi * 2100.0 * t) * snapEnv * 0.5;
      final double whiteNoise = (rand.nextDouble() * 2.0 - 1.0) * snapEnv * 0.85;
      samples[i] = ((bodyTone + highCrack + whiteNoise) * 0.55).clamp(-1.0, 1.0);
    }

    return _encodePcm16Wav(samples, sampleRate);
  }

  /// Float64波形配列（-1.0〜1.0）を16bitモノラルPCM WAVフォーマットへエンコード
  static Uint8List _encodePcm16Wav(Float64List samples, int sampleRate) {
    final int numSamples = samples.length;
    final int dataSize = numSamples * 2;
    final int fileSize = 36 + dataSize;

    final ByteData buffer = ByteData(44 + dataSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, fileSize, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // fmt chunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Subchunk1Size (16 for PCM)
    buffer.setUint16(20, 1, Endian.little); // AudioFormat (1 = PCM)
    buffer.setUint16(22, 1, Endian.little); // NumChannels (1 = Mono)
    buffer.setUint32(24, sampleRate, Endian.little); // SampleRate
    buffer.setUint32(28, sampleRate * 2, Endian.little); // ByteRate
    buffer.setUint16(32, 2, Endian.little); // BlockAlign
    buffer.setUint16(34, 16, Endian.little); // BitsPerSample

    // data chunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little);

    for (int i = 0; i < numSamples; i++) {
      final int pcmVal = (samples[i].clamp(-1.0, 1.0) * 32767.0).round();
      buffer.setInt16(44 + i * 2, pcmVal, Endian.little);
    }

    return buffer.buffer.asUint8List();
  }
}
