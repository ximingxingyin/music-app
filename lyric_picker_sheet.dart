import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/database.dart';
import '../../providers/library_provider.dart';
import '../../providers/lrc_provider.dart';
import '../../services/lrc_parser.dart';

/// LRC 文件选择 / 管理面板。
///
/// 用户可以从设备上选 .lrc 文件，手动指定给当前曲目。
class LyricPickerSheet extends ConsumerWidget {
  const LyricPickerSheet({super.key, required this.trackId});

  final String trackId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return FutureBuilder<String?>(
      future: db.getLrcPath(trackId),
      builder: (_, snap) {
        final currentPath = snap.data;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('歌词文件',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  '自动识别失败？手动指定一个 .lrc 文件即可。',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                if (currentPath != null && currentPath.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lyrics, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            currentPath.split('/').last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          tooltip: '清除指定',
                          onPressed: () async {
                            await db.setLrcPath(trackId, null);
                            ref.invalidate(currentLrcProvider);
                            if (context.mounted) Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('选择 .lrc 文件'),
                    onPressed: () => _pickAndSet(context, ref),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.help_outline, size: 18),
                  label: const Text('如何准备 .lrc 文件？'),
                  onPressed: () => _showHelpDialog(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndSet(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.first;
    final path = picked.path;
    if (path == null) return;

    // 简单校验：必须是 .lrc 后缀
    if (!path.toLowerCase().endsWith('.lrc')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请选择 .lrc 扩展名的文件')),
        );
      }
      return;
    }

    // 读取预览验证是否合法 LRC
    try {
      final content = await File(path).readAsString();
      final parsed = Lrc.parse(content);
      if (parsed.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('LRC 文件格式无效')),
          );
        }
        return;
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('读取文件失败')),
        );
      }
      return;
    }

    final db = ref.read(databaseProvider);
    await db.setLrcPath(trackId, path);
    ref.invalidate(currentLrcProvider);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已指定歌词：${path.split('/').last}')),
      );
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('如何准备 LRC 文件'),
        content: const SingleChildScrollView(
          child: Text(
            '1. 从歌词网站下载与曲名/歌手匹配的 .lrc 文件\n'
            '2. 标准格式示例：\n'
            '   [00:00.00]作词：张三\n'
            '   [00:01.23]作曲：李四\n'
            '   [00:05.67]第一句歌词\n'
            '   [00:12.34]第二句歌词\n'
            '\n'
            '3. 通过上面的"选择 .lrc 文件"指定即可\n'
            '\n'
            '注意：file_picker 在 Android 10+ Scoped Storage 下，'
            '只能访问用户主动选中的文件，无法授权后永久读取。'
            '所以本功能是一次性手动指定。',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}