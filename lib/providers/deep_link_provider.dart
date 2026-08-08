import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'player_provider.dart';

/// 处理从应用快捷方式、桌面图标、Widget 进入的 deep link。
///
/// 支持：
///   ximing://now-playing    → 进入全屏播放页
///   ximing://ai-scene       → 进入 AI 场景页
///   ximing://history        → 进入播放历史页
class DeepLinkHandler {
  DeepLinkHandler(this.ref);
  final Ref ref;

  /// 处理 deep link 目标。
  /// 由 main.dart 的 MethodChannel handler 调用。
  Future<void> handle(String target) async {
    final ctx = ref.read(goRouterProvider);
    switch (target) {
      case 'now-playing':
        final handler = ref.read(audioHandlerProvider);
        if (handler.mediaItem.valueOrNull != null) {
          ctx.push('/now-playing');
        } else {
          // 没有正在播放，跳到主页
          ctx.go('/');
        }
        break;
      case 'ai-scene':
        ctx.push('/ai-scene');
        break;
      case 'history':
        ctx.push('/history');
        break;
      default:
        ctx.go('/');
    }
  }
}

final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  return DeepLinkHandler(ref);
});