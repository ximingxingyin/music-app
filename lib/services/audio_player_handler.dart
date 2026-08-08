import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../core/constants.dart';
import '../data/database/database.dart';
import '../data/models/track.dart';

/// 桥接 just_audio 与 audio_service。
/// 负责：
///   1. 播放队列管理
///   2. 通知栏 / 锁屏 / 蓝牙耳机控制
///   3. 后台播放
class AppAudioHandler extends BaseAudioHandler with SeekHandler {
  AppAudioHandler() : _player = AudioPlayer() {
    _init();
  }

  final AudioPlayer _player;
  final List<Track> _queue = [];
  int _index = 0;

  /// 当前播放队列（带完整 Track 信息，含 uri）
  List<Track> get queue => List.unmodifiable(_queue);

  /// 当前曲目索引
  int get currentIndex => _index;

  /// 队列变化广播
  final _queueController = StreamController<List<Track>>.broadcast();
  Stream<List<Track>> get queueStream => _queueController.stream;

  /// 索引变化广播
  final _indexController = StreamController<int>.broadcast();
  Stream<int> get indexStream => _indexController.stream;

  AudioPlayer get player => _player;

  Future<void> _init() async {
    // 监听播放进度 → 更新 MediaItem 通知
    _player.positionStream.listen((pos) {
      playbackState.add(playbackState.value.copyWith(updatePosition: pos));
    });

    _player.playerStateStream.listen((state) {
      final playing = state.playing;
      playbackState.add(playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: const {
          ProcessingState.idle: AudioProcessingState.idle,
          ProcessingState.loading: AudioProcessingState.loading,
          ProcessingState.buffering: AudioProcessingState.buffering,
          ProcessingState.ready: AudioProcessingState.ready,
          ProcessingState.completed: AudioProcessingState.completed,
        }[state.processingState]!,
        playing: playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
      ));
    });

    // 播放结束自动下一首
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        skipToNext();
      }
    });
  }

  // ────────── 公共接口 ──────────

  /// 设置播放队列并从 index 处开始。
  Future<void> setQueue(List<Track> tracks, int index) async {
    _queue
      ..clear()
      ..addAll(tracks);
    _index = index.clamp(0, tracks.isEmpty ? 0 : tracks.length - 1);
    final sources = _queue.map(_toAudioSource).toList();
    await _player.setAudioSource(
      ConcatenatingAudioSource(children: sources),
      initialIndex: _index,
    );
    await _loadCurrent();
    _queueController.add(List.unmodifiable(_queue));
    _indexController.add(_index);
  }

  UriAudioSource _toAudioSource(Track t) {
    return AudioSource.uri(Uri.parse(t.uri));
  }

  Future<void> _loadCurrent() async {
    if (_queue.isEmpty) return;
    final t = _queue[_index];
    final item = MediaItem(
      id: t.id,
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration == Duration.zero ? null : t.duration,
      artUri: t.albumArtUrl != null ? Uri.tryParse(t.albumArtUrl!) : null,
    );
    mediaItem.add(item);
    queue.add(List.unmodifiable(_queue.map((t) => MediaItem(
          id: t.id,
          title: t.title,
          artist: t.artist,
          album: t.album,
          duration: t.duration == Duration.zero ? null : t.duration,
        ))));
  }

  @override
  Future<void> play() async {
    await _player.play();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
  }

  /// 当前是否为直播流（radio）：直播流不支持 seek。
  bool get _isLive =>
      _index >= 0 && _index < _queue.length && _queue[_index].source == TrackSource.radio;

  @override
  Future<void> seek(Duration position) async {
    if (_isLive) return;
    await _player.seek(position);
  }

  @override
  Future<void> skipToNext() async {
    if (_index < _queue.length - 1) {
      _index++;
      await _player.seekToNext();
      await _loadCurrent();
      _indexController.add(_index);
    }
  }

  @override
  Future<void> skipToPrevious() async {
    if (_player.position.inSeconds > 3 || _index == 0) {
      // 直播流且没有上一首可切时，不做任何 seek
      if (_isLive && _index == 0) return;
      await _player.seek(Duration.zero);
    } else {
      _index--;
      await _player.seekToPrevious();
      await _loadCurrent();
      _indexController.add(_index);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode != AudioServiceShuffleMode.none;
    await _player.setShuffle(enabled);
  }

  RepeatMode _repeat = RepeatMode.off;
  RepeatMode get repeatMode => _repeat;

  Future<void> cycleRepeat() async {
    _repeat = RepeatMode.values[(_repeat.index + 1) % RepeatMode.values.length];
    await _player.setLoopMode(
      const {
        RepeatMode.off: LoopMode.off,
        RepeatMode.all: LoopMode.all,
        RepeatMode.one: LoopMode.one,
      }[_repeat]!,
    );
    playbackState.add(playbackState.value.copyWith(
      repeatMode: const {
        RepeatMode.off: AudioServiceRepeatMode.none,
        RepeatMode.all: AudioServiceRepeatMode.all,
        RepeatMode.one: AudioServiceRepeatMode.one,
      }[_repeat]!,
    ));
  }

  Future<void> toggleShuffle() async {
    final cur = _player.shuffleModeEnabled;
    await _player.setShuffle(!cur);
  }

  /// 预设速度档位
  static const List<double> kSpeedPresets = [
    0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0
  ];

  int _speedIdx = 2; // 默认 1.0x

  Future<void> cycleSpeed() async {
    _speedIdx = (_speedIdx + 1) % kSpeedPresets.length;
    await _player.setSpeed(kSpeedPresets[_speedIdx]);
  }

  Future<void> setSpeedIndex(int idx) async {
    if (idx < 0 || idx >= kSpeedPresets.length) return;
    _speedIdx = idx;
    await _player.setSpeed(kSpeedPresets[_speedIdx]);
  }

  double get currentSpeed => kSpeedPresets[_speedIdx];
}