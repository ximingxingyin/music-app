import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/duration_formatter.dart';
import '../../data/database/database.dart';
import '../../data/models/track.dart';
import '../../providers/library_actions.dart';
import '../../providers/library_provider.dart';

/// 列表中的曲目行。
///
/// 长按弹出操作菜单：收藏 / 加入歌单。
class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.trailing,
    this.onMore,
  });

  final Track track;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 48,
          height: 48,
          child: _AlbumCover(track: track),
        ),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${track.artist} · ${track.album}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withOpacity(0.6),
          fontSize: 12,
        ),
      ),
      trailing: trailing ??
          (onMore != null
              ? IconButton(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onPressed: onMore,
                )
              : Text(
                  formatDurationShort(track.duration),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 12,
                  ),
                )),
      onLongPress: () => _showActions(context, ref),
    );
  }

  Future<void> _showActions(BuildContext context, WidgetRef ref) async {
    final actions = ref.read(libraryActionsProvider);
    final db = ref.read(databaseProvider);
    final favs = await db.getFavorites();
    final isFav = favs.any((r) => r.id == track.id);
    final playlists = await db.getPlaylists();

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? Colors.pink : null,
              ),
              title: Text(isFav ? '取消收藏' : '加入收藏'),
              onTap: () async {
                Navigator.pop(context);
                await actions.toggleFavorite(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('从曲库删除'),
              onTap: () async {
                Navigator.pop(context);
                await _confirmDelete(context, ref, track);
              },
            ),
            const Divider(height: 0),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '加入歌单',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            if (playlists.isEmpty)
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('还没有歌单，请先创建'),
              )
            else
              ...playlists.map(
                (p) => ListTile(
                  leading: const Icon(Icons.playlist_play),
                  title: Text(p.name),
                  onTap: () async {
                    Navigator.pop(context);
                    await actions.addTrackToPlaylist(p.id, track);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已加入 ${p.name}')),
                      );
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Track track) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除曲目'),
        content: Text(
          '确定要从曲库删除《${track.title}》？\n'
          '${track.isLocal ? '不会删除设备上的源文件' : '同时会清除本地缓存（如有）'}。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(libraryActionsProvider).deleteTrack(track);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已从曲库删除')),
        );
      }
    }
  }
}

/// 智能判断加载方式（本地 file / 网络 url / 占位）。
class _AlbumCover extends StatelessWidget {
  const _AlbumCover({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    final url = track.albumArtUrl;
    if (url == null || url.isEmpty) {
      return Container(
        color: Colors.deepPurple.withOpacity(0.3),
        child: const Icon(Icons.music_note, color: Colors.white70),
      );
    }
    final isLocal =
        track.isLocal || (!url.startsWith('http') && !url.startsWith('content://'));
    if (isLocal && File(url).existsSync()) {
      return Image.file(
        File(url),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.deepPurple.withOpacity(0.3),
          child: const Icon(Icons.music_note, color: Colors.white70),
        ),
      );
    }
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.deepPurple.withOpacity(0.3),
        child: const Icon(Icons.music_note, color: Colors.white70),
      ),
    );
  }
}