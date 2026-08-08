import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track.dart';
import '../../providers/cache_provider.dart';
import '../../providers/player_provider.dart';
import 'track_tile.dart';

/// 在线曲目行：右侧带下载按钮。
class OnlineTrackTile extends ConsumerWidget {
  const OnlineTrackTile({
    super.key,
    required this.track,
    required this.index,
    required this.allTracks,
  });

  final Track track;
  final int index;
  final List<Track> allTracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cacheSvc = ref.watch(cacheServiceProvider);
    return Stack(
      children: [
        TrackTile(
          track: track,
          onTap: () => ref
              .read(playerControllerProvider)
              .playQueue(allTracks, index),
        ),
        Positioned(
          right: 16,
          top: 0,
          bottom: 0,
          child: Center(
            child: FutureBuilder<bool>(
              future: cacheSvc.isCached(track),
              builder: (_, snap) {
                final cached = snap.data ?? false;
                return IconButton(
                  icon: Icon(
                    cached ? Icons.download_done : Icons.download_outlined,
                    color: cached ? Colors.green : Colors.white60,
                    size: 22,
                  ),
                  tooltip: cached ? '已缓存，点击重新下载' : '下载到本地',
                  onPressed: () => _download(context, ref, cacheSvc),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    dynamic cacheSvc,
  ) async {
    // 显示下载进度
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DownloadDialog(track: track, cacheSvc: cacheSvc),
    );
  }
}

class _DownloadDialog extends ConsumerStatefulWidget {
  const _DownloadDialog({required this.track, required this.cacheSvc});
  final Track track;
  final dynamic cacheSvc;

  @override
  ConsumerState<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends ConsumerState<_DownloadDialog> {
  double _progress = 0;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      await widget.cacheSvc.download(
        widget.track,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        setState(() {
          _done = true;
          _progress = 1;
        });
        ref.invalidate(cacheStatsProvider);
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_done ? '下载完成' : '下载中...'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          if (_error == null)
            LinearProgressIndicator(value: _progress)
          else
            Text('错误：$_error', style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          Text(
            _error == null
                ? '${(_progress * 100).toStringAsFixed(0)}%'
                : '请检查网络',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}