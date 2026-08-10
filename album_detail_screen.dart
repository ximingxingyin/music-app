import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/library_actions.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/track_tile.dart';

/// 专辑详情页。
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.album, required this.artist});

  final String album;
  final String artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTracks = ref.watch(tracksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(album),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '删除该专辑所有曲目',
            onPressed: () => _deleteAll(context, ref, allTracks.valueOrNull ?? []),
          ),
        ],
      ),
      body: allTracks.when(
        data: (all) {
          final tracks = all.where((t) => t.album == album && t.artist == artist).toList();
          if (tracks.isEmpty) {
            return const Center(child: Text('专辑暂无曲目'));
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (_, i) {
              final t = tracks[i];
              return TrackTile(
                track: t,
                onTap: () => ref
                    .read(playerControllerProvider)
                    .playQueue(tracks, i),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误：$e')),
      ),
    );
  }

  Future<void> _deleteAll(
      BuildContext context, WidgetRef ref, List tracks) async {
    final list = tracks.where((t) => t.album == album && t.artist == artist).toList();
    if (list.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除专辑'),
        content: Text('确定要删除《$album》共 ${list.length} 首曲目？\n不会删除设备上的源文件。'),
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
      final actions = ref.read(libraryActionsProvider);
      for (final t in list) {
        await actions.deleteTrack(t);
      }
      if (context.mounted) Navigator.pop(context);
    }
  }
}

/// 艺术家详情页。
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artist});

  final String artist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTracks = ref.watch(tracksProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(artist),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: '删除该艺术家所有曲目',
            onPressed: () => _deleteAll(context, ref, allTracks.valueOrNull ?? []),
          ),
        ],
      ),
      body: allTracks.when(
        data: (all) {
          final tracks = all.where((t) => t.artist == artist).toList();
          if (tracks.isEmpty) {
            return const Center(child: Text('该艺术家暂无曲目'));
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (_, i) {
              final t = tracks[i];
              return TrackTile(
                track: t,
                onTap: () => ref
                    .read(playerControllerProvider)
                    .playQueue(tracks, i),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('错误：$e')),
      ),
    );
  }

  Future<void> _deleteAll(
      BuildContext context, WidgetRef ref, List tracks) async {
    final list = tracks.where((t) => t.artist == artist).toList();
    if (list.isEmpty) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('删除艺术家'),
        content: Text('确定要删除 $artist 共 ${list.length} 首曲目？\n不会删除设备上的源文件。'),
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
      final actions = ref.read(libraryActionsProvider);
      for (final t in list) {
        await actions.deleteTrack(t);
      }
      if (context.mounted) Navigator.pop(context);
    }
  }
}