import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/models/track.dart';
import '../services/audio_player_handler.dart';
import 'cache_provider.dart';
import 'library_actions.dart';

/// 全局播放器 handler（由 main.dart 注入）。
final audioHandlerProvider = Provider<AppAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden in main()');
});

/// 当前曲目（含完整 URI，用于歌词加载等）
final currentTrackFullProvider = StreamProvider<Track?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  // 合并 queue 变化 + index 变化 + mediaItem 变化
  final controller = StreamController<Track?>();
  Track? last;
  void emit() {
    final q = handler.queue;
    final i = handler.currentIndex;
    if (q.isEmpty || i < 0 || i >= q.length) {
      if (last != null) {
        last = null;
        controller.add(null);
      }
      return;
    }
    final t = q[i];
    if (t.id != last?.id || t.uri != last?.uri) {
      last = t;
      controller.add(t);
    }
  }

  final subs = <StreamSubscription>[
    handler.queueStream.listen((_) => emit()),
    handler.indexStream.listen((_) => emit()),
    handler.mediaItem.listen((_) => emit()),
  ];
  emit();

  ref.onDispose(() {
    for (final s in subs) {
      s.cancel();
    }
    controller.close();
  });
  return controller.stream;
});

/// 当前曲目
final currentTrackProvider = StreamProvider<Track?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem.map((m) {
    if (m == null) return null;
    return Track(
      id: m.id,
      title: m.title,
      artist: m.artist ?? '',
      album: m.album ?? '',
      duration: m.duration ?? Duration.zero,
      uri: '',
      source: TrackSource.local,
      albumArtUrl: m.artUri?.toString(),
    );
  });
});

/// 播放/暂停
final isPlayingProvider = StreamProvider<bool>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState.map((s) => s.playing);
});

/// 进度
final positionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState.map((s) => s.updatePosition);
});

/// 缓冲进度
final bufferedPositionProvider = StreamProvider<Duration>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState.map((s) => s.bufferedPosition);
});

/// 播放队列
final queueProvider = StreamProvider<List<Track>>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.queue.map((qs) {
    return qs
        .map((m) => Track(
              id: m.id,
              title: m.title,
              artist: m.artist ?? '',
              album: m.album ?? '',
              duration: m.duration ?? Duration.zero,
              uri: '',
              source: TrackSource.local,
              albumArtUrl: m.artUri?.toString(),
            ))
        .toList();
  });
});

/// 循环模式
final repeatModeProvider = StreamProvider<RepeatMode>((ref) async* {
  final handler = ref.watch(audioHandlerProvider);
  yield handler.repeatMode;
  yield* handler.playbackState.map((s) {
    switch (s.repeatMode) {
      case AudioServiceRepeatMode.none:
        return RepeatMode.off;
      case AudioServiceRepeatMode.all:
        return RepeatMode.all;
      case AudioServiceRepeatMode.one:
        return RepeatMode.one;
      case AudioServiceRepeatMode.group:
        return RepeatMode.all;
    }
  });
});

/// 播放速度 Provider（暴露当前速度值 + 循环切换入口）
final speedProvider = StreamProvider<double>((ref) async* {
  final handler = ref.watch(audioHandlerProvider);
  yield handler.currentSpeed;
  // 速度变化会触发 playbackState 更新
  yield* handler.playbackState.map((_) => handler.currentSpeed);
});

/// Player Controller —— 提供高层操作。
class PlayerController {
  PlayerController(this.ref);
  final Ref ref;

  AppAudioHandler get _handler => ref.read(audioHandlerProvider);

  Future<void> playQueue(List<Track> tracks, int index) async {
    // 对在线曲目优先用本地缓存路径
    final cacheSvc = ref.read(cacheServiceProvider);
    final resolved = <Track>[];
    for (final t in tracks) {
      if (!t.isLocal) {
        // 直播流（radio）不可缓存，直接播放
        if (!t.cacheable) {
          resolved.add(t);
          continue;
        }
        final local = await cacheSvc.getCachedPath(t);
        if (local != null) {
          // 标记已播放（用于 LRU）
          // ignore: unawaited_futures
          cacheSvc.markPlayed(t.id);
          resolved.add(t.copyWith(uri: local));
          continue;
        }
      }
      resolved.add(t);
    }
    await _handler.setQueue(resolved, index);
    // 记录播放
    if (index >= 0 && index < resolved.length) {
      final t = resolved[index];
      if (t.isLocal) {
        // ignore: unawaited_futures
        ref.read(libraryActionsProvider).recordPlay(t.id);
      }
    }
  }

  Future<void> play() => _handler.play();
  Future<void> pause() => _handler.pause();
  Future<void> next() => _handler.skipToNext();
  Future<void> previous() => _handler.skipToPrevious();
  Future<void> seek(Duration d) => _handler.seek(d);
  Future<void> cycleRepeat() => _handler.cycleRepeat();
  Future<void> toggleShuffle() => _handler.toggleShuffle();
  Future<void> cycleSpeed() => _handler.cycleSpeed();
  Future<void> setSpeedIndex(int i) => _handler.setSpeedIndex(i);
}

final playerControllerProvider = Provider<PlayerController>((ref) {
  return PlayerController(ref);
});