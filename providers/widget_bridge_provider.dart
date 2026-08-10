import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'player_provider.dart';

/// 与 Android 桌面 Widget 通信的服务。
///
/// 写入 SharedPreferences "ximing_widget" 给 Widget 读，
/// 定期检查 "ximing_media_control" 的 pending_action。
class WidgetBridgeService {
  WidgetBridgeService(this.ref);
  final Ref ref;

  static const _widgetPrefs = 'ximing_widget';
  static const _mediaPrefs = 'ximing_media_control';

  Timer? _pollTimer;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    // 启动时立即同步一次
    await _syncWidgetState();
    // 监听播放状态变化
    final handler = ref.read(audioHandlerProvider);
    handler.mediaItem.listen((_) => _syncWidgetState());
    handler.playbackState.listen((_) => _syncWidgetState());
    // 定期同步（Widget 内部 30 分钟最小间隔，我们 5 秒主动推一次）
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _syncWidgetState();
      await _consumeMediaAction();
    });
  }

  Future<void> _syncWidgetState() async {
    try {
      final handler = ref.read(audioHandlerProvider);
      final mediaItem = handler.mediaItem.valueOrNull;
      final playing = handler.playbackState.valueOrNull?.playing ?? false;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_widgetPrefs}_title', mediaItem?.title ?? '未在播放');
      await prefs.setString('${_widgetPrefs}_artist', mediaItem?.artist ?? '袭明音乐');
      await prefs.setBool('${_widgetPrefs}_playing', playing);
      await prefs.setString('${_widgetPrefs}_artUri', mediaItem?.artUri?.toString() ?? '');
    } catch (_) {}
  }

  Future<void> _consumeMediaAction() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final action = prefs.getString('${_mediaPrefs}_pending_action');
      if (action == null) return;
      await prefs.remove('${_mediaPrefs}_pending_action');

      final handler = ref.read(audioHandlerProvider);
      switch (action) {
        case 'ACTION_PLAY':
          await handler.play();
          break;
        case 'ACTION_PAUSE':
          await handler.pause();
          break;
        case 'ACTION_NEXT':
          await handler.skipToNext();
          break;
        case 'ACTION_PREV':
          await handler.skipToPrevious();
          break;
      }
    } catch (_) {}
  }

  void dispose() {
    _pollTimer?.cancel();
  }
}

final widgetBridgeProvider = Provider<WidgetBridgeService>((ref) {
  final svc = WidgetBridgeService(ref);
  ref.onDispose(svc.dispose);
  return svc;
});