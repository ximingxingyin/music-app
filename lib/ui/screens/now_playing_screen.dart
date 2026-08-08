import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track.dart';
import '../../providers/library_provider.dart';
import '../../providers/lrc_provider.dart';
import '../../providers/lyric_settings_provider.dart';
import '../../providers/playback_enhancements_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/audio_player_handler.dart';
import '../../services/lrc_parser.dart';
import '../../services/system_volume.dart';
import '../widgets/lyric_picker_sheet.dart';
import '../widgets/track_tile.dart';

/// 全屏播放页。
class NowPlayingScreen extends ConsumerWidget {
  const NowPlayingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackProvider);
    final playing = ref.watch(isPlayingProvider);
    final pos = ref.watch(positionProvider);
    final buffered = ref.watch(bufferedPositionProvider);
    final controller = ref.watch(playerControllerProvider);
    final repeat = ref.watch(repeatModeProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('正在播放', style: TextStyle(fontSize: 16)),
        actions: [
          _SleepTimerAction(),
          if (current.value?.isLocal == true)
            IconButton(
              icon: const Icon(Icons.lyrics_outlined),
              tooltip: '歌词文件',
              onPressed: () {
                final trackId = current.value!.id;
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => LyricPickerSheet(trackId: trackId),
                );
              },
            ),
          _RepeatModeAction(),
        ],
      ),
      body: current.when(
        data: (track) {
          if (track == null) {
            return const Center(child: Text('选择一首曲目开始播放'));
          }
          return _GestureArea(
            onNext: controller.next,
            onPrev: controller.previous,
            child: _buildBody(
              context, ref, track,
              controller: controller,
              duration: track.duration,
              position: pos.value ?? Duration.zero,
              bufferedPos: buffered.value ?? Duration.zero,
              isPlaying: playing.value ?? false,
              mode: repeat.value,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误：$e')),
      ),
    );
  }
}

/// 触屏手势区：
///   水平滑动 → 切歌（左滑下一首 / 右滑上一首）
///   垂直滑动 → 调系统音量 / 屏幕亮度
class _GestureArea extends StatefulWidget {
  const _GestureArea({
    required this.child,
    required this.onNext,
    required this.onPrev,
  });
  final Widget child;
  final Future<void> Function() onNext;
  final Future<void> Function() onPrev;

  @override
  State<_GestureArea> createState() => _GestureAreaState();
}

class _GestureAreaState extends State<_GestureArea>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _dragY = 0;
  bool _showVolumeHint = false;
  bool _showBrightnessHint = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: (_) {
        _dragX = 0;
      },
      onHorizontalDragUpdate: (d) {
        _dragX += d.delta.dx;
      },
      onHorizontalDragEnd: (d) {
        if (_dragX.abs() > 80) {
          if (_dragX > 0) {
            widget.onPrev();
          } else {
            widget.onNext();
          }
        }
        _dragX = 0;
      },
      onVerticalDragStart: (d) {
        _dragY = 0;
        // 左侧 = 亮度，右侧 = 音量
        final isRight = d.globalPosition.dx >
            MediaQuery.of(context).size.width / 2;
        setState(() {
          _showBrightnessHint = !isRight;
          _showVolumeHint = isRight;
        });
      },
      onVerticalDragUpdate: (d) {
        _dragY += d.delta.dy;
        final delta = -_dragY / 200; // 上滑增量为正
        if (_showVolumeHint) {
          SystemVolume.adjust(delta);
        }
        if (_showBrightnessHint) {
          SystemBrightness.adjust(delta);
        }
        _dragY = 0;
      },
      onVerticalDragEnd: (_) {
        setState(() {
          _showVolumeHint = false;
          _showBrightnessHint = false;
        });
      },
      child: Stack(
        children: [
          widget.child,
          if (_showVolumeHint)
            const Positioned(
              right: 20,
              top: 100,
              child: _GestureHint(
                icon: Icons.volume_up,
                text: '音量',
              ),
            ),
          if (_showBrightnessHint)
            const Positioned(
              left: 20,
              top: 100,
              child: _GestureHint(
                icon: Icons.brightness_6,
                text: '亮度',
              ),
            ),
        ],
      ),
    );
  }
}

class _GestureHint extends StatelessWidget {
  const _GestureHint({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}

/// 构建全屏播放页的正文（封面 + 歌词 + 控制）
Widget _buildBody(
  BuildContext context,
  WidgetRef ref,
  Track track, {
  required PlayerController controller,
  required Duration duration,
  required Duration position,
  required Duration bufferedPos,
  required bool isPlaying,
  required dynamic mode,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    child: Column(
      children: [
        Expanded(
          flex: 3,
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: _CoverImage(track: track),
              ),
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: _LyricsArea(position: position),
        ),
        const SizedBox(height: 8),
        Text(track.title,
            style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text('${track.artist} · ${track.album}',
            style:
                const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 24),
        // ±10 秒快进快退
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.replay_10_rounded, size: 32),
              tooltip: '后退 10 秒',
              onPressed: () {
                final newPos =
                    position - const Duration(seconds: 10);
                controller.seek(newPos < Duration.zero
                    ? Duration.zero
                    : newPos);
              },
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.forward_10_rounded, size: 32),
              tooltip: '快进 10 秒',
              onPressed: () {
                final newPos =
                    position + const Duration(seconds: 10);
                controller.seek(newPos > duration ? duration : newPos);
              },
            ),
          ],
        ),
        _ProgressBar(
          position: position,
          buffered: bufferedPos,
          duration: duration,
          onSeek: controller.seek,
        ),
        const SizedBox(height: 16),
        _Controls(
          isPlaying: isPlaying,
          onPlayPause: () =>
              isPlaying ? controller.pause() : controller.play(),
          onNext: controller.next,
          onPrevious: controller.previous,
          onShuffle: controller.toggleShuffle,
          speed: ref.watch(speedProvider).value ?? 1.0,
          onSpeedTap: () => _showSpeedSheet(context, ref),
        ),
      ],
    ),
  );
}

void _showSpeedSheet(BuildContext context, WidgetRef ref) {
  final ctrl = ref.read(playerControllerProvider);
  final handler = ref.read(audioHandlerProvider);
  final cur = handler.currentSpeed;
  showModalBottomSheet<void>(
    context: context,
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('播放速度',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '当前 ${cur}x',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppAudioHandler.kSpeedPresets.map((v) {
                  final active = (v - cur).abs() < 0.001;
                  return ChoiceChip(
                    label: Text('${v}x'),
                    selected: active,
                    onSelected: (_) {
                      final idx = AppAudioHandler.kSpeedPresets.indexOf(v);
                      ctrl.setSpeedIndex(idx);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withValues(alpha: 0.6),
            Colors.blue.withValues(alpha: 0.4),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(Icons.music_note, size: 96, color: Colors.white70),
    );
  }
}

/// 全屏播放页大封面（支持本地 + 网络）。
class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.track});
  final Track track;

  bool _isLocal(String u) =>
      !u.startsWith('http') && !u.startsWith('content://');

  @override
  Widget build(BuildContext context) {
    final url = track.albumArtUrl;
    if (url == null || url.isEmpty) return const _CoverPlaceholder();
    if (track.isLocal || _isLocal(url)) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
        );
      }
      return const _CoverPlaceholder();
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const _CoverPlaceholder(),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.buffered,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;
  final Duration buffered;
  final Duration duration;
  final void Function(Duration) onSeek;

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds.clamp(1, 1 << 30).toDouble();
    final curMs = position.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    final bufMs = buffered.inMilliseconds.clamp(0, maxMs.toInt()).toDouble();
    return Column(
      children: [
        Stack(
          alignment: Alignment.centerLeft,
          children: [
            LinearProgressIndicator(
              value: bufMs / maxMs,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.3)),
              minHeight: 3,
            ),
            Slider(
              value: curMs / maxMs,
              onChanged: (v) => onSeek(Duration(
                milliseconds: (v * maxMs).round(),
              )),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_fmt(position), style: const TextStyle(fontSize: 12)),
            Text(_fmt(duration), style: const TextStyle(fontSize: 12)),
          ],
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({
    required this.isPlaying,
    required this.onPlayPause,
    required this.onNext,
    required this.onPrevious,
    required this.onShuffle,
    required this.onSpeedTap,
    required this.speed,
  });

  final bool isPlaying;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onShuffle;
  final VoidCallback onSpeedTap;
  final double speed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: const Icon(Icons.shuffle_rounded, size: 24),
          onPressed: onShuffle,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 36),
          onPressed: onPrevious,
        ),
        Container(
          decoration: const BoxDecoration(
            color: Colors.deepPurple,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              size: 36,
              color: Colors.white,
            ),
            onPressed: onPlayPause,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 36),
          onPressed: onNext,
        ),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onSpeedTap,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white24),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${speed.toStringAsFixed(speed.truncateToDouble() == speed ? 0 : 2)}x',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 重复模式按钮（AppBar 右侧）。
class _RepeatModeAction extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(repeatModeProvider).value;
    return IconButton(
      icon: Icon(_iconForMode(mode)),
      tooltip: _labelForMode(mode),
      onPressed: () =>
          ref.read(playerControllerProvider).cycleRepeat(),
    );
  }

  IconData _iconForMode(dynamic mode) {
    if (mode == null) return Icons.repeat_rounded;
    switch (mode.toString()) {
      case 'RepeatMode.one':
        return Icons.repeat_one_rounded;
      case 'RepeatMode.all':
        return Icons.repeat_rounded;
      default:
        return Icons.repeat_rounded;
    }
  }

  String _labelForMode(dynamic mode) {
    if (mode == null) return '循环：关闭';
    switch (mode.toString()) {
      case 'RepeatMode.one':
        return '循环：单曲';
      case 'RepeatMode.all':
        return '循环：列表';
      default:
        return '循环：关闭';
    }
  }
}

Future<void> _onLrcLongPress(BuildContext context, LrcLine line) async {
  // 长按歌词行：复制到剪贴板
  final text = line.translation != null && line.translation!.isNotEmpty
      ? '${line.text}\n${line.translation}'
      : line.text;
  if (text.isEmpty || text == '·') return;
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}

/// 睡眠定时按钮（AppBar 右侧），激活时显示剩余分钟数。
class _SleepTimerAction extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sleepTimerTickProvider);
    final ctrl = ref.watch(sleepTimerProvider);
    final remaining = ctrl.remaining;
    return IconButton(
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.bedtime_outlined),
          if (remaining != null)
            Positioned(
              right: -8,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.deepPurple,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${remaining.inMinutes}',
                  style: const TextStyle(fontSize: 9, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
      tooltip: '睡眠定时',
      onPressed: () => _showSheet(context, ref),
    );
  }

  void _showSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) {
        return Consumer(
          builder: (context, ref, _) {
            ref.watch(sleepTimerTickProvider);
            final ctrl = ref.read(sleepTimerProvider);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('睡眠定时',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      ctrl.isActive
                          ? '将在 ${ctrl.remaining!.inMinutes} 分钟后自动暂停'
                          : '到时间后自动暂停播放',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final m in const [15, 30, 45, 60, 90])
                          ActionChip(
                            label: Text('$m 分钟'),
                            onPressed: () {
                              ctrl.start(m);
                              Navigator.pop(context);
                            },
                          ),
                      ],
                    ),
                    if (ctrl.isActive) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close),
                          label: const Text('取消定时'),
                          onPressed: () {
                            ctrl.cancel();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 歌词区：根据当前播放进度滚动 + 高亮当前行。
class _LyricsArea extends ConsumerWidget {
  const _LyricsArea({required this.position});
  final Duration position;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lrcAsync = ref.watch(currentLrcProvider);
    return lrcAsync.when(
      data: (lrc) {
        if (lrc.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lyrics_outlined, size: 32, color: Colors.white24),
                const SizedBox(height: 8),
                const Text(
                  '暂无歌词',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '将同名 .lrc 放在音乐同目录可自动识别\n'
                  '或点击右上角歌词图标手动指定',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 10,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        }
        return _LrcView(lrc: lrc, position: position);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _LrcView extends ConsumerStatefulWidget {
  const _LrcView({required this.lrc, required this.position});
  final Lrc lrc;
  final Duration position;

  @override
  ConsumerState<_LrcView> createState() => _LrcViewState();
}

class _LrcViewState extends ConsumerState<_LrcView> {
  late ScrollController _scroll;
  int _lastIdx = -1;
  int _tapCount = 0;
  Timer? _tapTimer;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
  }

  @override
  void didUpdateWidget(covariant _LrcView old) {
    super.didUpdateWidget(old);
    final idx = widget.lrc.indexAt(widget.position);
    if (idx != _lastIdx && idx >= 0 && _scroll.hasClients) {
      _lastIdx = idx;
      // 当前行滚动到中线（每行最大 ~60 px：主行 + 翻译行）
      final target = (idx * 60.0 - 80).clamp(0.0, double.infinity);
      final speed = ref.read(lyricSettingsProvider).scrollSpeed;
      _scroll.animateTo(
        target,
        duration: Duration(milliseconds: speed.ms),
        curve: Curves.easeOut,
      );
    } else if (idx == -1) {
      _lastIdx = -1;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    _tapTimer?.cancel();
    super.dispose();
  }

  void _handleTap(LrcLine line) {
    _tapCount++;
    _tapTimer?.cancel();
    if (_tapCount >= 3) {
      _tapCount = 0;
      // 三击：快退 10 秒
      final ctrl = ref.read(playerControllerProvider);
      final handler = ref.read(audioHandlerProvider);
      final newPos = handler.player.position - const Duration(seconds: 10);
      ctrl.seek(newPos < Duration.zero ? Duration.zero : newPos);
      return;
    }
    _tapTimer = Timer(const Duration(milliseconds: 300), () {
      if (_tapCount == 2) {
        // 双击：快进 10 秒
        final ctrl = ref.read(playerControllerProvider);
        final handler = ref.read(audioHandlerProvider);
        final newPos = handler.player.position + const Duration(seconds: 10);
        final maxDur = handler.mediaItem.valueOrNull?.duration ??
            const Duration(hours: 1);
        ctrl.seek(newPos > maxDur ? maxDur : newPos);
      } else if (_tapCount == 1) {
        // 单击：跳转
        ref.read(playerControllerProvider).seek(line.time);
      }
      _tapCount = 0;
    });
  }

  void _handleDoubleTap() {
    // 触发双击 - 由 _handleTap 处理，这里保留为空（避免 InkWell 弹起冲突）
  }

  @override
  Widget build(BuildContext context) {
    final idx = widget.lrc.indexAt(widget.position);
    final s = ref.watch(lyricSettingsProvider);
    final showTr = s.showTranslation && widget.lrc.hasTranslation;
    return ListView.builder(
      controller: _scroll,
      itemCount: widget.lrc.lines.length,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemBuilder: (_, i) {
        final line = widget.lrc.lines[i];
        final active = i == idx;
        final hasTr = showTr && (line.translation?.isNotEmpty ?? false);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(line),
          onDoubleTap: () => _handleDoubleTap(),
          onLongPress: () => _onLrcLongPress(context, line),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: s.centerAlign
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  line.text.isEmpty ? '·' : line.text,
                  textAlign: s.centerAlign
                      ? TextAlign.center
                      : TextAlign.start,
                  style: TextStyle(
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.4),
                    fontSize:
                        active ? s.activeFontSize : s.inactiveFontSize,
                    fontWeight:
                        active ? FontWeight.w600 : FontWeight.w400,
                    height: 1.2,
                  ),
                ),
                if (hasTr)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line.translation!,
                      textAlign: s.centerAlign
                          ? TextAlign.center
                          : TextAlign.start,
                      style: TextStyle(
                        color: active
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.3),
                        fontSize: active
                            ? s.translationFontSize
                            : s.inactiveTranslationFontSize,
                        fontStyle: FontStyle.italic,
                        height: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}