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
import 'player_bar_tv.dart';
import 'artists_tv.dart';
import 'favourites_tv.dart';

// ── Indices sections ──────────────────────────────────────────────────────────
enum _TvSection { home, search, albums, artists, playlists, favourites, settings }

class HomeTvScreen extends StatefulWidget {
  const HomeTvScreen({super.key});

  @override
  State<HomeTvScreen> createState() => _HomeTvScreenState();
}

class _HomeTvScreenState extends State<HomeTvScreen> {
  _TvSection _section = _TvSection.home;
  bool _sidebarExpanded = true;

  // Home data
  List<Album>   _recentAlbums    = [];
  List<Song>    _recentHistory   = [];
  List<Artist>  _topArtists      = [];
  List<Playlist>_recentPlaylists = [];
  List<Song>    _favourites      = [];
  bool _loadingHome = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    try {
      final api = SwingApiService();
      final results = await Future.wait([
        api.getAlbums(limit: 20),
        api.getArtists(limit: 16),
        api.getPlaylists(),
        api.getFavourites(),
      ]);
      final player = context.read<PlayerProvider>();
      if (mounted) {
        setState(() {
          _recentAlbums    = results[0] as List<Album>;
          _topArtists      = results[1] as List<Artist>;
          _recentPlaylists = results[2] as List<Playlist>;
          _favourites      = results[3] as List<Song>;
          _recentHistory   = player.history.take(20).toList();
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
      case _TvSection.search:
        return const SearchTvScreen();
      case _TvSection.albums:
        return const AlbumsTvSection();
      case _TvSection.artists:
        return const ArtistsTvSection();
      case _TvSection.playlists:
        return const LibraryTvScreen();
      case _TvSection.favourites:
        return const FavouritesTvSection();
      case _TvSection.settings:
        return const SettingsTvScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          // Touche BACK TV (bouton retour télécommande) → home
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.goBack) {
            if (_section != _TvSection.home) {
              setState(() => _section = _TvSection.home);
            }
          }
        },
        child: Row(
          children: [
            // ── Sidebar ─────────────────────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
              width: _sidebarExpanded ? 230 : 72,
              color: Sp.surface,
              child: Column(
                children: [
                  // Logo / toggle
                  _SidebarHeader(
                    expanded: _sidebarExpanded,
                    onToggle: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                  ),
                  const SizedBox(height: 8),
                  // Nav items
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        TvNavItem(
                          icon: Icons.home_rounded,
                          label: 'Accueil',
                          active: _section == _TvSection.home,
                          expanded: _sidebarExpanded,
                          onTap: () => setState(() => _section = _TvSection.home),
                        ),
                        TvNavItem(
                          icon: Icons.search_rounded,
                          label: 'Recherche',
                          active: _section == _TvSection.search,
                          expanded: _sidebarExpanded,
                          onTap: () => setState(() => _section = _TvSection.search),
                        ),
                        const _SidebarDivider(),
                        TvNavItem(
                          icon: Icons.album_rounded,
                          label: 'Albums',
                          active: _section == _TvSection.albums,
                          expanded: _sidebarExpanded,
                          onTap: () => setState(() => _section = _TvSection.albums),
                        ),
                        TvNavItem(
                          icon: Icons.person_rounded,
                          label: 'Artistes',
                          active: _section == _TvSection.artists,
                          expanded: _sidebarExpanded,
                          onTap: () => setState(() => _section = _TvSection.artists),
                        ),
                        TvNavItem(
                          icon: Icons.queue_music_rounded,
                          label: 'Playlists',
                          active: _section == _TvSection.playlists,
                          expanded: _sidebarExpanded,
                          onTap: () => setState(() => _section = _TvSection.playlists),
                        ),
                        TvNavItem(
                          icon: Icons.favorite_rounded,
                          label: 'Favoris',
                          active: _section == _TvSection.favourites,
                          expanded: _sidebarExpanded,
                          onTap: () => setState(() => _section = _TvSection.favourites),
                        ),
                        const _SidebarDivider(),
                        TvNavItem(
                          icon: Icons.settings_rounded,
                          label: 'Paramètres',
                          active: _section == _TvSection.settings,
                          expanded: _sidebarExpanded,
                          onTap: () => setState(() => _section = _TvSection.settings),
                        ),
                      ],
                    ),
                  ),
                  // Mini-player en bas de la sidebar
                  const MiniPlayerTv(),
                  const SizedBox(height: 12),
                ],
              ),
            ),

            // ── Contenu ──────────────────────────────────────────────────────
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
}

// ── Header sidebar ────────────────────────────────────────────────────────────
class _SidebarHeader extends StatefulWidget {
  final bool expanded;
  final VoidCallback onToggle;
  const _SidebarHeader({required this.expanded, required this.onToggle});
  @override
  State<_SidebarHeader> createState() => _SidebarHeaderState();
}

class _SidebarHeaderState extends State<_SidebarHeader> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (_, event) => handleDpadSelect(event, widget.onToggle),
      child: GestureDetector(
        onTap: widget.onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.all(10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withOpacity(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: widget.expanded
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              if (widget.expanded) ...[
                ShaderMask(
                  shaderCallback: (r) => kGrad.createShader(r),
                  child: const Text(
                    'ASKARIA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
              Icon(
                widget.expanded
                    ? Icons.menu_open_rounded
                    : Icons.menu_rounded,
                color: _hasFocus ? Colors.white : Sp.textDim,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarDivider extends StatelessWidget {
  const _SidebarDivider();
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    height: 1,
    color: Colors.white10,
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// HomeContent — page d'accueil avec sections multiples
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
      padding: const EdgeInsets.fromLTRB(36, 32, 36, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Titre principal ────────────────────────────────────────────
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Bonne écoute 🎵',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _RefreshBtn(onTap: onRefresh),
            ],
          ),
          const SizedBox(height: 32),

          // ── Section : Écoutes récentes ─────────────────────────────────
          if (recentHistory.isNotEmpty) ...[
            TvSectionHeader(title: '▶  Récemment écouté'),
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentHistory.take(12).length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (ctx, i) {
                  final song = recentHistory[i];
                  return _RecentHistoryChip(song: song);
                },
              ),
            ),
            const SizedBox(height: 32),
          ],

          // ── Section : Albums récents ────────────────────────────────────
          if (recentAlbums.isNotEmpty) ...[
            TvSectionHeader(
              title: '💿  Albums récents',
              onSeeAll: () => onGoSection(_TvSection.albums),
            ),
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentAlbums.take(12).length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (ctx, i) => _HomeAlbumCard(album: recentAlbums[i]),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // ── Section : Artistes populaires ──────────────────────────────
          if (topArtists.isNotEmpty) ...[
            TvSectionHeader(
              title: '🎤  Artistes',
              onSeeAll: () => onGoSection(_TvSection.artists),
            ),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: topArtists.take(10).length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (ctx, i) => _HomeArtistCard(artist: topArtists[i]),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // ── Section : Playlists ────────────────────────────────────────
          if (recentPlaylists.isNotEmpty) ...[
            TvSectionHeader(
              title: '🎵  Playlists',
              onSeeAll: () => onGoSection(_TvSection.playlists),
            ),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentPlaylists.take(8).length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (ctx, i) => _HomePlaylistCard(playlist: recentPlaylists[i]),
              ),
            ),
            const SizedBox(height: 32),
          ],

          // ── Section : Favoris ──────────────────────────────────────────
          if (favourites.isNotEmpty) ...[
            TvSectionHeader(
              title: '❤️  Favoris',
              onSeeAll: () => onGoSection(_TvSection.favourites),
            ),
            Column(
              children: favourites.take(6).toList().asMap().entries.map((e) {
                final i = e.key;
                final song = e.value;
                final artwork = '${SwingApiService().baseUrl}/img/thumbnail/${song.image ?? song.hash}';
                final player = context.read<PlayerProvider>();
                final isPlaying = context.watch<PlayerProvider>().currentSong?.hash == song.hash;
                return TvListTile(
                  key: ValueKey(song.hash),
                  autoFocus: i == 0 && favourites.isNotEmpty,
                  leading: TvArtworkImage(url: artwork, size: 52),
                  title: song.title,
                  subtitle: '${song.artist} • ${song.album ?? ''}',
                  isActive: isPlaying,
                  trailing: Text(
                    song.formattedDuration,
                    style: const TextStyle(color: Sp.textDim, fontSize: 14),
                  ),
                  onTap: () => player.playSong(song, queue: favourites, index: i),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Chip écoutes récentes ─────────────────────────────────────────────────────
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
    final player = context.read<PlayerProvider>();
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (_, event) => handleDpadSelect(event, () => player.playSong(widget.song)),
      child: GestureDetector(
        onTap: () => player.playSong(widget.song),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 280,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withOpacity(0.12) : Sp.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              TvArtworkImage(url: artwork, size: 64, borderRadius: BorderRadius.circular(8)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(widget.song.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(widget.song.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Sp.textDim, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Carte album (accueil) ──────────────────────────────────────────────────────
class _HomeAlbumCard extends StatelessWidget {
  final Album album;
  const _HomeAlbumCard({required this.album});
  @override
  Widget build(BuildContext context) {
    final url = '${SwingApiService().baseUrl}/img/thumbnail/${album.image}';
    return TvFocusCard(
      width: 160,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => AlbumTvScreen(album: album),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TvArtworkImage(url: url, size: 160, borderRadius: BorderRadius.zero, fallbackIcon: Icons.album_rounded),
          Container(
            color: Sp.surface,
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Sp.textDim, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Carte artiste (accueil) ────────────────────────────────────────────────────
class _HomeArtistCard extends StatelessWidget {
  final Artist artist;
  const _HomeArtistCard({required this.artist});
  @override
  Widget build(BuildContext context) {
    final url = '${SwingApiService().baseUrl}/img/artist/small/${artist.hash}.webp';
    return TvFocusCard(
      width: 150,
      borderRadius: BorderRadius.circular(75),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ArtistDetailTvScreen(artist: artist),
      )),
      child: Column(
        children: [
          TvArtworkImage(
            url: url, size: 140,
            borderRadius: BorderRadius.circular(70),
            fallbackIcon: Icons.person_rounded,
          ),
          const SizedBox(height: 6),
          Text(artist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Carte playlist (accueil) ───────────────────────────────────────────────────
class _HomePlaylistCard extends StatelessWidget {
  final Playlist playlist;
  const _HomePlaylistCard({required this.playlist});
  @override
  Widget build(BuildContext context) {
    final url = playlist.imageHash != null
        ? '${SwingApiService().baseUrl}/img/playlist/${playlist.imageHash}.webp'
        : '';
    return TvFocusCard(
      width: 170,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => PlaylistDetailTvScreen(playlist: playlist),
      )),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          url.isNotEmpty
              ? TvArtworkImage(url: url, size: 170, borderRadius: BorderRadius.zero, fallbackIcon: Icons.queue_music_rounded)
              : Container(
                  width: 170, height: 130,
                  color: Sp.surface,
                  child: const Icon(Icons.queue_music_rounded, color: Colors.white24, size: 56),
                ),
          Container(
            color: Sp.surface,
            padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('${playlist.trackCount} titres',
                  style: const TextStyle(color: Sp.textDim, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Bouton refresh ────────────────────────────────────────────────────────────
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
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _hasFocus ? Colors.white : Colors.transparent),
        ),
        child: Icon(Icons.refresh_rounded, color: _hasFocus ? Colors.white : Sp.textDim, size: 24),
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
  List<Album> _albums = [];
  bool _loading = true;

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
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TvSectionHeader(title: '💿  Albums'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Sp.focus))
                : _albums.isEmpty
                    ? const Center(child: Text('Aucun album', style: TextStyle(color: Sp.textDim, fontSize: 18)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 20,
                          childAspectRatio: 0.78,
                        ),
                        itemCount: _albums.length,
                        itemBuilder: (ctx, i) => _AlbumGridCard(album: _albums[i], autoFocus: i == 0),
                      ),
          ),
        ],
      ),
    );
  }
}

class _AlbumGridCard extends StatelessWidget {
  final Album album;
  final bool autoFocus;
  const _AlbumGridCard({required this.album, this.autoFocus = false});
  @override
  Widget build(BuildContext context) {
    final url = '${SwingApiService().baseUrl}/img/thumbnail/${album.image}';
    return TvFocusCard(
      autoFocus: autoFocus,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AlbumTvScreen(album: album))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TvArtworkImage(url: url, size: double.infinity, borderRadius: BorderRadius.zero, fallbackIcon: Icons.album_rounded),
          ),
          Container(
            color: Sp.surface,
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(album.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Sp.textDim, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Stubs pour les écrans navigués depuis home (définis dans leurs fichiers)
// Les imports sont faits en haut — ces classes doivent exister
// ══════════════════════════════════════════════════════════════════════════════
