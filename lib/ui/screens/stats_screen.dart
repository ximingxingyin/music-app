import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../providers/cache_provider.dart';
import '../../providers/library_provider.dart';

/// 数据统计页：曲库 / 时长 / 缓存 / AI 创作数。
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final cacheStats = ref.watch(cacheStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('数据统计')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FutureBuilder<int>(
            future: db.totalTrackCount(),
            builder: (_, snap) => _StatCard(
              icon: Icons.library_music,
              title: '本地曲目',
              value: '${snap.data ?? 0} 首',
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: db.totalDurationMs(),
            builder: (_, snap) {
              final ms = snap.data ?? 0;
              final dur = Duration(milliseconds: ms);
              final hours = dur.inHours;
              final minutes = dur.inMinutes % 60;
              return _StatCard(
                icon: Icons.schedule,
                title: '总时长',
                value: '$hours 小时 $minutes 分钟',
                color: Colors.blue,
              );
            },
          ),
          const SizedBox(height: 12),
          FutureBuilder<int>(
            future: db.aiTrackCount(),
            builder: (_, snap) => _StatCard(
              icon: Icons.auto_awesome,
              title: 'AI 创作',
              value: '${snap.data ?? 0} 首',
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 12),
          cacheStats.when(
            data: (s) => _StatCard(
              icon: Icons.cloud_download,
              title: '在线缓存',
              value: '${_formatBytes(s.totalBytes)} / ${s.count} 首',
              color: Colors.teal,
            ),
            loading: () => const _StatCard(
              icon: Icons.cloud_download,
              title: '在线缓存',
              value: '加载中...',
              color: Colors.teal,
            ),
            error: (e, _) => _StatCard(
              icon: Icons.cloud_download,
              title: '在线缓存',
              value: '错误',
              color: Colors.teal,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('说明',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text(
                  '• 本地曲目：扫描到的设备本地音频文件数\n'
                  '• 总时长：所有本地曲目时长总和\n'
                  '• AI 创作：通过 AI 创作页生成的原创曲目\n'
                  '• 在线缓存：已下载到本地的 Jamendo/Audius 曲目\n'
                  '\n'
                  '缓存管理请到 设置 → 在线资源 → 离线缓存。',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                      height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int b) {
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 13)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}