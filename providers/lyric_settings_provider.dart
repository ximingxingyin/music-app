import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 歌词字号档位。
enum LyricFontSize {
  small(12, '小'),
  medium(14, '中'),
  large(17, '大'),
  xlarge(20, '超大');

  final double pt;
  final String label;
  const LyricFontSize(this.pt, this.label);

  static LyricFontSize fromName(String? name) {
    return LyricFontSize.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricFontSize.medium,
    );
  }
}

/// 滚动速度档位。
enum LyricScrollSpeed {
  slow(500, '慢'),
  medium(360, '中'),
  fast(200, '快');

  final int ms;
  final String label;
  const LyricScrollSpeed(this.ms, this.label);

  static LyricScrollSpeed fromName(String? name) {
    return LyricScrollSpeed.values.firstWhere(
      (e) => e.name == name,
      orElse: () => LyricScrollSpeed.medium,
    );
  }
}

/// 歌词显示设置（持久化在 SharedPreferences）。
class LyricSettings {
  final LyricFontSize fontSize;
  final bool centerAlign;
  final LyricScrollSpeed scrollSpeed;
  final bool showTranslation;

  const LyricSettings({
    this.fontSize = LyricFontSize.medium,
    this.centerAlign = true,
    this.scrollSpeed = LyricScrollSpeed.medium,
    this.showTranslation = true,
  });

  LyricSettings copyWith({
    LyricFontSize? fontSize,
    bool? centerAlign,
    LyricScrollSpeed? scrollSpeed,
    bool? showTranslation,
  }) {
    return LyricSettings(
      fontSize: fontSize ?? this.fontSize,
      centerAlign: centerAlign ?? this.centerAlign,
      scrollSpeed: scrollSpeed ?? this.scrollSpeed,
      showTranslation: showTranslation ?? this.showTranslation,
    );
  }

  /// 当前行字号
  double get activeFontSize => fontSize.pt + 3;

  /// 非当前行字号
  double get inactiveFontSize => fontSize.pt;

  /// 翻译行字号（当前行）
  double get translationFontSize => (fontSize.pt + 3) * 0.7;

  /// 翻译行字号（非当前行）
  double get inactiveTranslationFontSize => fontSize.pt * 0.7;
}

/// 同步加载 + 写操作的设置 Provider。
class LyricSettingsNotifier extends StateNotifier<LyricSettings> {
  LyricSettingsNotifier() : super(const LyricSettings()) {
    _load();
  }

  static const _keyFontSize = 'lyric.font_size';
  static const _keyCenter = 'lyric.center';
  static const _keyScrollSpeed = 'lyric.scroll_speed';
  static const _keyShowTranslation = 'lyric.show_translation';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = LyricSettings(
      fontSize: LyricFontSize.fromName(prefs.getString(_keyFontSize)),
      centerAlign: prefs.getBool(_keyCenter) ?? true,
      scrollSpeed:
          LyricScrollSpeed.fromName(prefs.getString(_keyScrollSpeed)),
      showTranslation: prefs.getBool(_keyShowTranslation) ?? true,
    );
  }

  Future<void> setFontSize(LyricFontSize v) async {
    state = state.copyWith(fontSize: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFontSize, v.name);
  }

  Future<void> setCenterAlign(bool v) async {
    state = state.copyWith(centerAlign: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCenter, v);
  }

  Future<void> setScrollSpeed(LyricScrollSpeed v) async {
    state = state.copyWith(scrollSpeed: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyScrollSpeed, v.name);
  }

  Future<void> setShowTranslation(bool v) async {
    state = state.copyWith(showTranslation: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowTranslation, v);
  }
}

final lyricSettingsProvider =
    StateNotifierProvider<LyricSettingsNotifier, LyricSettings>((ref) {
  return LyricSettingsNotifier();
});