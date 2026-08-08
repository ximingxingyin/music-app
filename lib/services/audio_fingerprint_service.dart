import 'dart:async';
import 'dart:math';

import '../data/models/track.dart';

/// 听歌场景。
enum Scene {
  commute('通勤', '地铁/公交上的轻快陪伴'),
  workout('运动', '节奏密集、推动力强'),
  sleep('睡前', '舒缓、低能量'),
  focus('专注', '白噪、纯音乐、低干扰'),
  chill('休闲', '氛围轻松、随时可听');

  final String label;
  final String desc;
  const Scene(this.label, this.desc);

  static Scene fromName(String? n) {
    return Scene.values.firstWhere(
      (e) => e.name == n,
      orElse: () => Scene.chill,
    );
  }
}

/// 智能场景分类 / 智能歌单。
///
/// v0.4 实装启发式分类（标题关键词 + 时长 + 流派）：
///   - 不需要 ML 模型，0 依赖，即装即用
///   - 准确率有限（60-70%），但作为 MVP 够用
/// v0.5+ 升级方向：
///   - 集成 ONNX 模型做 BPM / 情绪检测
///   - 接入 MusicBrainz / Spotify Audio Features API
class SmartClassifierService {
  /// 关键词词典（中文 / 英文）。
  static const _keywords = <Scene, List<String>>{
    Scene.commute: [
      '流行', 'pop', '轻', '民谣', 'folk', '独立', 'indie', 'city', '城市',
    ],
    Scene.workout: [
      'rock', 'rap', '电子', 'edm', 'house', 'techno', '鼓', '快',
      'pump', 'beat', '运动', '跑步', '燃', '热血',
    ],
    Scene.sleep: [
      '钢琴', '纯音乐', '轻音乐', 'sleep', 'ambient', 'lullaby', '摇篮',
      '冥想', 'meditation', '古筝', '箫', '轻',
    ],
    Scene.focus: [
      '古典', 'classical', 'ambient', '白噪声', 'lofi', 'study', '学习',
      '专注', '钢琴', 'piano',
    ],
    Scene.chill: [
      'jazz', 'blues', 'bossa', 'chill', 'lofi', '民谣', '轻',
    ],
  };

  /// 每个场景的特征（时长偏好，单位秒）。
  static const _durationPrefs = <Scene, (int min, int max)>{
    Scene.commute: (90, 300),
    Scene.workout: (120, 360),
    Scene.sleep: (60, 600),
    Scene.focus: (60, 900),
    Scene.chill: (90, 420),
  };

  /// 为指定场景挑选最匹配的曲目，按相关性评分排序。
  Future<List<Track>> pickByScene({
    required List<Track> library,
    required Scene scene,
    int limit = 30,
  }) async {
    if (library.isEmpty) return const [];

    final kw = _keywords[scene] ?? const [];
    final (minDur, maxDur) = _durationPrefs[scene] ?? (60, 600);

    // 给每首歌打分
    final scored = <(Track, double)>[];
    for (final t in library) {
      double score = 0;
      final hay =
          '${t.title} ${t.artist} ${t.album} ${t.genre ?? ''}'.toLowerCase();
      for (final k in kw) {
        if (hay.contains(k.toLowerCase())) score += 1;
      }
      final dur = t.duration.inSeconds;
      if (dur > 0) {
        if (dur >= minDur && dur <= maxDur) score += 0.5;
        // 时长差异惩罚
        if (dur > maxDur * 1.5 || dur < minDur * 0.5) score -= 0.5;
      }
      // 收藏加权
      // （需要外部传入，因为这里没有 DB access）
      scored.add((t, score));
    }
    // 按分数降序
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    // 取分数 >= 0 的前 N 首
    final result = <Track>[];
    for (final (track, score) in scored) {
      if (result.length >= limit) break;
      if (score > 0) result.add(track);
    }

    // 如果匹配太少（< 5 首），降级：返回评分 >= -0.5 的
    if (result.length < 5) {
      result.clear();
      for (final (track, score) in scored) {
        if (result.length >= limit) break;
        if (score > -0.5) result.add(track);
      }
    }

    return result;
  }

  /// 自然语言 → 场景。
  /// 输入："跑步时听的歌" / "睡前助眠" / "通勤地铁"
  /// 输出：匹配的 Scene（找不到返回 null）
  Scene? sceneFromPrompt(String prompt) {
    final p = prompt.toLowerCase();
    if (p.contains('跑步') ||
        p.contains('运动') ||
        p.contains('workout') ||
        p.contains('健身')) {
      return Scene.workout;
    }
    if (p.contains('睡') ||
        p.contains('助眠') ||
        p.contains('冥想') ||
        p.contains('sleep') ||
        p.contains('meditation')) {
      return Scene.sleep;
    }
    if (p.contains('专注') ||
        p.contains('学习') ||
        p.contains('工作') ||
        p.contains('study') ||
        p.contains('focus')) {
      return Scene.focus;
    }
    if (p.contains('通勤') ||
        p.contains('地铁') ||
        p.contains('公交') ||
        p.contains('commute')) {
      return Scene.commute;
    }
    if (p.contains('休闲') ||
        p.contains('咖啡') ||
        p.contains('chill') ||
        p.contains('放松')) {
      return Scene.chill;
    }
    return null;
  }

  /// 根据自然语言 prompt 生成歌单。
  /// 流程：识别场景 → 调用 pickByScene
  Future<List<Track>> generateFromPrompt({
    required String prompt,
    required List<Track> library,
  }) async {
    final scene = sceneFromPrompt(prompt);
    if (scene == null) {
      // 兜底：返回随机 20 首
      library.shuffle(Random(prompt.hashCode));
      return library.take(20).toList();
    }
    return pickByScene(library: library, scene: scene);
  }
}