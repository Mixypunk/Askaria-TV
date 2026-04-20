import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/api_service.dart';
import '../core/models/album.dart';
import '../core/models/song.dart';
import '../core/providers/player_provider.dart';
import '../main.dart';
import 'widgets_tv.dart';
import 'album_tv.dart';

// ══════════════════════════════════════════════════════════════════════════════
// ArtistsTvSection — grille de tous les artistes
// ══════════════════════════════════════════════════════════════════════════════
class ArtistsTvSection extends StatefulWidget {
  const ArtistsTvSection({super.key});
  @override State<ArtistsTvSection> createState() => _ArtistsTvSectionState();
}

class _ArtistsTvSectionState extends State<ArtistsTvSection> {
  List<Artist> _artists = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await SwingApiService().getArtists(limit: 200);
      if (mounted) setState(() { _artists = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TvSectionHeader(title: '🎤  Artistes'),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Sp.focus))
                : _artists.isEmpty
                    ? const Center(child: Text('Aucun artiste', style: TextStyle(color: Sp.textDim, fontSize: 18)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 6,
                          crossAxisSpacing: 20,
                          mainAxisSpacing: 24,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: _artists.length,
                        itemBuilder: (ctx, i) => _ArtistGridCard(
                          artist: _artists[i],
                          autoFocus: i == 0,
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ArtistGridCard extends StatelessWidget {
  final Artist artist;
  final bool autoFocus;
  const _ArtistGridCard({required this.artist, this.autoFocus = false});
  @override
  Widget build(BuildContext context) {
    final url = '${SwingApiService().baseUrl}/img/artist/small/${artist.hash}.webp';
    return TvFocusCard(
      autoFocus: autoFocus,
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ArtistDetailTvScreen(artist: artist),
      )),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 10),
          TvArtworkImage(
            url: url,
            size: 100,
            borderRadius: BorderRadius.circular(50),
            fallbackIcon: Icons.person_rounded,
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              artist.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${artist.albumCount} album${artist.albumCount != 1 ? 's' : ''}',
            style: const TextStyle(color: Sp.textDim, fontSize: 12),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ArtistDetailTvScreen — page détail d'un artiste
// ══════════════════════════════════════════════════════════════════════════════
class ArtistDetailTvScreen extends StatefulWidget {
  final Artist artist;
  const ArtistDetailTvScreen({super.key, required this.artist});
  @override State<ArtistDetailTvScreen> createState() => _ArtistDetailTvScreenState();
}

class _ArtistDetailTvScreenState extends State<ArtistDetailTvScreen> {
  List<Song>  _tracks = [];
  List<Album> _albums = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final api = SwingApiService();
      final results = await Future.wait([
        api.getArtistTracks(widget.artist.hash),
        api.getArtistAlbums(widget.artist.hash),
      ]);
      if (mounted) setState(() {
        _tracks = results[0] as List<Song>;
        _albums = results[1] as List<Album>;
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final artUrl = '${SwingApiService().baseUrl}/img/artist/small/${widget.artist.hash}.webp';

    return Scaffold(
      backgroundColor: Sp.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Sp.focus))
          : CustomScrollView(
              slivers: [
                // ── Header artististe ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Sp.surface, Sp.bg],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(48, 48, 48, 32),
                    child: Row(
                      children: [
                        TvFocusCard(
                          width: 160,
                          height: 160,
                          borderRadius: BorderRadius.circular(80),
                          onTap: () => Navigator.pop(context),
                          child: TvArtworkImage(
                            url: artUrl,
                            size: 160,
                            borderRadius: BorderRadius.circular(80),
                            fallbackIcon: Icons.person_rounded,
                          ),
                        ),
                        const SizedBox(width: 36),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('ARTISTE', style: TextStyle(color: Sp.textDim, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(widget.artist.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 10),
                              Text(
                                '${_tracks.length} titres • ${_albums.length} albums',
                                style: const TextStyle(color: Sp.textDim, fontSize: 16),
                              ),
                              const SizedBox(height: 20),
                              if (_tracks.isNotEmpty)
                                _TvPlayBtn(
                                  onTap: () => player.playSong(_tracks.first, queue: _tracks, index: 0),
                                ),
                            ],
                          ),
                        ),
                        // Back
                        _TvBackBtn(onTap: () => Navigator.pop(context)),
                      ],
                    ),
                  ),
                ),

                // ── Albums ──────────────────────────────────────────────────
                if (_albums.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(48, 0, 48, 16),
                      child: TvSectionHeader(title: 'Albums'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        scrollDirection: Axis.horizontal,
                        itemCount: _albums.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 16),
                        itemBuilder: (ctx, i) {
                          final url = '${SwingApiService().baseUrl}/img/thumbnail/${_albums[i].image}';
                          return TvFocusCard(
                            width: 160,
                            onTap: () => Navigator.push(ctx, MaterialPageRoute(
                              builder: (_) => AlbumTvScreen(album: _albums[i]),
                            )),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TvArtworkImage(url: url, size: 160, borderRadius: BorderRadius.zero, fallbackIcon: Icons.album_rounded),
                                Container(
                                  color: Sp.surface,
                                  padding: const EdgeInsets.all(8),
                                  child: Text(_albums[i].title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],

                // ── Titres ──────────────────────────────────────────────────
                if (_tracks.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(48, 24, 48, 16),
                      child: TvSectionHeader(title: 'Titres populaires'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(48, 0, 48, 80),
                    sliver: SliverList.builder(
                      itemCount: _tracks.length,
                      itemBuilder: (ctx, i) {
                        final song = _tracks[i];
                        final isPlaying = context.watch<PlayerProvider>().currentSong?.hash == song.hash;
                        final artUrl = '${SwingApiService().baseUrl}/img/thumbnail/${song.image ?? song.hash}';
                        return TvListTile(
                          key: ValueKey(song.hash),
                          leading: TvArtworkImage(url: artUrl, size: 52),
                          title: song.title,
                          subtitle: song.album ?? '',
                          isActive: isPlaying,
                          trailing: Text(song.formattedDuration, style: const TextStyle(color: Sp.textDim, fontSize: 14)),
                          onTap: () => player.playSong(song, queue: _tracks, index: i),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

// Bouton Lecture TV
class _TvPlayBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _TvPlayBtn({required this.onTap});
  @override State<_TvPlayBtn> createState() => _TvPlayBtnState();
}
class _TvPlayBtnState extends State<_TvPlayBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white : Sp.focus,
            borderRadius: BorderRadius.circular(50),
            boxShadow: _hasFocus ? [BoxShadow(color: Sp.focus.withOpacity(0.5), blurRadius: 20)] : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_arrow_rounded, color: _hasFocus ? Sp.bg : Colors.white, size: 24),
            const SizedBox(width: 8),
            Text('Lecture', style: TextStyle(color: _hasFocus ? Sp.bg : Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// Bouton Retour TV
class _TvBackBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _TvBackBtn({required this.onTap});
  @override State<_TvBackBtn> createState() => _TvBackBtnState();
}
class _TvBackBtnState extends State<_TvBackBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hasFocus ? Colors.white : Colors.white12),
          ),
          child: Icon(Icons.arrow_back_rounded, color: _hasFocus ? Colors.white : Sp.textDim, size: 26),
        ),
      ),
    );
  }
}
