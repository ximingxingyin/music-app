import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/online_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/archive_service.dart';
import '../widgets/online_track_tile.dart';

/// Internet Archive 公版音乐库（开放 API，无需 key）。
class ArchiveScreen extends ConsumerStatefulWidget {
  const ArchiveScreen({super.key});

  @override
  ConsumerState<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends ConsumerState<ArchiveScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(archiveSearchQueryProvider);
    final results = ref.watch(archiveSearchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('公版音乐库'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(archiveSearchResultsProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索古典 / 现场 / 公版音乐（如 Beethoven）',
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
                          ref.read(archiveSearchQueryProvider.notifier).state =
                              '';
                        },
                      ),
              ),
              onSubmitted: (v) =>
                  ref.read(archiveSearchQueryProvider.notifier).state =
                      v.trim(),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? const _Hint()
                : results.when(
                    data: (items) => _ItemList(items: items),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('搜索失败：$e')),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music, size: 48, color: Colors.white24),
            SizedBox(height: 12),
            Text(
              '输入关键词搜索 archive.org 的公版音频馆藏。\n'
              '古典乐、现场录音、历史录音等公开可播放资源。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white60),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemList extends ConsumerWidget {
  const _ItemList({required this.items});
  final List<ArchiveItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const Center(child: Text('暂无结果，换个关键词试试'));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              item.thumbUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48,
                height: 48,
                color: const Color(0xFF2A2A3A),
                child: const Icon(Icons.album, color: Colors.white38, size: 24),
              ),
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5),
          ),
          subtitle: Text(
            [
              item.creator,
              if (item.year != null) '${item.year}',
              if (item.downloads > 0) '${item.downloads} 次下载',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.white38),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => ArchiveDetailScreen(item: item),
            ),
          ),
        );
      },
    );
  }
}

/// 条目详情：展示该馆藏内可播放的音频文件。
class ArchiveDetailScreen extends ConsumerWidget {
  const ArchiveDetailScreen({super.key, required this.item});
  final ArchiveItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(archiveTracksProvider(item));
    return Scaffold(
      appBar: AppBar(title: const Text('馆藏详情')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    item.thumbUrl,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 88,
                      height: 88,
                      color: const Color(0xFF2A2A3A),
                      child: const Icon(Icons.album,
                          color: Colors.white38, size: 36),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          item.creator,
                          if (item.year != null) '${item.year}',
                        ].join(' · '),
                        style: const TextStyle(
                            fontSize: 12.5, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('曲目列表（可播放 / 可下载）',
                style: TextStyle(fontSize: 13, color: Colors.white70)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: tracks.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('该馆藏无可播放的音频文件'));
                }
                return ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => OnlineTrackTile(
                    track: list[i],
                    index: i,
                    allTracks: list,
                  ),
                );
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败：$e')),
            ),
          ),
        ],
      ),
    );
  }
}
