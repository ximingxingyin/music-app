import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 主题模式
enum AppThemeMode { system, light, dark }

/// 主色调
enum AppAccent {
  purple('紫色', Color(0xFF6C5CE7)),
  blue('蓝色', Color(0xFF0984E3)),
  green('绿色', Color(0xFF00B894)),
  pink('粉色', Color(0xFFFD79A8)),
  orange('橙色', Color(0xFFE17055));

  final String label;
  final Color color;
  const AppAccent(this.label, this.color);

  static AppAccent fromName(String? n) {
    return AppAccent.values.firstWhere(
      (e) => e.name == n,
      orElse: () => AppAccent.purple,
    );
  }
}

/// 主题设置
class AppThemeSettings {
  final AppThemeMode mode;
  final AppAccent accent;

  const AppThemeSettings({
    this.mode = AppThemeMode.dark,
    this.accent = AppAccent.purple,
  });

  ThemeMode get materialMode {
    switch (mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
    }
  }

  AppThemeSettings copyWith({AppThemeMode? mode, AppAccent? accent}) {
    return AppThemeSettings(
      mode: mode ?? this.mode,
      accent: accent ?? this.accent,
    );
  }
}

class AppThemeNotifier extends StateNotifier<AppThemeSettings> {
  AppThemeNotifier() : super(const AppThemeSettings()) {
    _load();
  }

  static const _keyMode = 'theme.mode';
  static const _keyAccent = 'theme.accent';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AppThemeSettings(
      mode: AppThemeMode.values.firstWhere(
        (m) => m.name == prefs.getString(_keyMode),
        orElse: () => AppThemeMode.dark,
      ),
      accent: AppAccent.fromName(prefs.getString(_keyAccent)),
    );
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyMode, mode.name);
  }

  Future<void> setAccent(AppAccent accent) async {
    state = state.copyWith(accent: accent);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyAccent, accent.name);
  }
}

final appThemeProvider =
    StateNotifierProvider<AppThemeNotifier, AppThemeSettings>((ref) {
  return AppThemeNotifier();
});