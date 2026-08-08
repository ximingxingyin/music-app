import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../widgets/track_tile.dart';

/// 播放历史页：按时间倒序，最多展示 200 条。
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('播放历史')),
      body: history.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('暂无播放记录',
                      style: TextStyle(color: Colors.white70)),
                ],
              ),
            );
          }
          // 按天分组
          final grouped = <String, List<HistoryItem>>{};
          final fmt = DateFormat('yyyy-MM-dd');
          for (final item in items) {
            final key = fmt.format(item.playedAt);
            grouped.putIfAbsent(key, () => []).add(item);
          }
          return ListView(
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    _labelForDate(entry.key),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...entry.value.map((h) {
                  return TrackTile(
                    track: h.track,
                    onTap: () => ref
                        .read(playerControllerProvider)
                        .playQueue(
                          items.map((e) => e.track).toList(),
                          items.indexOf(h),
                        ),
                    trailing: Text(
                      DateFormat('HH:mm').format(h.playedAt),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11,
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }

  String _labelForDate(String dateStr) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final yesterday = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(const Duration(days: 1)));
    if (dateStr == today) return '今天';
    if (dateStr == yesterday) return '昨天';
    return dateStr;
  }
}