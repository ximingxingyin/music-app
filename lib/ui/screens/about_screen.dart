import 'package:flutter/material.dart';

/// 关于页：版本 / 致谢 / 开源许可。
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Logo + 名字
          Center(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF0984E3)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.music_note,
                      color: Colors.white, size: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  '袭明音乐',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'v0.7.1',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _Section(title: '简介'),
          _Item(text:
              '本地音乐播放器 + 合规在线电台发现 + AI 创作\n'
              'Flutter / Android，原生体验'),
          const SizedBox(height: 16),
          _Section(title: '功能'),
          _Item(text:
              '• 本地扫描 + 收藏 + 歌单 + 历史\n'
              '• 全局搜索（本地 + Jamendo + Audius）\n'
              '• LRC 歌词（含翻译行）\n'
              '• 离线缓存 + LRU 自动清理\n'
              '• AI 场景分类 + AI 音乐创作\n'
              '• 桌面 Widget + 应用快捷方式\n'
              '• 触屏手势（左右滑切歌 / 上下滑调音量亮度）\n'
              '• 通知栏 + 来电暂停 + 耳机拔出暂停'),
          const SizedBox(height: 16),
          _Section(title: '开源协议'),
          _Item(text: 'MIT License\n仅限代码本身。音乐版权归原权利人所有。'),
          const SizedBox(height: 16),
          _Section(title: '主要依赖'),
          _Item(text:
              '• just_audio · audio_service · just_audio_background\n'
              '• on_audio_query · drift · flutter_riverpod\n'
              '• go_router · file_picker · screen_brightness\n'
              '• audio_session · permission_handler\n'
              '• http · shared_preferences · intl · uuid'),
          const SizedBox(height: 16),
          _Section(title: '合规声明'),
          _Item(text:
              '本 App 不内置任何版权音乐。所有在线音乐来自：\n'
              '• Jamendo（CC 协议开放 API）\n'
              '• Audius（Web3 开放流媒体）\n'
              '\n'
              '本 App 仅作为本地播放器 + 合规内容聚合工具。\n'
              '用户上传、分享的内容由用户自行承担责任。'),
          const SizedBox(height: 32),
          Center(
            child: Text(
              '© 2026 袭明音乐',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, height: 1.7),
      ),
    );
  }
}