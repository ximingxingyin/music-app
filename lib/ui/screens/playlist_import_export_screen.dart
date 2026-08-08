import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/library_actions.dart';
import '../../providers/library_provider.dart';
import '../../services/playlist_m3u_service.dart';

/// 歌单导入导出页
class PlaylistImportExportScreen extends ConsumerWidget {
  const PlaylistImportExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('歌单导入导出')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('说明',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text(
                  '• 导出：生成 m3u 文件到 Download/袭明音乐/ 目录\n'
                  '• 导入：选择 m3u 文件，自动匹配本地曲库',
                  style: TextStyle(
                      color: Colors.white70, fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_upload),
            label: const Text('导入 m3u 文件'),
            onPressed: () => _import(context, ref),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Text('选择要导出的歌单',
                style: TextStyle(
                    fontSize: 12, color: Colors.white60, letterSpacing: 1.2)),
          ),
          playlists.when(
            data: (list) {
              if (list.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('还没有歌单',
                        style: TextStyle(color: Colors.white60)),
                  ),
                );
              }
              return Column(
                children: list.map((p) {
                  return ListTile(
                    leading: const Icon(Icons.playlist_play),
                    title: Text(p.name),
                    subtitle: Text('${p.trackCount} 首',
                        style: const TextStyle(fontSize: 12)),
                    trailing: const Icon(Icons.file_download),
                    onTap: () => _export(context, ref, p.id, p.name),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('错误：$e')),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
      BuildContext context, WidgetRef ref, String id, String name) async {
    final db = ref.read(databaseProvider);
    final svc = PlaylistM3uService(db);
    try {
      final path = await svc.exportPlaylist(playlistId: id, playlistName: name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导出到 $path')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出失败：$e')),
      );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path = picked.path;
    if (path == null) return;

    final db = ref.read(databaseProvider);
    final svc = PlaylistM3uService(db);
    try {
      final newId = await svc.importFromFile(file: File(path));
      ref.invalidate(playlistsProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('导入成功')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$e')),
      );
    }
  }
}