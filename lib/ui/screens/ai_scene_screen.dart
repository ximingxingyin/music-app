import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/audio_fingerprint_service.dart';
import '../widgets/track_tile.dart';

/// AI 智能场景页：根据场景分类 + 自然语言 prompt 生成歌单。
class AiSceneScreen extends ConsumerStatefulWidget {
  const AiSceneScreen({super.key});

  @override
  ConsumerState<AiSceneScreen> createState() => _AiSceneScreenState();
}

class _AiSceneScreenState extends ConsumerState<AiSceneScreen> {
  final _classifier = SmartClassifierService();
  final _promptController = TextEditingController();
  Scene? _selectedScene;
  List _tracks = const [];
  bool _loading = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _onSceneTap(Scene s) async {
    setState(() {
      _selectedScene = s;
      _loading = true;
    });
    final all = await ref.read(tracksProvider.future);
    final result = await _classifier.pickByScene(library: all, scene: s);
    if (mounted) {
      setState(() {
        _tracks = result;
        _loading = false;
      });
    }
  }

  Future<void> _onPromptSubmit(String prompt) async {
    final p = prompt.trim();
    if (p.isEmpty) return;
    setState(() {
      _loading = true;
      _selectedScene = _classifier.sceneFromPrompt(p);
    });
    final all = await ref.read(tracksProvider.future);
    final result = await _classifier.generateFromPrompt(prompt: p, library: all);
    if (mounted) {
      setState(() {
        _tracks = result;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI 智能场景')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('告诉我你想听什么感觉',
                    style: TextStyle(fontSize: 14, color: Colors.white70)),
                const SizedBox(height: 8),
                TextField(
                  controller: _promptController,
                  decoration: InputDecoration(
                    hintText: '跑步时听的歌 / 睡前助眠 / 通勤地铁',
                    prefixIcon: const Icon(Icons.auto_awesome),
                    filled: true,
                    fillColor: const Color(0xFF1A1A24),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () {
                        _onPromptSubmit(_promptController.text);
                      },
                    ),
                  ),
                  onSubmitted: _onPromptSubmit,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...Scene.values.map((s) {
            final active = _selectedScene == s;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Material(
                color: active
                    ? Colors.deepPurple.withOpacity(0.3)
                    : const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _onSceneTap(s),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _sceneColors(s),
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(_sceneIcon(s), color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.label,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text(s.desc,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.white60)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white60),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_selectedScene != null && _tracks.isNotEmpty) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '"${_selectedScene!.label}" 匹配到 ${_tracks.length} 首',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('全部播放'),
                    onPressed: () => ref
                        .read(playerControllerProvider)
                        .playQueue(
                            _tracks.cast(), 0),
                  ),
                ],
              ),
            ),
            ...List.generate(_tracks.length, (i) {
              final t = _tracks[i];
              return TrackTile(
                track: t,
                onTap: () => ref
                    .read(playerControllerProvider)
                    .playQueue(_tracks.cast(), i),
              );
            }),
          ] else if (_selectedScene != null && _tracks.isEmpty) ...[
            const SizedBox(height: 32),
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  '本地音乐中没有匹配此场景的曲目。\n'
                  '试试其他场景，或先去扫描更多本地音乐。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60),
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A24),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '说明：v0.4 基于标题关键词 + 时长匹配的启发式分类，'
                '准确率约 60-70%。v0.5+ 将集成 ONNX 模型做 BPM / 情绪检测，'
                '准确率可提升到 85%+。',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5), fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _sceneIcon(Scene s) {
    switch (s) {
      case Scene.commute:
        return Icons.directions_subway;
      case Scene.workout:
        return Icons.fitness_center;
      case Scene.sleep:
        return Icons.bedtime;
      case Scene.focus:
        return Icons.psychology;
      case Scene.chill:
        return Icons.local_cafe;
    }
  }

  List<Color> _sceneColors(Scene s) {
    switch (s) {
      case Scene.commute:
        return const [Color(0xFF6C5CE7), Color(0xFF0984E3)];
      case Scene.workout:
        return const [Color(0xFFE17055), Color(0xFFD63031)];
      case Scene.sleep:
        return const [Color(0xFF74B9FF), Color(0xFF6C5CE7)];
      case Scene.focus:
        return const [Color(0xFF00B894), Color(0xFF00CEC9)];
      case Scene.chill:
        return const [Color(0xFFFD79A8), Color(0xFFE17055)];
    }
  }
}