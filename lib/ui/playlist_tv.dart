import 'package:flutter/material.dart';
import '../core/models/playlist.dart';
import '../core/models/song.dart';
import '../core/services/api_service.dart';
import '../core/providers/player_provider.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class PlaylistTvScreen extends StatefulWidget {
  final Playlist playlist;
  const PlaylistTvScreen({super.key, required this.playlist});

  @override
  State<PlaylistTvScreen> createState() => _PlaylistTvScreenState();
}

class _PlaylistTvScreenState extends State<PlaylistTvScreen> {
  List<Song> _tracks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  Future<void> _loadTracks() async {
    try {
      final res = await SwingApiService().getPlaylistTracks(widget.playlist.id);
      if (mounted) {
        setState(() {
          _tracks = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _playTrack(Song song, int index) {
    context.read<PlayerProvider>().playSong(song, queue: _tracks, index: index);
  }

  void _playAll() {
    if (_tracks.isNotEmpty) {
      _playTrack(_tracks.first, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final artwork = widget.playlist.imageHash != null 
        ? '${SwingApiService().baseUrl}/img/playlist/${widget.playlist.imageHash}.webp'
        : '';

    return Scaffold(
      body: Row(
        children: [
          // ── En-tête de la playlist avec Cover (Gauche) ────────────────────────
          Container(
            width: 400,
            color: Sp.surface,
            padding: const EdgeInsets.all(48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    artwork,
                    width: 300,
                    height: 300,
                    fit: BoxFit.cover,
                    headers: SwingApiService().authHeaders,
                    errorBuilder: (_, __, ___) => Container(
                       width: 300, height: 300,
                       color: Colors.white12,
                       child: const Icon(Icons.queue_music_rounded, size: 84, color: Colors.white24),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.playlist.name,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.playlist.description ?? '${widget.playlist.trackCount} titres',
                  style: const TextStyle(
                    fontSize: 20,
                    color: Sp.textDim,
                  ),
                ),
                const SizedBox(height: 32),
                if (!_loading && _tracks.isNotEmpty)
                  _TvPlayButton(onTap: _playAll),
              ],
            ),
          ),
          
          // ── Liste des pistes (Droite) ──────────────────────────────────────
          Expanded(
            child: _loading 
                ? const Center(child: CircularProgressIndicator(color: Sp.focus))
                : _tracks.isEmpty
                    ? const Center(child: Text("Cette playlist est vide.", style: TextStyle(color: Sp.textDim, fontSize: 18)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
                        itemCount: _tracks.length,
                        itemBuilder: (context, index) {
                          final song = _tracks[index];
                          final isPlaying = context.watch<PlayerProvider>().currentSong?.hash == song.hash;
                          return _TvTrackTile(
                            song: song,
                            index: index,
                            isPlaying: isPlaying,
                            onTap: () => _playTrack(song, index),
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }
}

// Réutilisation du bouton Play TV
class _TvPlayButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TvPlayButton({required this.onTap});

  @override
  State<_TvPlayButton> createState() => _TvPlayButtonState();
}

class _TvPlayButtonState extends State<_TvPlayButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white : Sp.focus,
            borderRadius: BorderRadius.circular(40),
            boxShadow: _hasFocus ? [BoxShadow(color: Sp.focus.withAlpha(128), blurRadius: 20)] : [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, color: _hasFocus ? Sp.bg : Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                "Tout lire",
                style: TextStyle(
                  color: _hasFocus ? Sp.bg : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Réutilisation de la ligne de piste TV
class _TvTrackTile extends StatefulWidget {
  final Song song;
  final int index;
  final bool isPlaying;
  final VoidCallback onTap;

  const _TvTrackTile({
    required this.song,
    required this.index,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_TvTrackTile> createState() => _TvTrackTileState();
}

class _TvTrackTileState extends State<_TvTrackTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withAlpha(25) : 
                   (widget.isPlaying ? Sp.focus.withAlpha(51) : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: _hasFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
            boxShadow: _hasFocus ? [BoxShadow(color: Colors.white.withAlpha(15), blurRadius: 10)] : [],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: widget.isPlaying
                    ? const Icon(Icons.graphic_eq_rounded, color: Sp.focus, size: 20)
                    : Text(
                        '${widget.index + 1}',
                        style: TextStyle(
                          color: _hasFocus ? Colors.white : Sp.textDim,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.song.title,
                      style: TextStyle(
                        color: widget.isPlaying ? Sp.focus : Colors.white,
                        fontSize: 18,
                        fontWeight: widget.isPlaying ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.song.artist,
                      style: TextStyle(
                        color: _hasFocus ? Colors.white70 : Sp.textDim,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Text(
                widget.song.formattedDuration,
                style: TextStyle(
                  color: _hasFocus ? Colors.white : Sp.textDim,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
