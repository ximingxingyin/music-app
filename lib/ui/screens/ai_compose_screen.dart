import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../providers/ai_provider.dart';
import '../../providers/player_provider.dart';

/// AI 创作页：输入描述 + 选风格 → 程序化合成 → 保存到本地曲库。
class AiComposeScreen extends ConsumerStatefulWidget {
  const AiComposeScreen({super.key});

  @override
  ConsumerState<AiComposeScreen> createState() => _AiComposeScreenState();
}

class _AiComposeScreenState extends ConsumerState<AiComposeScreen> {
  final _promptController = TextEditingController();
  AiGenre _genre = AiGenre.ambient;
  int _duration = 30;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入描述')),
      );
      return;
    }
    final notifier = ref.read(aiGenerationProvider.notifier);
    final t = await notifier.generate(
      prompt: prompt,
      genre: _genre,
      durationSeconds: _duration,
    );
    if (!mounted) return;
    if (t != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已生成：${t.title}')),
      );
      // 自动播放
      ref.read(playerControllerProvider).playQueue([t], 0);
    } else {
      final err = ref.read(aiGenerationProvider).error ?? '未知错误';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$err')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiGenerationProvider);
    final aiTracks = ref.watch(aiGeneratedTracksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 创作')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('描述你想要的声音',
              style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          TextField(
            controller: _promptController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '例如：雨夜的慢节奏电子\n凌晨 4 点的咖啡馆背景\n星际穿越感的环境音乐',
              filled: true,
              fillColor: const Color(0xFF1A1A24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('风格',
              style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AiGenre.values.map((g) {
              final selected = _genre == g;
              return ChoiceChip(
                label: Text(g.label),
                selected: selected,
                onSelected: (_) => setState(() => _genre = g),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Text(
            _genre.desc,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
          ),
          const SizedBox(height: 24),
          const Text('时长（秒）',
              style: TextStyle(fontSize: 14, color: Colors.white70)),
          Slider(
            value: _duration.toDouble(),
            min: 10,
            max: 120,
            divisions: 11,
            label: '$_duration 秒',
            onChanged: (v) => setState(() => _duration = v.round()),
          ),
          Text(
            '$_duration 秒 · 约 ${(_duration * 0.5).toStringAsFixed(0)} KB',
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: state.isGenerating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(state.isGenerating ? '生成中...' : '生成音乐'),
              onPressed: state.isGenerating ? null : _generate,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A24),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '说明：v0.6 实现为程序化合成（sine wave + 包络），生成的'
              '是原创合成音，不是模仿任何已有歌曲。\n'
              'v0.7+ 将集成 Suno / 网易"星辰"等云端 AI，生成质量可质变。',
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
            ),
          ),
          const SizedBox(height: 24),
          const Text('已生成',
              style: TextStyle(fontSize: 14, color: Colors.white70)),
          const SizedBox(height: 8),
          aiTracks.when(
            data: (tracks) {
              if (tracks.isEmpty) {
                return Text(
                  '还没有生成过',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12),
                );
              }
              return Column(
                children: tracks.map((t) {
                  return ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C5CE7), Color(0xFF0984E3)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.auto_awesome,
                          size: 20, color: Colors.white),
                    ),
                    title: Text(t.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${t.album} · ${(t.duration.inSeconds)} 秒',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow),
                      onPressed: () => ref
                          .read(playerControllerProvider)
                          .playQueue(tracks, tracks.indexOf(t)),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (e, _) => Text('加载失败：$e'),
          ),
        ],
      ),
    );
  }
}