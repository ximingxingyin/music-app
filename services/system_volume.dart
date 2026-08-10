import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// 屏幕亮度控制
class SystemBrightness {
  /// 设置屏幕亮度（0.0 - 1.0）
  static Future<void> set(double v) async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(v.clamp(0.0, 1.0));
    } catch (_) {}
  }

  /// 获取当前应用屏幕亮度
  static Future<double> get() async {
    try {
      final v = await ScreenBrightness.instance.applicationScreenBrightness;
      return v ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  /// 调节（+/- 0.05）
  static Future<void> adjust(double delta) async {
    final cur = await get();
    await set(cur + delta);
  }

  /// 恢复系统亮度
  static Future<void> reset() async {
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }
}

/// 系统音量控制（通过 MethodChannel 调用原生 API）。
///
/// 因为 just_audio 的 player.volume 只控制 App 内输出，
/// 真正调系统音量需要 Android MediaSession / stream volume。
class SystemVolume {
  static const _channel = MethodChannel('com.ximing.music/volume');

  /// 设置系统音量（0.0 - 1.0）
  static Future<void> set(double v) async {
    try {
      await _channel.invokeMethod('setVolume', v.clamp(0.0, 1.0));
    } catch (_) {}
  }

  /// 获取当前系统音量
  static Future<double> get() async {
    try {
      final v = await _channel.invokeMethod<double>('getVolume');
      return v ?? 0.5;
    } catch (_) {
      return 0.5;
    }
  }

  /// 调节（+0.05 / -0.05）
  static Future<void> adjust(double delta) async {
    final cur = await get();
    await set(cur + delta);
  }
}