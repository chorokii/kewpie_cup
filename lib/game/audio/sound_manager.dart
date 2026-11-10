class SoundManager {
  static bool isEnabled = true;

  static Future<void> init() async {
    return;
  }

  /// チャージ音（無効化）
  static Future<void> playCharge() async {
    return;
  }

  static Future<void> stopCharge() async {
    return;
  }

  /// 防御音（一時停止）
  static void playGuard() {
    return;
  }

  /// 打撃音（一時停止）
  static void playHit() {
    return;
  }

  /// リソース解放
  static void dispose() {
    return;
  }
}
