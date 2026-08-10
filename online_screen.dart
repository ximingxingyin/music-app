import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track.dart';
import '../../providers/online_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/online_track_tile.dart';
import '../widgets/track_tile.dart';

/// Jamendo 热门 / 搜索
class JamendoScreen extends ConsumerStatefulWidget {
  const JamendoScreen({super.key});

  @override
  ConsumerState<JamendoScreen> createState() => _JamendoScreenState();
}

class _JamendoScreenState extends ConsumerState<JamendoScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(jamendoSearchQueryProvider);
    final results = ref.watch(jamendoSearchResultsProvider);
    final trending = ref.watch(jamendoTrendingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jamendo 电台'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索外文/独立音乐',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: const Color(0xFF1A1A24),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _controller.clear();
                          ref.read(jamendoSearchQueryProvider.notifier).state = '';
                        },
                      ),
              ),
              onSubmitted: (v) =>
                  ref.read(jamendoSearchQueryProvider.notifier).state = v.trim(),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? trending.when(
                    data: (tracks) => _TrackList(tracks: tracks),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('加载失败：$e')),
                  )
                : results.when(
                    data: (tracks) => _TrackList(tracks: tracks),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('加载失败：$e')),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TrackList extends ConsumerWidget {
  const _TrackList({required this.tracks});
  final List tracks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tracks.isEmpty) {
      return const Center(child: Text('暂无结果'));
    }
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (_, i) {
        final t = tracks[i];
        return OnlineTrackTile(
          track: t,
          index: i,
          allTracks: tracks,
        );
      },
    );
  }
}

/// Audius 热门
class AudiusScreen extends ConsumerWidget {
  const AudiusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trending = ref.watch(audiusTrendingProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Audius 电台')),
      body: trending.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return const Center(child: Text('暂无数据'));
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (_, i) {
              final t = tracks[i];
              return OnlineTrackTile(
                track: t,
                index: i,
                allTracks: tracks,
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Audius 节点不可用：$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60)),
          ),
        ),
      ),
    );
  }
}