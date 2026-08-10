import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/exclusion_provider.dart';

/// 排除文件夹设置页：管理扫描黑名单 + 一键清理脏数据。
class ExclusionScreen extends ConsumerWidget {
  const ExclusionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excluded = ref.watch(excludedFoldersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('排除文件夹')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '扫描时将跳过黑名单中的文件夹。\n'
                '例如录音、播客下载文件夹，避免污染曲库。',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                    height: 1.5),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text('已排除',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                  onPressed: () => _showAddDialog(context, ref),
                ),
              ],
            ),
          ),
          excluded.when(
            data: (set) {
              if (set.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      '暂无排除的文件夹',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 13),
                    ),
                  ),
                );
              }
              return Column(
                children: set.map((p) {
                  final display = p.length > 50 ? '${p.substring(0, 50)}...' : p;
                  return ListTile(
                    leading: const Icon(Icons.folder_off, color: Colors.white60),
                    title: Text(display,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                    subtitle: Text(p,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 10)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () async {
                        await ref
                            .read(exclusionServiceProvider)
                            .removeExclusion(p);
                        ref.invalidate(excludedFoldersProvider);
                      },
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('加载失败：$e')),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services, color: Colors.amber),
            title: const Text('清理已不存在的曲目'),
            subtitle: const Text(
                '扫描设备，对比文件实际存在性，删除"孤儿"记录'),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('清理脏数据'),
                  content: const Text(
                      '将检查所有本地曲目，删除文件已不存在的记录。\n'
                      '这可能需要数十秒到几分钟。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('开始'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
                final n = await ref
                    .read(cleanupServiceProvider)
                    .cleanupMissingFiles();
                if (context.mounted) {
                  Navigator.of(context, rootNavigator: true).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('清理完成，删除 $n 条孤儿记录')),
                  );
                  ref.invalidate(tracksProvider);
                  ref.invalidate(albumsProvider);
                  ref.invalidate(artistsProvider);
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final candidates =
        await ref.read(cleanupServiceProvider).listCandidateFolders();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('选择要排除的文件夹'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: candidates.map((p) {
              final display = p.length > 50 ? '${p.substring(0, 50)}...' : p;
              return ListTile(
                title: Text(display,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(p,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10)),
                onTap: () async {
                  await ref.read(exclusionServiceProvider).addExclusion(p);
                  ref.invalidate(excludedFoldersProvider);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }
}