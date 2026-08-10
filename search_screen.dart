import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track.dart';
import '../../providers/library_provider.dart';
import '../../providers/online_provider.dart';
import '../../providers/player_provider.dart';
import '../../providers/search_history_provider.dart';
import '../widgets/online_track_tile.dart';
import '../widgets/track_tile.dart';

/// 全局搜索页：本地 + Jamendo + Audius 三源并行检索。
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () async {
      final q = v.trim();
      ref.read(searchQueryProvider.notifier).state = q;
      ref.read(jamendoSearchQueryProvider.notifier).state = q;
      ref.read(audiusSearchQueryProvider.notifier).state = q;
      // 写入搜索历史
      if (q.isNotEmpty && q.length >= 2) {
        await SearchHistoryService().addHistory(q);
        ref.invalidate(searchHistoryProvider);
        ref.invalidate(searchHotProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localAsync = ref.watch(searchResultsProvider);
    final jamendoAsync = ref.watch(jamendoSearchResultsProvider);
    final audiusAsync = ref.watch(audiusSearchResultsProvider);
    final query = ref.watch(searchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜索本地 / Jamendo / Audius',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Colors.white.withOpacity(0.5),
            ),
          ),
          style: const TextStyle(fontSize: 18),
          onChanged: _onChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '本地'),
            Tab(text: 'Jamendo'),
            Tab(text: 'Audius'),
          ],
        ),
      ),
      body: query.isEmpty
          ? _EmptyState(
              onTapKeyword: (q) {
                _controller.text = q;
                _onChanged(q);
              },
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _LocalResults(asyncList: localAsync),
                _JamendoResults(asyncList: jamendoAsync),
                _AudiusResults(asyncList: audiusAsync),
              ],
            ),
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState({required this.onTapKeyword});
  final void Function(String) onTapKeyword;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final hot = ref.watch(searchHotProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 32),
        Icon(Icons.search,
            size: 56, color: Colors.white.withOpacity(0.2)),
        const SizedBox(height: 16),
        const Center(
          child: Text('输入关键词开始搜索',
              style: TextStyle(color: Colors.white60)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            '本地：曲名 / 艺术家 / 专辑\n'
            'Jamendo：欧美独立音乐（CC 协议）\n'
            'Audius：当前仅支持热门榜单',
            style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 12,
                height: 1.6),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 32),
        history.when(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('最近搜索',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12)),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            await SearchHistoryService().clearHistory();
                            ref.invalidate(searchHistoryProvider);
                          },
                          child: const Text('清空',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: list.map((q) {
                        return ActionChip(
                          label: Text(q),
                          onPressed: () => onTapKeyword(q),
                        );
                      }).toList(),
                    ),
                  ],
                ),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        hot.when(
          data: (list) => list.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('热门搜索',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: list.take(8).map((q) {
                        return ActionChip(
                          label: Text(q),
                          onPressed: () => onTapKeyword(q),
                        );
                      }).toList(),
                    ),
                  ],
                ),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _LocalResults extends ConsumerWidget {
  const _LocalResults({required this.asyncList});
  final AsyncValue<List<Track>> asyncList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncList.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Center(
            child: Text('本地没有匹配的曲目', style: TextStyle(color: Colors.white60)),
          );
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
      error: (e, _) => Center(child: Text('搜索失败：$e')),
    );
  }
}

class _JamendoResults extends ConsumerWidget {
  const _JamendoResults({required this.asyncList});
  final AsyncValue<List<Track>> asyncList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncList.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Center(
            child: Text('Jamendo 没有匹配的曲目',
                style: TextStyle(color: Colors.white60)),
          );
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
      error: (e, _) => Center(child: Text('搜索失败：$e')),
    );
  }
}

class _AudiusResults extends ConsumerWidget {
  const _AudiusResults({required this.asyncList});
  final AsyncValue<List<Track>> asyncList;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return asyncList.when(
      data: (tracks) {
        if (tracks.isEmpty) {
          return const Center(
            child: Text('Audius 没有匹配的曲目',
                style: TextStyle(color: Colors.white60)),
          );
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
      error: (e, _) => Center(child: Text('Audius 搜索失败：$e')),
    );
  }
}