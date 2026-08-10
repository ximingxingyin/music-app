import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/library_actions.dart';
import '../../providers/player_provider.dart';
import '../widgets/track_tile.dart';

/// 歌单详情页：列出歌单曲目 + 增删 + 播放全部。
class PlaylistScreen extends ConsumerWidget {
  const PlaylistScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTracks = ref.watch(playlistTracksProvider(playlistId));
    final asyncList = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: asyncList.maybeWhen(
          data: (list) {
            final found = list.where((p) => p.id == playlistId).firstOrNull;
            return Text(found?.name ?? '歌单');
          },
          orElse: () => const Text('歌单'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: '重命名',
            onPressed: () => _showRenameDialog(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '删除歌单',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('删除歌单'),
                  content: const Text('确定要删除这个歌单？曲目本身不会被删除。'),
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
              if (confirm == true && context.mounted) {
                await ref
                    .read(libraryActionsProvider)
                    .deletePlaylist(playlistId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: asyncTracks.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('这个歌单还是空的',
                      style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 8),
                  Text('在"曲目"里长按歌曲 → 加入歌单',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: tracks.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('播放全部'),
                          onPressed: () => ref
                              .read(playerControllerProvider)
                              .playQueue(tracks, 0),
                        ),
                      ),
                    ],
                  ),
                );
              }
              final t = tracks[i - 1];
              return TrackTile(
                track: t,
                onTap: () => ref
                    .read(playerControllerProvider)
                    .playQueue(tracks, i - 1),
                onMore: () => _showRemoveDialog(context, ref, t.id),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }

  Future<void> _showRemoveDialog(
      BuildContext context, WidgetRef ref, String trackId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('从歌单移除'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(libraryActionsProvider)
          .removeTrackFromPlaylist(playlistId, trackId);
    }
  }

  Future<void> _showRenameDialog(BuildContext context, WidgetRef ref) async {
    final list = ref.read(playlistsProvider).valueOrNull ?? [];
    final cur = list.where((p) => p.id == playlistId).firstOrNull;
    if (cur == null) return;
    final controller = TextEditingController(text: cur.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('重命名歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '新名字'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      await ref
          .read(libraryActionsProvider)
          .renamePlaylist(playlistId, newName);
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}