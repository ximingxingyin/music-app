import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/lyric_settings_provider.dart';
import '../../providers/notification_settings_provider.dart';
import '../../providers/playback_enhancements_provider.dart';
import '../../providers/theme_provider.dart';

/// 设置页：歌词显示设置。
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(lyricSettingsProvider);
    final notifier = ref.read(lyricSettingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader(title: '外观'),
          Consumer(
            builder: (_, ref, __) {
              final s = ref.watch(appThemeProvider);
              final notifier = ref.read(appThemeProvider.notifier);
              return Column(
                children: [
                  ListTile(
                    title: const Text('主题模式'),
                    subtitle: Text(_themeModeLabel(s.mode)),
                    trailing: Wrap(
                      spacing: 4,
                      children: AppThemeMode.values.map((m) {
                        final active = m == s.mode;
                        return ChoiceChip(
                          label: Text(_themeModeShort(m)),
                          selected: active,
                          onSelected: (_) => notifier.setMode(m),
                        );
                      }).toList(),
                    ),
                  ),
                  ListTile(
                    title: const Text('主色调'),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: AppAccent.values.map((a) {
                          final active = a == s.accent;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => notifier.setAccent(a),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: a.color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: active
                                        ? Colors.white
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: active
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 18)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: '通知栏'),
          Consumer(
            builder: (_, ref, __) {
              final s = ref.watch(notificationSettingsProvider);
              final notifier = ref.read(notificationSettingsProvider.notifier);
              return Column(
                children: [
                  SwitchListTile(
                    title: const Text('持续显示通知'),
                    subtitle: const Text('暂停时也保留通知栏图标'),
                    value: s.persistent,
                    onChanged: notifier.setPersistent,
                  ),
                  SwitchListTile(
                    title: const Text('显示快进快退按钮'),
                    subtitle: const Text('通知栏控制条上的 30 秒按钮'),
                    value: s.showSeekButtons,
                    onChanged: notifier.setShowSeekButtons,
                  ),
                  ListTile(
                    title: const Text('通知样式'),
                    subtitle: Text(_notifStyleLabel(s.style)),
                    trailing: Wrap(
                      spacing: 4,
                      children: NotificationStyle.values.map((st) {
                        final active = st == s.style;
                        return ChoiceChip(
                          label: Text(_notifStyleShort(st)),
                          selected: active,
                          onSelected: (_) => notifier.setStyle(st),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          const _SectionHeader(title: '歌词显示'),
          ListTile(
            title: const Text('字号'),
            subtitle: Text(
              '当前 ${s.fontSize.label}（${s.fontSize.pt.toStringAsFixed(0)}pt）',
            ),
            trailing: Wrap(
              spacing: 4,
              children: LyricFontSize.values.map((v) {
                final active = v == s.fontSize;
                return ChoiceChip(
                  label: Text(v.label),
                  selected: active,
                  onSelected: (_) => notifier.setFontSize(v),
                );
              }).toList(),
            ),
          ),
          SwitchListTile(
            title: const Text('居中对齐'),
            subtitle: const Text('关闭后歌词左对齐'),
            value: s.centerAlign,
            onChanged: notifier.setCenterAlign,
          ),
          SwitchListTile(
            title: const Text('显示翻译行'),
            subtitle: const Text('仅对含双语 LRC 文件生效'),
            value: s.showTranslation,
            onChanged: notifier.setShowTranslation,
          ),
          ListTile(
            title: const Text('滚动速度'),
            subtitle: Text('当前 ${s.scrollSpeed.label}'),
            trailing: Wrap(
              spacing: 4,
              children: LyricScrollSpeed.values.map((v) {
                final active = v == s.scrollSpeed;
                return ChoiceChip(
                  label: Text(v.label),
                  selected: active,
                  onSelected: (_) => notifier.setScrollSpeed(v),
                );
              }).toList(),
            ),
          ),
          const Divider(),
          const _SectionHeader(title: '数据'),
          ListTile(
            title: const Text('歌单导入导出'),
            subtitle: const Text('m3u 格式与其他 App 互通'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/playlist-import-export'),
          ),
          ListTile(
            title: const Text('清空播放历史'),
            subtitle: const Text('删除所有"最近听过"记录，不影响收藏和歌单'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('清空播放历史'),
                  content: const Text('将删除所有播放记录，确定吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('清空'),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await ref.read(libraryActionsProvider).clearHistory();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('播放历史已清空')),
                  );
                }
              }
            },
          ),
          const Divider(),
          const _SectionHeader(title: '曲库管理'),
          ListTile(
            title: const Text('排除文件夹'),
            subtitle: const Text('扫描时跳过指定路径（如录音、播客）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/exclusion'),
          ),
          const Divider(),
          const _SectionHeader(title: 'AI 能力'),
          ListTile(
            title: const Text('AI 创作'),
            subtitle: const Text('输入描述，生成原创音乐'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/ai-compose'),
          ),
          const Divider(),
          const _SectionHeader(title: '在线资源'),
          ListTile(
            title: const Text('离线缓存'),
            subtitle: const Text('管理已下载的在线电台曲目'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/cache'),
          ),
          const Divider(),
          const _SectionHeader(title: '音质'),
          ListTile(
            title: const Text('均衡器'),
            subtitle: const Text('预设 EQ（v0.5 实装真正生效）'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _EqualizerScreen()),
            ),
          ),
          const _SectionHeader(title: '预览'),
          Container(
            height: 200,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '当前播放的歌词行',
                    textAlign: s.centerAlign ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: s.activeFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '前一行的歌词',
                    textAlign: s.centerAlign ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: s.inactiveFontSize,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '再前一行的歌词',
                    textAlign: s.centerAlign ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: s.inactiveFontSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const _SectionHeader(title: '关于'),
          ListTile(
            title: const Text('数据统计'),
            subtitle: const Text('本地曲库 / 时长 / AI 创作 / 缓存'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/stats'),
          ),
          ListTile(
            title: const Text('关于袭明音乐'),
            subtitle: const Text('版本 · 开源许可 · 致谢'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
          const Divider(),
          Center(
            child: Text(
              '袭明音乐 · v0.7.1',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

String _notifStyleLabel(NotificationStyle s) {
  switch (s) {
    case NotificationStyle.standard:
      return '标准';
    case NotificationStyle.compact:
      return '紧凑（更小）';
    case NotificationStyle.large:
      return '大图（更大封面）';
  }
}

String _notifStyleShort(NotificationStyle s) {
  switch (s) {
    case NotificationStyle.standard:
      return '标准';
    case NotificationStyle.compact:
      return '紧凑';
    case NotificationStyle.large:
      return '大图';
  }
}

String _themeModeShort(AppThemeMode m) {
  switch (m) {
    case AppThemeMode.system:
      return '自动';
    case AppThemeMode.light:
      return '亮';
    case AppThemeMode.dark:
      return '暗';
  }
}

String _themeModeLabel(AppThemeMode m) {
  switch (m) {
    case AppThemeMode.system:
      return '跟随系统';
    case AppThemeMode.light:
      return '亮色主题（白天省眼）';
    case AppThemeMode.dark:
      return '暗色主题（默认）';
  }
}

/// 均衡器子页面
class _EqualizerScreen extends ConsumerWidget {
  const _EqualizerScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available = ref.watch(equalizerAvailableProvider);
    final currentName = ref.watch(equalizerPresetProvider);
    final notifier = ref.read(equalizerPresetProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('均衡器')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          if (!available)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.withValues(alpha: 0.8)),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '均衡器 API 实装中（v0.5 上线）。当前可浏览预设和频段曲线，'
                      '选中不会真正修改音频。',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('预设', style: TextStyle(fontSize: 12, color: Colors.white60)),
          ),
          ...kEqualizerPresets.map((preset) {
            final active = preset.name == currentName;
            return ListTile(
              title: Text(preset.name,
                  style: TextStyle(
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  )),
              subtitle: Text(preset.description,
                  style: const TextStyle(fontSize: 12, color: Colors.white60)),
              trailing: active
                  ? const Icon(Icons.check, color: Colors.deepPurple)
                  : null,
              onTap: () => notifier.state = preset.name,
            );
          }),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('频段曲线预览',
                style: TextStyle(fontSize: 12, color: Colors.white60)),
          ),
          _EqualizerCurve(
            gains: kEqualizerPresets
                .firstWhere((p) => p.name == currentName,
                    orElse: () => kEqualizerPresets.first)
                .gains,
          ),
          const SizedBox(height: 24),
          _EqualizerSliders(
            gains: kEqualizerPresets
                .firstWhere((p) => p.name == currentName,
                    orElse: () => kEqualizerPresets.first)
                .gains,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

/// 5 段频段曲线图
class _EqualizerCurve extends StatelessWidget {
  const _EqualizerCurve({required this.gains});
  final List<int> gains;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _EqPainter(gains: gains.map((g) => g.toDouble()).toList()),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  _EqPainter({required this.gains});
  final List<double> gains;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    final center = size.height / 2;
    for (var i = 0; i < 4; i++) {
      final y = center - 30 + i * 20;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final paint = Paint()
      ..color = Colors.deepPurple
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final maxGain = 6.0;
    final dx = size.width / (gains.length - 1);
    final path = Path();
    for (var i = 0; i < gains.length; i++) {
      final x = i * dx;
      final normalized = (gains[i] / maxGain).clamp(-1.0, 1.0);
      final y = center - normalized * (size.height / 2 - 10);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4,
          Paint()..color = Colors.deepPurpleAccent);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _EqPainter old) => old.gains != gains;
}

class _EqualizerSliders extends StatelessWidget {
  const _EqualizerSliders({required this.gains});
  final List<int> gains;

  @override
  Widget build(BuildContext context) {
    const labels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(gains.length, (i) {
          return Column(
            children: [
              Text('${gains[i] >= 0 ? '+' : ''}${gains[i]}dB',
                  style: const TextStyle(fontSize: 10, color: Colors.white60)),
              SizedBox(
                height: 120,
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Slider(
                    value: gains[i].toDouble(),
                    min: -6,
                    max: 6,
                    onChanged: null, // v0.5 实装
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  style: const TextStyle(fontSize: 10, color: Colors.white60)),
            ],
          );
        }),
      ),
    );
  }
}