import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/models/playlist.dart';
import '../core/models/song.dart';
import '../core/services/api_service.dart';
import '../core/providers/player_provider.dart';
import '../main.dart';
import 'widgets_tv.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LibraryTvScreen — playlists (Mes playlists + Partagées en tabs)
// ══════════════════════════════════════════════════════════════════════════════
class LibraryTvScreen extends StatefulWidget {
  const LibraryTvScreen({super.key});
  @override State<LibraryTvScreen> createState() => _LibraryTvScreenState();
}

class _LibraryTvScreenState extends State<LibraryTvScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<Playlist> _mine   = [];
  List<Playlist> _public = [];
  bool _loadingMine   = true;
  bool _loadingPublic = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.index == 1 && _public.isEmpty && !_loadingPublic) _loadPublic();
    });
    _loadMine();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _loadMine() async {
    try {
      final res = await SwingApiService().getPlaylists();
      if (mounted) setState(() { _mine = res; _loadingMine = false; });
    } catch (_) { if (mounted) setState(() => _loadingMine = false); }
  }

  Future<void> _loadPublic() async {
    setState(() => _loadingPublic = true);
    try {
      final res = await SwingApiService().getPublicPlaylists();
      if (mounted) setState(() { _public = res; _loadingPublic = false; });
    } catch (_) { if (mounted) setState(() => _loadingPublic = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Entête ────────────────────────────────────────────────────────
          Row(
            children: [
              const Text(
                '🎵  Playlists',
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const Spacer(),
              _TvTabBtn(label: 'Mes playlists', active: _tab.index == 0, onTap: () => setState(() => _tab.index = 0)),
              const SizedBox(width: 12),
              _TvTabBtn(label: 'Partagées',     active: _tab.index == 1, onTap: () {
                setState(() => _tab.index = 1);
                if (_public.isEmpty && !_loadingPublic) _loadPublic();
              }),
            ],
          ),
          const SizedBox(height: 24),

          // ── Contenu par tab ───────────────────────────────────────────────
          Expanded(
            child: _tab.index == 0
                ? _PlaylistGrid(
                    playlists: _mine,
                    loading: _loadingMine,
                    emptyIcon: Icons.queue_music_rounded,
                    emptyMsg: 'Aucune playlist',
                    onRefresh: _loadMine,
                    onTap: (pl) => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PlaylistDetailTvScreen(playlist: pl),
                    )).then((_) => _loadMine()),
                  )
                : _PlaylistGrid(
                    playlists: _public,
                    loading: _loadingPublic,
                    emptyIcon: Icons.public_off_rounded,
                    emptyMsg: 'Aucune playlist partagée',
                    onRefresh: _loadPublic,
                    onTap: (pl) => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => PlaylistDetailTvScreen(playlist: pl, readOnly: true),
                    )),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Grille de playlists ───────────────────────────────────────────────────────
class _PlaylistGrid extends StatelessWidget {
  final List<Playlist>      playlists;
  final bool                loading;
  final IconData            emptyIcon;
  final String              emptyMsg;
  final Future<void> Function() onRefresh;
  final void Function(Playlist) onTap;
  const _PlaylistGrid({
    required this.playlists,
    required this.loading,
    required this.emptyIcon,
    required this.emptyMsg,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Sp.focus));
    if (playlists.isEmpty) return Center(child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(emptyIcon, color: Colors.white12, size: 72),
        const SizedBox(height: 16),
        Text(emptyMsg, style: const TextStyle(color: Sp.textDim, fontSize: 18)),
      ],
    ));

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.78,
      ),
      itemCount: playlists.length,
      itemBuilder: (ctx, i) => _PlaylistGridCard(
        playlist: playlists[i],
        autoFocus: i == 0,
        onTap: () => onTap(playlists[i]),
      ),
    );
  }
}

class _PlaylistGridCard extends StatelessWidget {
  final Playlist playlist;
  final bool autoFocus;
  final VoidCallback onTap;
  const _PlaylistGridCard({required this.playlist, this.autoFocus = false, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final url = playlist.imageHash != null
        ? '${SwingApiService().baseUrl}/img/playlist/${playlist.imageHash}.webp'
        : '';
    return TvFocusCard(
      autoFocus: autoFocus,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: url.isNotEmpty
                ? TvArtworkImage(url: url, size: double.infinity, borderRadius: BorderRadius.zero, fallbackIcon: Icons.queue_music_rounded)
                : Container(color: Sp.surface, child: const Icon(Icons.queue_music_rounded, color: Colors.white24, size: 64)),
          ),
          Container(
            color: Sp.surface,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(playlist.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
                if (playlist.isPublic)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.public_rounded, color: Colors.blueAccent, size: 12),
                  ),
              ]),
              const SizedBox(height: 3),
              Text('${playlist.trackCount} titre${playlist.trackCount != 1 ? 's' : ''}',
                  style: const TextStyle(color: Sp.textDim, fontSize: 12)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ── Tab button style TV ───────────────────────────────────────────────────────
class _TvTabBtn extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _TvTabBtn({required this.label, required this.active, required this.onTap});
  @override State<_TvTabBtn> createState() => _TvTabBtnState();
}
class _TvTabBtnState extends State<_TvTabBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: widget.active ? Sp.focus.withOpacity(0.2)
                : (_hasFocus ? Colors.white.withOpacity(0.08) : Colors.transparent),
            borderRadius: BorderRadius.circular(50),
            border: Border.all(
              color: widget.active ? Sp.focus
                  : (_hasFocus ? Colors.white : Colors.white12),
            ),
          ),
          child: Text(widget.label, style: TextStyle(
            color: widget.active ? Sp.focus
                : (_hasFocus ? Colors.white : Sp.textDim),
            fontSize: 14,
            fontWeight: widget.active ? FontWeight.w700 : FontWeight.w400,
          )),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PlaylistDetailTvScreen — détail d'une playlist (lecture)
// ══════════════════════════════════════════════════════════════════════════════
class PlaylistDetailTvScreen extends StatefulWidget {
  final Playlist playlist;
  final bool readOnly;
  const PlaylistDetailTvScreen({super.key, required this.playlist, this.readOnly = false});
  @override State<PlaylistDetailTvScreen> createState() => _PlaylistDetailTvScreenState();
}

class _PlaylistDetailTvScreenState extends State<PlaylistDetailTvScreen> {
  List<Song> _tracks = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await SwingApiService().getPlaylistTracks(widget.playlist.id);
      if (mounted) setState(() { _tracks = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();
    final url = widget.playlist.imageHash != null
        ? '${SwingApiService().baseUrl}/img/playlist/${widget.playlist.imageHash}.webp'
        : '';

    return Scaffold(
      backgroundColor: Sp.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Sp.focus))
          : CustomScrollView(
              slivers: [
                // ── Header ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Sp.surface, Sp.bg],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(48, 48, 48, 32),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Pochette
                        TvFocusCard(
                          width: 200, height: 200,
                          onTap: () => Navigator.pop(context),
                          child: url.isNotEmpty
                              ? TvArtworkImage(url: url, size: 200, borderRadius: BorderRadius.zero, fallbackIcon: Icons.queue_music_rounded)
                              : Container(color: Sp.surface, child: const Icon(Icons.queue_music_rounded, color: Colors.white24, size: 80)),
                        ),
                        const SizedBox(width: 36),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('PLAYLIST', style: TextStyle(color: Sp.textDim, fontSize: 12, letterSpacing: 1.2, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 8),
                              Text(widget.playlist.name,
                                  style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (widget.playlist.description?.isNotEmpty == true) ...[
                                const SizedBox(height: 6),
                                Text(widget.playlist.description!, maxLines: 2, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Sp.textDim, fontSize: 15)),
                              ],
                              const SizedBox(height: 10),
                              Text('${_tracks.length} titre${_tracks.length != 1 ? 's' : ''}',
                                  style: const TextStyle(color: Sp.textDim, fontSize: 15)),
                              const SizedBox(height: 20),
                              Row(children: [
                                if (_tracks.isNotEmpty)
                                  _TvPrimaryBtn(
                                    icon: Icons.play_arrow_rounded,
                                    label: 'Lecture',
                                    autofocus: true,
                                    onTap: () => player.playSong(_tracks.first, queue: _tracks, index: 0),
                                  ),
                                const SizedBox(width: 12),
                                if (_tracks.isNotEmpty)
                                  _TvSecondaryBtn(
                                    icon: Icons.shuffle_rounded,
                                    label: 'Aléatoire',
                                    onTap: () {
                                      final copy = List<Song>.from(_tracks)..shuffle();
                                      player.playSong(copy.first, queue: copy, index: 0);
                                    },
                                  ),
                              ]),
                            ],
                          ),
                        ),
                        // Retour
                        Align(
                          alignment: Alignment.topRight,
                          child: _TvIconBtn(icon: Icons.arrow_back_rounded, onTap: () => Navigator.pop(context)),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Titres ─────────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 48, 80),
                  sliver: _tracks.isEmpty
                      ? const SliverToBoxAdapter(
                          child: Center(child: Padding(
                            padding: EdgeInsets.all(48),
                            child: Text('Playlist vide', style: TextStyle(color: Sp.textDim, fontSize: 18)),
                          )),
                        )
                      : SliverList.builder(
                          itemCount: _tracks.length,
                          itemBuilder: (ctx, i) {
                            final song = _tracks[i];
                            final isPlaying = context.watch<PlayerProvider>().currentSong?.hash == song.hash;
                            final artUrl = '${SwingApiService().baseUrl}/img/thumbnail/${song.image ?? song.hash}';
                            return TvListTile(
                              key: ValueKey('${song.hash}_$i'),
                              leading: Stack(
                                alignment: Alignment.center,
                                children: [
                                  TvArtworkImage(url: artUrl, size: 56),
                                  if (isPlaying)
                                    Container(
                                      width: 56, height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.graphic_eq_rounded, color: Sp.focus),
                                    ),
                                ],
                              ),
                              title: song.title,
                              subtitle: '${song.artist} • ${song.album ?? ''}',
                              isActive: isPlaying,
                              trailing: Text(song.formattedDuration,
                                  style: const TextStyle(color: Sp.textDim, fontSize: 14)),
                              onTap: () => player.playSong(song, queue: _tracks, index: i),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// Bouton primaire TV
class _TvPrimaryBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool autofocus;
  const _TvPrimaryBtn({required this.icon, required this.label, required this.onTap, this.autofocus = false});
  @override State<_TvPrimaryBtn> createState() => _TvPrimaryBtnState();
}
class _TvPrimaryBtnState extends State<_TvPrimaryBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) => Focus(
    autofocus: widget.autofocus,
    onFocusChange: (f) => setState(() => _hasFocus = f),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: _hasFocus ? Colors.white : Sp.focus,
          borderRadius: BorderRadius.circular(50),
          boxShadow: _hasFocus ? [BoxShadow(color: Sp.focus.withOpacity(0.5), blurRadius: 20)] : [],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, color: _hasFocus ? Sp.bg : Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(widget.label, style: TextStyle(color: _hasFocus ? Sp.bg : Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );
}

// Bouton secondaire TV
class _TvSecondaryBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _TvSecondaryBtn({required this.icon, required this.label, required this.onTap});
  @override State<_TvSecondaryBtn> createState() => _TvSecondaryBtnState();
}
class _TvSecondaryBtnState extends State<_TvSecondaryBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (f) => setState(() => _hasFocus = f),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: _hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: _hasFocus ? Colors.white : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, color: _hasFocus ? Colors.white : Sp.textDim, size: 20),
          const SizedBox(width: 6),
          Text(widget.label, style: TextStyle(color: _hasFocus ? Colors.white : Sp.textDim, fontSize: 14, fontWeight: FontWeight.w500)),
        ]),
      ),
    ),
  );
}

// Bouton icône TV
class _TvIconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _TvIconBtn({required this.icon, required this.onTap});
  @override State<_TvIconBtn> createState() => _TvIconBtnState();
}
class _TvIconBtnState extends State<_TvIconBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) => Focus(
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
        child: Icon(widget.icon, color: _hasFocus ? Colors.white : Sp.textDim, size: 24),
      ),
    ),
  );
}
