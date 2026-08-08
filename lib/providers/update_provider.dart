import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 版本升级信息。
class UpdateInfo {
  final String version;
  final List<String> changelog;
  final String? downloadUrl;
  final bool required;
  const UpdateInfo({
    required this.version,
    required this.changelog,
    this.downloadUrl,
    this.required = false,
  });
}

/// 当前已知版本信息（v0.8 changelog）
/// 实际商用时应改为远程配置（如 Firebase Remote Config / 自建 API）
final UpdateInfo kCurrentUpdateInfo = UpdateInfo(
  version: 'v0.8',
  changelog: [
    '✨ 新增：扫描排除文件夹（黑名单）',
    '✨ 新增：一键清理已不存在的曲目',
    '✨ 新增：歌词点击跳转 + 长按复制',
    '✨ 新增：±10 秒快进快退按钮',
    '✨ 新增：主题切换（暗 / 亮 / 跟随系统）',
    '✨ 新增：5 种主色调自定义',
    '✨ 新增：歌单导入导出 m3u',
    '✨ 新增：搜索历史记录',
    '✨ 新增：双击歌词快进 / 三击歌词快退',
    '🐛 修复：音量控制不生效',
    '🐛 修复：应用快捷方式无法跳转',
    '🐛 修复：部分崩溃与 UI 错位',
  ],
);

class UpdateNotifier extends StateNotifier<bool> {
  UpdateNotifier() : super(false);

  /// 检查并显示更新提示（首次启动每个版本只显示一次）。
  Future<void> checkAndShow(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getString('update.dismissed_version');
    if (dismissed == kCurrentUpdateInfo.version) return;
    if (!context.mounted) return;
    state = true;
    await showDialog<void>(
      context: context,
      builder: (_) => _UpdateDialog(info: kCurrentUpdateInfo),
    );
    if (!context.mounted) return;
    await prefs.setString(
        'update.dismissed_version', kCurrentUpdateInfo.version);
    state = false;
  }
}

final updateNotifierProvider =
    StateNotifierProvider<UpdateNotifier, bool>((ref) => UpdateNotifier());

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.info});
  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.celebration, color: Colors.amber),
          const SizedBox(width: 8),
          Text('更新到 ${info.version}'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...info.changelog.map((c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $c',
                      style: const TextStyle(fontSize: 13, height: 1.5)),
                )),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('稍后'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.pop(context);
            // 真实场景：跳转下载链接
            // 这里仅关闭
          },
          child: const Text('知道了'),
        ),
      ],
    );
  }
}