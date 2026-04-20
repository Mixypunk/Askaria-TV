import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/services/api_service.dart';
import '../core/models/album.dart';
import '../core/models/song.dart';
import '../core/models/playlist.dart';
import '../core/providers/player_provider.dart';
import '../main.dart';

import 'widgets_tv.dart';
import 'settings_tv.dart';
import 'album_tv.dart';
import 'library_tv.dart';
import 'search_tv.dart';
import 'player_tv.dart';
import 'artists_tv.dart';
import 'favourites_tv.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Navigation
// ══════════════════════════════════════════════════════════════════════════════
enum _TvSection { home, search, albums, artists, playlists, favourites, settings }

const _navItems = [
  (_TvSection.home,       Icons.home_rounded,         'Accueil'),
  (_TvSection.search,     Icons.search_rounded,        'Recherche'),
  (_TvSection.albums,     Icons.album_rounded,         'Albums'),
  (_TvSection.artists,    Icons.person_rounded,        'Artistes'),
  (_TvSection.playlists,  Icons.queue_music_rounded,   'Playlists'),
  (_TvSection.favourites, Icons.favorite_rounded,      'Favoris'),
  (_TvSection.settings,   Icons.settings_rounded,      'Paramètres'),
];

// ══════════════════════════════════════════════════════════════════════════════
// HomeTvScreen — root screen
// ══════════════════════════════════════════════════════════════════════════════
class HomeTvScreen extends StatefulWidget {
  const HomeTvScreen({super.key});
  @override
  State<HomeTvScreen> createState() => _HomeTvScreenState();
}

class _HomeTvScreenState extends State<HomeTvScreen> {
  _TvSection _section = _TvSection.home;

  // Home data
  List<Album>    _recentAlbums    = [];
  List<Song>     _recentHistory   = [];
  List<Artist>   _topArtists      = [];
  List<Playlist> _recentPlaylists = [];
  List<Song>     _favourites      = [];
  bool _loadingHome = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => _loadingHome = true);
    final playerRef = context.read<PlayerProvider>(); // capture before async gap
    try {
      final api = SwingApiService();
      final results = await Future.wait([
        api.getAlbums(limit: 20),
        api.getArtists(limit: 12),
        api.getPlaylists(),
        api.getFavourites(),
      ]);
      if (mounted) {
        setState(() {
          _recentAlbums    = results[0] as List<Album>;
          _topArtists      = results[1] as List<Artist>;
          _recentPlaylists = results[2] as List<Playlist>;
          _favourites      = results[3] as List<Song>;
          _recentHistory   = playerRef.history.take(8).toList();
          _loadingHome     = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingHome = false);
    }
  }

  Widget _buildContent() {
    switch (_section) {
      case _TvSection.home:
        return _HomeContent(
          recentAlbums:    _recentAlbums,
          topArtists:      _topArtists,
          recentPlaylists: _recentPlaylists,
          favourites:      _favourites,
          recentHistory:   _recentHistory,
          loading:         _loadingHome,
          onRefresh:       _loadHomeData,
          onGoSection:     (s) => setState(() => _section = s),
        );
      case _TvSection.search:     return const SearchTvScreen();
      case _TvSection.albums:     return const AlbumsTvSection();
      case _TvSection.artists:    return const ArtistsTvSection();
      case _TvSection.playlists:  return const LibraryTvScreen();
      case _TvSection.favourites: return const FavouritesTvSection();
      case _TvSection.settings:   return const SettingsTvScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Sp.bg,
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.goBack &&
              _section != _TvSection.home) {
            setState(() => _section = _TvSection.home);
          }
        },
        child: Column(
          children: [
            // ── Main area (sidebar + content) ──────────────────────────────
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Sidebar — toujours 82px, icônes uniquement
                  _TvSidebar(
                    current: _section,
                    onSelect: (s) => setState(() => _section = s),
                  ),
                  // Content
                  Expanded(
                    child: ClipRect(child: _buildContent()),
                  ),
                ],
              ),
            ),
            // ── Mini player (barre fixe au bas de l'écran) ─────────────────
            const _BottomPlayerBar(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TvSidebar — icônes uniquement, label en tooltip sur focus
// ══════════════════════════════════════════════════════════════════════════════
class _TvSidebar extends StatelessWidget {
  final _TvSection current;
  final ValueChanged<_TvSection> onSelect;

  const _TvSidebar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      color: Sp.surface,
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ShaderMask(
              shaderCallback: (r) => kGrad.createShader(r),
              child: const Icon(Icons.tv_rounded, color: Colors.white, size: 36),
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 8),
          // Nav items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: _navItems.map((item) {
                return _SidebarItem(
                  icon: item.$2,
                  label: item.$3,
                  active: current == item.$1,
                  onSelect: () => onSelect(item.$1),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final VoidCallback onSelect;
  const _SidebarItem({
    required this.icon, required this.label,
    required this.active, required this.onSelect,
  });
  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}
class _SidebarItemState extends State<_SidebarItem> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? Sp.focus
        : (_hasFocus ? Colors.white : Sp.textDim);

    return Tooltip(
      message: widget.label,
      preferBelow: false,
      verticalOffset: 0,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A3A),
        borderRadius: BorderRadius.circular(8),
      ),
      textStyle: const TextStyle(color: Colors.white, fontSize: 14),
      child: Focus(
        onFocusChange: (f) => setState(() => _hasFocus = f),
        onKeyEvent: (_, event) => handleDpadSelect(event, widget.onSelect),
        child: GestureDetector(
          onTap: widget.onSelect,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: widget.active
                  ? Sp.focus.withOpacity(0.15)
                  : (_hasFocus ? Colors.white.withOpacity(0.08) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _hasFocus ? Colors.white : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Icon(widget.icon, color: color, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _BottomPlayerBar — barre de lecture fixe en bas (si musique en cours)
// ══════════════════════════════════════════════════════════════════════════════
class _BottomPlayerBar extends StatefulWidget {
  const _BottomPlayerBar();
  @override
  State<_BottomPlayerBar> createState() => _BottomPlayerBarState();
}
class _BottomPlayerBarState extends State<_BottomPlayerBar> {
  bool _hasFocus = false;

  void _openPlayer() {
    Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const PlayerTvScreen(),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song   = player.currentSong;
    if (song == null) return const SizedBox.shrink();

    final artwork = '${SwingApiService().baseUrl}/img/thumbnail/${song.image ?? song.hash}';

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (_, event) => handleDpadSelect(event, _openPlayer),
      child: GestureDetector(
        onTap: _openPlayer,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 72,
          decoration: BoxDecoration(
            color: _hasFocus ? const Color(0xFF252535) : const Color(0xFF1C1C28),
            border: Border(
              top: BorderSide(
                color: _hasFocus ? Sp.focus : Colors.white12,
                width: _hasFocus ? 2 : 1,
              ),
            ),
            boxShadow: _hasFocus
                ? [BoxShadow(color: Sp.focus.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -4))]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Artwork
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: TvArtworkImage(url: artwork, size: 48),
                ),
                const SizedBox(width: 16),
                // Titre + artiste
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Sp.textDim, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Contrôles rapides
                _BarControl(
                  icon: Icons.skip_previous_rounded,
                  onTap: player.previous,
                ),
                const SizedBox(width: 4),
                _BarControl(
                  icon: player.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  onTap: player.playPause,
                  size: 36,
                  accent: true,
                ),
                const SizedBox(width: 4),
                _BarControl(
                  icon: Icons.skip_next_rounded,
                  onTap: player.next,
                ),
                const SizedBox(width: 20),
                // Barre de progression verticale
                SizedBox(
                  width: 200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: player.progress.clamp(0.0, 1.0),
                          backgroundColor: Colors.white12,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _hasFocus ? Colors.white : Sp.focus),
                          minHeight: 3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Icône ouverture player
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: _hasFocus ? Colors.white : Sp.textDim,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BarControl extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool accent;
  const _BarControl({required this.icon, required this.onTap,
      this.size = 26, this.accent = false});
  @override State<_BarControl> createState() => _BarControlState();
}
class _BarControlState extends State<_BarControl> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (_, event) => handleDpadSelect(event, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: _hasFocus ? Colors.white
                : (widget.accent ? Sp.focus : Sp.textDim),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _HomeContent — page d'accueil
// ══════════════════════════════════════════════════════════════════════════════
class _HomeContent extends StatelessWidget {
  final List<Album>    recentAlbums;
  final List<Artist>   topArtists;
  final List<Playlist> recentPlaylists;
  final List<Song>     favourites;
  final List<Song>     recentHistory;
  final bool loading;
  final VoidCallback onRefresh;
  final void Function(_TvSection) onGoSection;

  const _HomeContent({
    required this.recentAlbums,
    required this.topArtists,
    required this.recentPlaylists,
    required this.favourites,
    required this.recentHistory,
    required this.loading,
    required this.onRefresh,
    required this.onGoSection,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: Sp.focus));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre + refresh
          Row(children: [
            const Expanded(
              child: Text('Bonne écoute 🎵',
                style: TextStyle(color: Colors.white, fontSize: 28,
                    fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            ),
            _RefreshBtn(onTap: onRefresh),
          ]),
          const SizedBox(height: 24),

          // ── Récemment écouté (petites chips 2 colonnes) ──────────────────
          if (recentHistory.isNotEmpty) ...[
            TvSectionHeader(title: '▶  Récemment écouté'),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 4.5,
              ),
              itemCount: recentHistory.length.clamp(0, 8),
              itemBuilder: (ctx, i) => _RecentHistoryChip(song: recentHistory[i]),
            ),
            const SizedBox(height: 28),
          ],

          // ── Albums (scrolling horizontal) ──────────────────────────────
          if (recentAlbums.isNotEmpty) ...[
            TvSectionHeader(
              title: '💿  Albums',
              onSeeAll: () => onGoSection(_TvSection.albums),
            ),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentAlbums.length.clamp(0, 12),
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (ctx, i) => _HomeAlbumCard(album: recentAlbums[i]),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Artistes (scrolling horizontal) ────────────────────────────
          if (topArtists.isNotEmpty) ...[
            TvSectionHeader(
              title: '🎤  Artistes',
              onSeeAll: () => onGoSection(_TvSection.artists),
            ),
            SizedBox(
              height: 160,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topArtists.length.clamp(0, 10),
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (ctx, i) => _HomeArtistCard(artist: topArtists[i]),
              ),
            ),
            const SizedBox(height: 28),
          ],

          // ── Playlists + Favoris côte à côte ────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (recentPlaylists.isNotEmpty)
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TvSectionHeader(
                      title: '🎵  Playlists',
                      onSeeAll: () => onGoSection(_TvSection.playlists),
                    ),
                    ...recentPlaylists.take(5).map((pl) => _HomePlaylistTile(playlist: pl)),
                  ],
                )),
              if (recentPlaylists.isNotEmpty && favourites.isNotEmpty)
                const SizedBox(width: 24),
              if (favourites.isNotEmpty)
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TvSectionHeader(
                      title: '❤️  Favoris',
                      onSeeAll: () => onGoSection(_TvSection.favourites),
                    ),
                    ...favourites.take(5).toList().asMap().entries.map((e) {
                      final song = e.value;
                      return _HomeFavTile(
                        song: song,
                        queue: favourites,
                        index: e.key,
                      );
                    }),
                  ],
                )),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Chip écoutes récentes ──────────────────────────────────────────────────────
class _RecentHistoryChip extends StatefulWidget {
  final Song song;
  const _RecentHistoryChip({required this.song});
  @override State<_RecentHistoryChip> createState() => _RecentHistoryChipState();
}
class _RecentHistoryChipState extends State<_RecentHistoryChip> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    final artwork = '${SwingApiService().baseUrl}/img/thumbnail/${widget.song.image ?? widget.song.hash}';
    final player  = context.read<PlayerProvider>();
    final isPlaying = context.watch<PlayerProvider>().currentSong?.hash == widget.song.hash;

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (_, event) => handleDpadSelect(event, () => player.playSong(widget.song)),
      child: GestureDetector(
        onTap: () => player.playSong(widget.song),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hasFocus
                ? Colors.white.withOpacity(0.12)
                : (isPlaying ? Sp.focus.withOpacity(0.15) : Sp.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hasFocus ? Colors.white : (isPlaying ? Sp.focus : Colors.transparent),
              width: 2,
            ),
          ),
          child: Row(children: [
            TvArtworkImage(url: artwork, size: 44, borderRadius: BorderRadius.circular(6)),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                Text(widget.song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Sp.textDim, fontSize: 11)),
              ],
            )),
            if (isPlaying)
              const Icon(Icons.graphic_eq_rounded, color: Sp.focus, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ── Carte album ────────────────────────────────────────────────────────────────
class _HomeAlbumCard extends StatelessWidget {
  final Album album;
  const _HomeAlbumCard({required this.album});
  @override
  Widget build(BuildContext context) {
    final url = '${SwingApiService().baseUrl}/img/thumbnail/${album.image}';
    return TvFocusCard(
      width: 150,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => AlbumTvScreen(album: album))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        TvArtworkImage(url: url, size: 150, borderRadius: BorderRadius.zero,
            fallbackIcon: Icons.album_rounded),
        Container(
          width: 150,
          color: Sp.surface,
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Sp.textDim, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

// ── Carte artiste ──────────────────────────────────────────────────────────────
class _HomeArtistCard extends StatelessWidget {
  final Artist artist;
  const _HomeArtistCard({required this.artist});
  @override
  Widget build(BuildContext context) {
    final url = '${SwingApiService().baseUrl}/img/artist/small/${artist.hash}.webp';
    return TvFocusCard(
      width: 120,
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ArtistDetailTvScreen(artist: artist))),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipOval(child: TvArtworkImage(url: url, size: 100, fallbackIcon: Icons.person_rounded)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(artist.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Tuile playlist (liste compacte) ───────────────────────────────────────────
class _HomePlaylistTile extends StatefulWidget {
  final Playlist playlist;
  const _HomePlaylistTile({required this.playlist});
  @override State<_HomePlaylistTile> createState() => _HomePlaylistTileState();
}
class _HomePlaylistTileState extends State<_HomePlaylistTile> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (_, event) => handleDpadSelect(event, () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => PlaylistDetailTvScreen(playlist: widget.playlist)))),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PlaylistDetailTvScreen(playlist: widget.playlist))),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withOpacity(0.1) : Sp.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hasFocus ? Colors.white : Colors.transparent, width: 2),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Sp.focus.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.queue_music_rounded, color: Sp.focus, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${widget.playlist.trackCount} titres',
                    style: const TextStyle(color: Sp.textDim, fontSize: 12)),
              ],
            )),
            Icon(Icons.chevron_right_rounded, color: _hasFocus ? Colors.white : Sp.textDim, size: 20),
          ]),
        ),
      ),
    );
  }
}

// ── Tuile favori ───────────────────────────────────────────────────────────────
class _HomeFavTile extends StatefulWidget {
  final Song song;
  final List<Song> queue;
  final int index;
  const _HomeFavTile({required this.song, required this.queue, required this.index});
  @override State<_HomeFavTile> createState() => _HomeFavTileState();
}
class _HomeFavTileState extends State<_HomeFavTile> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final isPlaying = context.watch<PlayerProvider>().currentSong?.hash == widget.song.hash;

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (_, event) => handleDpadSelect(event,
          () => player.playSong(widget.song, queue: widget.queue, index: widget.index)),
      child: GestureDetector(
        onTap: () => player.playSong(widget.song, queue: widget.queue, index: widget.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withOpacity(0.1)
                : (isPlaying ? Sp.focus.withOpacity(0.1) : Sp.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hasFocus ? Colors.white : (isPlaying ? Sp.focus : Colors.transparent),
              width: 2,
            ),
          ),
          child: Row(children: [
            if (isPlaying)
              const Icon(Icons.graphic_eq_rounded, color: Sp.focus, size: 20)
            else
              Text('${widget.index + 1}',
                  style: TextStyle(color: _hasFocus ? Colors.white : Sp.textDim,
                      fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: isPlaying ? Sp.focus : Colors.white,
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(widget.song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Sp.textDim, fontSize: 11)),
              ],
            )),
            Text(widget.song.formattedDuration,
                style: TextStyle(color: _hasFocus ? Colors.white : Sp.textDim, fontSize: 12)),
          ]),
        ),
      ),
    );
  }
}

// ── Bouton refresh ─────────────────────────────────────────────────────────────
class _RefreshBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _RefreshBtn({required this.onTap});
  @override State<_RefreshBtn> createState() => _RefreshBtnState();
}
class _RefreshBtnState extends State<_RefreshBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (f) => setState(() => _hasFocus = f),
    onKeyEvent: (_, event) => handleDpadSelect(event, widget.onTap),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _hasFocus ? Colors.white : Colors.transparent),
        ),
        child: Icon(Icons.refresh_rounded,
            color: _hasFocus ? Colors.white : Sp.textDim, size: 22),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// AlbumsTvSection — grille complète des albums
// ══════════════════════════════════════════════════════════════════════════════
class AlbumsTvSection extends StatefulWidget {
  const AlbumsTvSection({super.key});
  @override State<AlbumsTvSection> createState() => _AlbumsTvSectionState();
}
class _AlbumsTvSectionState extends State<AlbumsTvSection> {
  List<Album> _albums  = [];
  bool        _loading = true;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final res = await SwingApiService().getAlbums(limit: 200);
      if (mounted) setState(() { _albums = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const TvSectionHeader(title: '💿  Albums'),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: Sp.focus))
            : _albums.isEmpty
                ? const Center(child: Text('Aucun album', style: TextStyle(color: Sp.textDim, fontSize: 18)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5, crossAxisSpacing: 16,
                      mainAxisSpacing: 16, childAspectRatio: 0.78),
                    itemCount: _albums.length,
                    itemBuilder: (ctx, i) => _AlbumGridCard(album: _albums[i], autoFocus: i == 0),
                  )),
      ]),
    );
  }
}
class _AlbumGridCard extends StatelessWidget {
  final Album album;
  final bool  autoFocus;
  const _AlbumGridCard({required this.album, this.autoFocus = false});
  @override
  Widget build(BuildContext context) {
    final url = '${SwingApiService().baseUrl}/img/thumbnail/${album.image}';
    return TvFocusCard(
      autoFocus: autoFocus,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumTvScreen(album: album))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: TvArtworkImage(url: url, size: double.infinity,
            borderRadius: BorderRadius.zero, fallbackIcon: Icons.album_rounded)),
        Container(
          color: Sp.surface,
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Sp.textDim, fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}
