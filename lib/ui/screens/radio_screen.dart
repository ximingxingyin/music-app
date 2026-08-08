import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/track.dart';
import '../../providers/online_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/radio_browser_service.dart';

/// 中文网络电台（Radio Browser 开放 API）。
class RadioScreen extends ConsumerStatefulWidget {
  const RadioScreen({super.key});

  @override
  ConsumerState<RadioScreen> createState() => _RadioScreenState();
}

class _RadioScreenState extends ConsumerState<RadioScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(radioSearchQueryProvider);
    final results = ref.watch(radioSearchResultsProvider);
    final stations = ref.watch(radioStationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('中文网络电台'),
        actions: [
          IconButton(
            tooltip: '刷新',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(radioStationsProvider);
              ref.invalidate(radioSearchResultsProvider);
            },
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
                hintText: '搜索电台名称 / 关键词',
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
                          ref.read(radioSearchQueryProvider.notifier).state = '';
                        },
                      ),
              ),
              onSubmitted: (v) =>
                  ref.read(radioSearchQueryProvider.notifier).state = v.trim(),
            ),
          ),
          Expanded(
            child: query.isEmpty
                ? stations.when(
                    data: (list) => _StationList(stations: list),
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('加载失败：$e')),
                  )
                : results.when(
                    data: (list) => _StationList(stations: list),
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

class _StationList extends ConsumerWidget {
  const _StationList({required this.stations});
  final List<RadioStation> stations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stations.isEmpty) {
      return const Center(child: Text('暂无电台'));
    }
    return ListView.separated(
      itemCount: stations.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (_, i) {
        final s = stations[i];
        return ListTile(
          leading: _StationAvatar(url: s.favicon, name: s.name),
          title: Text(
            s.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14.5),
          ),
          subtitle: Text(
            [
              s.streamLabel,
              s.language.isNotEmpty ? s.language : '中文',
              if (s.tags.isNotEmpty) s.tags,
              if (s.bitrate != null && s.bitrate! > 0) '${s.bitrate} kbps',
            ].join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
          trailing: const Icon(Icons.play_circle_outline,
              color: Colors.white70, size: 26),
          onTap: () {
            final track = s.toTrack();
            ref
                .read(playerControllerProvider)
                .playQueue([track], 0);
          },
        );
      },
    );
  }
}

class _StationAvatar extends StatelessWidget {
  const _StationAvatar({this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.isNotEmpty;
    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFF2A2A3A),
      child: hasUrl
          ? ClipOval(
              child: Image.network(
                url!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              ),
            )
          : _fallback(),
    );
  }

  Widget _fallback() {
    return const Icon(Icons.radio, size: 22, color: Colors.white60);
  }
}
