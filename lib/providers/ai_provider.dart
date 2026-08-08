import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/database/database.dart';
import '../data/models/track.dart';
import '../services/ai_music_generator.dart';
import 'library_provider.dart';

final aiGeneratorProvider = Provider<AiMusicGenerator>((_) => AiMusicGenerator());

/// AI 生成状态（生成中 + 已生成曲目）
class AiGenerationState {
  final bool isGenerating;
  final String? lastGeneratedPath;
  final String? error;

  const AiGenerationState({
    this.isGenerating = false,
    this.lastGeneratedPath,
    this.error,
  });

  AiGenerationState copyWith({
    bool? isGenerating,
    String? lastGeneratedPath,
    String? error,
  }) {
    return AiGenerationState(
      isGenerating: isGenerating ?? this.isGenerating,
      lastGeneratedPath: lastGeneratedPath ?? this.lastGeneratedPath,
      error: error,
    );
  }
}

class AiGenerationNotifier extends StateNotifier<AiGenerationState> {
  AiGenerationNotifier(this.ref) : super(const AiGenerationState());
  final Ref ref;

  /// 生成并保存到本地曲库。
  /// 返回 Track 对象（已落库）。
  Future<Track?> generate({
    required String prompt,
    required AiGenre genre,
    required int durationSeconds,
  }) async {
    state = state.copyWith(isGenerating: true, error: null);
    try {
      final gen = ref.read(aiGeneratorProvider);
      final path = await gen.generate(
        prompt: prompt,
        genre: genre,
        durationSeconds: durationSeconds,
      );
      // 写入 tracks 表
      final db = ref.read(databaseProvider);
      final id = 'ai:$genre:${DateTime.now().millisecondsSinceEpoch}';
      await db.upsertTrack(TracksCompanion(
        id: Value(id),
        title: Value(prompt.isEmpty ? 'AI 生成 - ${genre.label}' : prompt),
        artist: Value('AI 创作'),
        album: Value(genre.label),
        durationMs: Value(durationSeconds * 1000),
        uri: Value(path),
        albumArtUri: Value(null),
      ));
      // 构造 Track 返回
      final t = Track(
        id: id,
        title: prompt.isEmpty ? 'AI 生成 - ${genre.label}' : prompt,
        artist: 'AI 创作',
        album: genre.label,
        duration: Duration(seconds: durationSeconds),
        uri: path,
        source: TrackSource.ai,
      );
      // 失效曲目列表（让用户能在"曲目"页找到）
      ref.invalidate(tracksProvider);
      ref.invalidate(albumsProvider);
      ref.invalidate(artistsProvider);
      state = AiGenerationState(
        isGenerating: false,
        lastGeneratedPath: path,
      );
      return t;
    } catch (e) {
      state = state.copyWith(isGenerating: false, error: e.toString());
      return null;
    }
  }
}

final aiGenerationProvider =
    StateNotifierProvider<AiGenerationNotifier, AiGenerationState>((ref) {
  return AiGenerationNotifier(ref);
});

/// AI 生成的曲目列表
final aiGeneratedTracksProvider =
    FutureProvider.autoDispose<List<Track>>((ref) async {
  final db = ref.watch(databaseProvider);
  final rows = await db.customSelect(
    "SELECT * FROM tracks WHERE id LIKE 'ai:%' ORDER BY rowid DESC LIMIT 50",
    readsFrom: {tracks},
  ).get();
  return rows.map((r) {
    return Track(
      id: r.read<String>('id'),
      title: r.read<String>('title'),
      artist: r.read<String>('artist'),
      album: r.read<String>('album'),
      duration: Duration(milliseconds: r.read<int>('duration_ms')),
      uri: r.read<String>('uri'),
      source: TrackSource.ai,
    );
  }).toList();
});