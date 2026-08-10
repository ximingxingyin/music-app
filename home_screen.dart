import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/exclusion_provider.dart';
import '../../providers/library_provider.dart';
import '../../providers/player_provider.dart';
import '../../services/music_scanner_service.dart';
import '../widgets/mini_player.dart';
import '../widgets/track_tile.dart';
import 'playlist_screen.dart';

/// 主页：底部导航 + 迷你播放器。
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _index = 0;

  static const _pages = <Widget>[
    _LibraryTab(),
    _AlbumsTab(),
    _ArtistsTab(),
    _MineTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayer(onTap: () => context.push('/now-playing')),
          BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.library_music_outlined),
                activeIcon: Icon(Icons.library_music),
                label: '曲目',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.album_outlined),
                activeIcon: Icon(Icons.album),
                label: '专辑',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: '艺术家',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle_outlined),
                activeIcon: Icon(Icons.account_circle),
                label: '我的',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────── Tab 1: 曲目（搜索移到全局） ──────────

class _LibraryTab extends ConsumerStatefulWidget {
  const _LibraryTab();

  @override
  ConsumerState<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<_LibraryTab> {
  Future<void> _rescan() async {
    final scanner = ref.read(scannerProvider);
    if (!mounted) return;

    bool cancelled = false;
    // 弹出进度对话框
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ScanProgressDialog(
        onCancel: () => cancelled = true,
      ),
    );

    // 加载黑名单
    scanner.onExclusionsLoaded = () async {
      return ref.read(excludedFoldersProvider).maybeWhen(
            data: (s) => s,
            orElse: () => <String>{},
          ) ??
          <String>{};
    };

    int n = 0;
    try {
      n = await scanner.scanAll(
        onProgress: (p) {
          if (cancelled) return;
          ref.read(scanProgressProvider.notifier).state = p;
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('扫描失败：$e')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    ref.invalidate(tracksProvider);
    ref.invalidate(albumsProvider);
    ref.invalidate(artistsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('扫描完成，新增/更新 $n 首')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tracksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的音乐'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '全局搜索',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '扫描本地音乐',
            onPressed: _rescan,
          ),
        ],
      ),
      body: tracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.library_music,
                      size: 64, color: Colors.white24),
                  const SizedBox(height: 16),
                  const Text('本地暂无音乐',
                      style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  const Text('点击右上角刷新扫描',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: tracks.length,
            itemBuilder: (_, i) {
              final t = tracks[i];
              return TrackTile(
                track: t,
                onTap: () => ref
                    .read(playerControllerProvider)
                    .playQueue(tracks, i),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

// ────────── Tab 2: 专辑 ──────────

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('专辑')),
      body: albumsAsync.when(
        data: (albums) => GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.78,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: albums.length,
          itemBuilder: (_, i) {
            final a = albums[i];
            return InkWell(
              onTap: () => context.push(
                '/album/${Uri.encodeComponent(a.album)}/${Uri.encodeComponent(a.artist)}',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: a.coverPath == null
                          ? Container(
                              color:
                                  Colors.deepPurple.withOpacity(0.3),
                              child: const Icon(Icons.album,
                                  size: 56, color: Colors.white70),
                            )
                          : Image.file(
                              File(a.coverPath!),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Colors.deepPurple
                                    .withOpacity(0.3),
                                child: const Icon(Icons.album,
                                    size: 56, color: Colors.white70),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(a.album,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text('${a.artist} · ${a.count}首',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white60)),
                ],
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

// ────────── Tab 3: 艺术家 ──────────

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistsAsync = ref.watch(artistsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('艺术家')),
      body: artistsAsync.when(
        data: (artists) => ListView.builder(
          itemCount: artists.length,
          itemBuilder: (_, i) {
            final a = artists[i];
            return ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: a.coverPath == null
                      ? CircleAvatar(
                          backgroundColor:
                              Colors.teal.withOpacity(0.4),
                          child: Text(a.artist.isNotEmpty ? a.artist[0] : '?'),
                        )
                      : Image.file(
                          File(a.coverPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => CircleAvatar(
                            backgroundColor:
                                Colors.teal.withOpacity(0.4),
                            child:
                                Text(a.artist.isNotEmpty ? a.artist[0] : '?'),
                          ),
                        ),
                ),
              ),
              title: Text(a.artist,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${a.count} 首曲目',
                  style:
                      const TextStyle(fontSize: 12, color: Colors.white60)),
              onTap: () => context.push(
                '/artist/${Uri.encodeComponent(a.artist)}',
              ),
            );
          },
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

// ────────── Tab 4: 我的（收藏 + 歌单 + 电台） ──────────

class _MineTab extends StatelessWidget {
  const _MineTab();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的'),
          actions: [
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'AI 智能场景',
              onPressed: () => context.push('/ai-scene'),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: '设置',
              onPressed: () => context.push('/settings'),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: '收藏'),
              Tab(text: '歌单'),
              Tab(text: 'AI'),
              Tab(text: '电台'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _FavoritesTab(),
            _PlaylistsTab(),
            _AiShortcutTab(),
            _OnlineTab(),
          ],
        ),
      ),
    );
  }
}

/// AI 智能场景的快捷入口 Tab
class _AiShortcutTab extends StatelessWidget {
  const _AiShortcutTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C5CE7), Color(0xFF0984E3)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
              const SizedBox(height: 12),
              const Text('AI 智能场景',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '通勤 / 运动 / 睡前 / 专注 / 休闲\n'
                '一键匹配本地音乐库最适合的曲目',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => context.push('/ai-scene'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                  ),
                  child: const Text('打开 AI 场景'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE17055), Color(0xFFD63031)],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.queue_music, color: Colors.white, size: 32),
              const SizedBox(height: 12),
              const Text('AI 创作',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                '输入一段描述\n'
                '生成属于你自己的原创音乐',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.9), fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => context.push('/ai-compose'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Color(0xFFD63031),
                  ),
                  child: const Text('开始创作'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    return Scaffold(
      body: favs.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return Column(
              children: [
                _HistoryEntry(),
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.favorite_border,
                            size: 64, color: Colors.white24),
                        SizedBox(height: 16),
                        Text('还没有收藏',
                            style: TextStyle(color: Colors.white70)),
                        SizedBox(height: 8),
                        Text('点击曲目标星可加入收藏',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
          return ListView(
            children: [
              _HistoryEntry(),
              ...tracks.map((t) => TrackTile(
                    track: t,
                    onTap: () => ref
                        .read(playerControllerProvider)
                        .playQueue(tracks, tracks.indexOf(t)),
                  )),
              const SizedBox(height: 32),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
    );
  }
}

/// 播放历史入口卡片（放在收藏 Tab 顶部）
class _HistoryEntry extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: InkWell(
        onTap: () => context.push('/history'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.withOpacity(0.4),
                Colors.blue.withOpacity(0.3),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.history, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('播放历史',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('查看最近听过的歌曲',
                        style: TextStyle(
                            fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(playlistsProvider);
    return Scaffold(
      body: playlists.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.queue_music, size: 64, color: Colors.white24),
                  SizedBox(height: 16),
                  Text('还没有歌单', style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 8),
                  Text('点击右下角"+ "创建',
                      style: TextStyle(color: Colors.white38, fontSize: 12)),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              final p = list[i];
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.playlist_play,
                      color: Colors.white),
                ),
                title: Text(p.name),
                subtitle: Text('${p.trackCount} 首曲目',
                    style: const TextStyle(fontSize: 12, color: Colors.white60)),
                onTap: () =>
                    context.push('/playlist/${p.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败：$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreatePlaylistDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreatePlaylistDialog(
      BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('新建歌单'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: '歌单名称'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('创建'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(libraryActionsProvider).createPlaylist(name);
    }
  }
}

// 在线电台子 Tab
class _OnlineTab extends ConsumerWidget {
  const _OnlineTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('合规开放资源',
            style: TextStyle(fontSize: 14, color: Colors.white70)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A24),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: const Text(
            '本模块接入 Jamendo / Audius / Radio Browser / Internet Archive '
            '等开放资源。无中文主流版权，提供独立音乐发现、'
            '中文网络电台与公版音乐库。商用扩展需另行接入'
            '咪咕/网易云/QQ 音乐开放平台。',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.radio),
          label: const Text('中文网络电台（直播）'),
          onPressed: () => context.push('/online/radio'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.library_music),
          label: const Text('公版音乐库（Internet Archive）'),
          onPressed: () => context.push('/online/archive'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.public),
          label: const Text('Jamendo 热门'),
          onPressed: () => context.push('/online/jamendo'),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          icon: const Icon(Icons.graphic_eq),
          label: const Text('Audius 热门'),
          onPressed: () => context.push('/online/audius'),
        ),
      ],
    );
  }
}
/// 扫描进度对话框
class _ScanProgressDialog extends ConsumerWidget {
  const _ScanProgressDialog({required this.onCancel});
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(scanProgressProvider);
    return AlertDialog(
      title: const Text('扫描中'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            p.currentStep.isEmpty ? '准备' : p.currentStep,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          if (p.total > 0)
            LinearProgressIndicator(value: p.ratio)
          else
            const LinearProgressIndicator(),
          const SizedBox(height: 8),
          Text(
            p.total > 0 ? '${p.processed} / ${p.total}' : '准备中...',
            style: const TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            onCancel();
            Navigator.pop(context);
          },
          child: const Text('取消'),
        ),
      ],
    );
  }
}
