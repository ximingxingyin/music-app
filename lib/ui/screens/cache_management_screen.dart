import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/database/database.dart';
import '../../providers/cache_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../data/models/track.dart';

/// 缓存管理页：列出已下载的在线曲目 + 空间统计 + 一键清理。
class CacheManagementScreen extends ConsumerWidget {
  const CacheManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(cacheStatsProvider);
    final db = ref.watch(databaseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('离线缓存'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空全部',
            onPressed: () => _confirmClear(context, ref),
          ),
        ],
      ),
      body: stats.when(
        data: (s) {
          final pct = (s.totalBytes / (500 * 1024 * 1024)).clamp(0.0, 1.0);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A24),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sd_storage, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '已用 ${_formatBytes(s.totalBytes)} / 500 MB',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation(
                              Colors.deepPurple),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${s.count} 首已缓存 · 超出上限时按"最近播放"自动清理',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CachedTrackRow>>(
                  future: db.getAllCaches(),
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final list = snap.data ?? [];
                    if (list.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.cloud_off,
                                size: 64, color: Colors.white24),
                            SizedBox(height: 16),
                            Text('还没有缓存',
                                style: TextStyle(color: Colors.white70)),
                            SizedBox(height: 8),
                            Text('到在线电台页面点击下载按钮即可缓存',
                                style: TextStyle(
                                    color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final r = list[i];
                        return _CacheRow(row: r, db: db);
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误：$e')),
      ),
    );
  }

  String _formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('清空所有缓存'),
        content: const Text('将删除所有已下载的在线曲目文件，不可恢复。确定吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(cacheServiceProvider).clearAll();
      ref.invalidate(cacheStatsProvider);
    }
  }
}

class _CacheRow extends ConsumerWidget {
  const _CacheRow({required this.row, required this.db});
  final CachedTrackRow row;
  final AppDatabase db;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Track?>(
      future: _lookup(),
      builder: (_, snap) {
        final t = snap.data;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: row.source == 'jamendo'
                ? Colors.deepPurple.withOpacity(0.4)
                : Colors.teal.withOpacity(0.4),
            child: Icon(
              row.source == 'jamendo' ? Icons.public : Icons.graphic_eq,
              size: 18,
              color: Colors.white70,
            ),
          ),
          title: Text(t?.title ?? row.id,
              maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${t?.artist ?? ''} · ${_formatBytes(row.sizeBytes)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: Colors.white.withOpacity(0.6), fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white60),
            onPressed: () async {
              // ignore: unawaited_futures
              ref.read(cacheServiceProvider).deleteCacheEntry(row.id);
              ref.invalidate(cacheStatsProvider);
            },
          ),
          onTap: () {
            if (t != null) {
              ref.read(playerControllerProvider).playQueue([t], 0);
              context.push('/now-playing');
            }
          },
        );
      },
    );
  }

  Future<Track?> _lookup() async {
    // 简单从 jamendo/audius 已知字段查不到，转用 cachedTracks 元数据
    // 这里简化：直接构造基本信息
    return Track(
      id: row.id,
      title: row.id,
      artist: row.source,
      album: '',
      duration: Duration.zero,
      uri: row.localPath,
      source: TrackSource.values.firstWhere(
        (s) => s.name == row.source,
        orElse: () => TrackSource.audius,
      ),
    );
  }

  String _formatBytes(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}