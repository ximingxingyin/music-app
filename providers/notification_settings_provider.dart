import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 通知栏设置
class NotificationSettings {
  /// 持续显示通知栏图标（即使暂停）
  final bool persistent;
  /// 显示快进/快退按钮
  final bool showSeekButtons;
  /// 通知样式
  final NotificationStyle style;

  const NotificationSettings({
    this.persistent = true,
    this.showSeekButtons = true,
    this.style = NotificationStyle.standard,
  });

  NotificationSettings copyWith({
    bool? persistent,
    bool? showSeekButtons,
    NotificationStyle? style,
  }) {
    return NotificationSettings(
      persistent: persistent ?? this.persistent,
      showSeekButtons: showSeekButtons ?? this.showSeekButtons,
      style: style ?? this.style,
    );
  }
}

enum NotificationStyle { standard, compact, large }

class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  static const _keyPersistent = 'notification.persistent';
  static const _keyShowSeek = 'notification.show_seek';
  static const _keyStyle = 'notification.style';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      persistent: prefs.getBool(_keyPersistent) ?? true,
      showSeekButtons: prefs.getBool(_keyShowSeek) ?? true,
      style: NotificationStyle.values.firstWhere(
        (s) => s.name == prefs.getString(_keyStyle),
        orElse: () => NotificationStyle.standard,
      ),
    );
  }

  Future<void> setPersistent(bool v) async {
    state = state.copyWith(persistent: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPersistent, v);
  }

  Future<void> setShowSeekButtons(bool v) async {
    state = state.copyWith(showSeekButtons: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShowSeek, v);
  }

  Future<void> setStyle(NotificationStyle v) async {
    state = state.copyWith(style: v);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyStyle, v.name);
  }
}

final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
        (ref) => NotificationSettingsNotifier());