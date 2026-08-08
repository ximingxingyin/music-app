import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/duration_formatter.dart';
import '../../data/models/track.dart';
import '../../providers/player_provider.dart';

/// 全局底部迷你播放器。
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTrackProvider);
    final playing = ref.watch(isPlayingProvider);
    final pos = ref.watch(positionProvider);
    final controller = ref.watch(playerControllerProvider);

    return current.maybeWhen(
      data: (track) => track == null
          ? const SizedBox.shrink()
          : _MiniPlayerBody(
              track: track,
              position: pos.value ?? Duration.zero,
              isPlaying: playing.value ?? false,
              onTap: onTap,
              onPlayPause: () => (playing.value ?? false)
                  ? controller.pause()
                  : controller.play(),
              onNext: controller.next,
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MiniPlayerBody extends StatelessWidget {
  const _MiniPlayerBody({
    required this.track,
    required this.position,
    required this.isPlaying,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
  });

  final Track track;
  final Duration position;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1A1A24),
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _AlbumArt(url: track.albumArtUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${track.artist} · ${formatDurationShort(position)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 32,
                ),
                onPressed: onPlayPause,
              ),
              IconButton(
                icon: const Icon(Icons.skip_next_rounded, size: 28),
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.url});
  final String? url;

  bool _isLocalFile(String u) =>
      !u.startsWith('http') && !u.startsWith('content://');

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 44,
        child: url == null || url!.isEmpty
            ? Container(
                color: Colors.deepPurple.withValues(alpha: 0.4),
                child: const Icon(Icons.music_note, color: Colors.white70),
              )
            : (_isLocalFile(url!) && File(url!).existsSync()
                ? Image.file(
                    File(url!),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.deepPurple.withValues(alpha: 0.4),
                      child:
                          const Icon(Icons.music_note, color: Colors.white70),
                    ),
                  )
                : Image.network(
                    url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.deepPurple.withValues(alpha: 0.4),
                      child: const Icon(Icons.music_note,
                          color: Colors.white70),
                    ),
                  )),
      ),
    );
  }
}