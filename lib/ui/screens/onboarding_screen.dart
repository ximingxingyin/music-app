import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../services/music_scanner_service.dart';

/// 首次启动权限引导页。
///
/// 用户授权音频读取权限后才能进入主界面。
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  Future<void> _requestPermissionAndContinue() async {
    final scanner = ref.read(scannerProvider);
    final ok = await scanner.requestPermission();
    if (!ok) {
      if (!mounted) return;
      _showManualGuideDialog();
      return;
    }
    await _markCompleted();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _skipForNow() async {
    await _markCompleted();
    if (!mounted) return;
    context.go('/');
  }

  Future<void> _markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefFirstLaunch, true);
  }

  void _showManualGuideDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('权限未授予'),
        content: const Text(
          '袭明音乐需要读取你设备上的音乐文件才能播放。\n\n'
          '请点击下方"打开设置"，在"权限"中允许"音乐和音频"。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text('打开设置'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _IntroPage(
        icon: Icons.music_note_rounded,
        title: '欢迎使用袭明音乐',
        desc: '本地音乐播放器 + 合规在线电台\n简洁 / 离线优先 / 不上传你的数据',
      ),
      _IntroPage(
        icon: Icons.library_music_rounded,
        title: '扫描你设备上的音乐',
        desc: '需要授予"音乐和音频"读取权限\n只读取本地音乐，不会上传任何信息',
      ),
      _IntroPage(
        icon: Icons.radio_rounded,
        title: '在线独立音乐电台',
        desc: '集成 Jamendo、Audius 等合规开放源\n商用扩展需另行接入正版版权平台',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: pages.length,
                itemBuilder: (_, i) => pages[i],
              ),
            ),
            _PageIndicator(count: pages.length, current: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _page == pages.length - 1
                          ? _requestPermissionAndContinue
                          : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 240),
                                curve: Curves.easeOut,
                              ),
                      child: Text(
                        _page == pages.length - 1 ? '授权并开始' : '下一步',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_page == pages.length - 1)
                    TextButton(
                      onPressed: _skipForNow,
                      child: const Text('暂不授权，先逛逛'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage({
    required this.icon,
    required this.title,
    required this.desc,
  });

  final IconData icon;
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.deepPurple.withOpacity(0.5),
                  Colors.blue.withOpacity(0.4),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            desc,
            style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.current});
  final int count;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Colors.deepPurple : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}