import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'app.dart';
import 'providers/deep_link_provider.dart';
import 'providers/update_provider.dart';
import 'providers/widget_bridge_provider.dart';
import 'services/audio_player_handler.dart';
import 'services/audio_session_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 音频会话配置（来电/耳机事件 → just_audio 自动处理）
  await AudioSessionConfig.configure();

  // 后台播放通知元数据通道
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ximing.music.channel.audio',
    androidNotificationChannelName: '音频播放',
    androidNotificationOngoing: true,
  );

  // 启动 audio_service
  final handler = await AudioService.init(
    builder: () => AppAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.ximing.music.channel.audio',
      androidNotificationChannelName: '音频播放',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      notificationColor: const Color(0xFF6C5CE7),
    ),
  );

  final container = ProviderContainer(
    overrides: [
      audioHandlerProvider.overrideWithValue(handler as AppAudioHandler),
    ],
  );

  // 启动 Widget bridge（同步状态到桌面 Widget）
  await container.read(widgetBridgeProvider).start();

  // 注册 Deep link 通道（MainActivity 启动 / onNewIntent 时回调）
  const deepLinkChannel = MethodChannel('com.ximing.music/deeplink');
  final deepLinkHandler = container.read(deepLinkHandlerProvider);
  deepLinkChannel.setMethodCallHandler((call) async {
    if (call.method == 'onShortcut') {
      await deepLinkHandler.handle(call.arguments as String? ?? '');
    }
    return null;
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MusicApp(),
    ),
  );

  // 应用启动后延迟 1.5 秒检查更新（避免阻塞首屏）
  Future.delayed(const Duration(milliseconds: 1500), () {
    final ctx = container.read(goRouterProvider)
        .routerDelegate
        .navigatorKey
        .currentContext;
    if (ctx != null) {
      container.read(updateNotifierProvider.notifier).checkAndShow(ctx);
    }
  });
}