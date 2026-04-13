import 'package:flutter/material.dart';
import '../core/models/playlist.dart';
import '../core/services/api_service.dart';
import '../main.dart';
import 'playlist_tv.dart';

class LibraryTvScreen extends StatefulWidget {
  const LibraryTvScreen({super.key});

  @override
  State<LibraryTvScreen> createState() => _LibraryTvScreenState();
}

class _LibraryTvScreenState extends State<LibraryTvScreen> {
  List<Playlist> _playlists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await SwingApiService().getPlaylists();
      if (mounted) setState(() { _playlists = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Sp.focus));
    }

    if (_playlists.isEmpty) {
      return const Center(
        child: Text(
          "Aucune playlist trouvée",
          style: TextStyle(color: Sp.textDim, fontSize: 18),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vos Playlists',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 24,
                mainAxisSpacing: 24,
                childAspectRatio: 0.8,
              ),
              itemCount: _playlists.length,
              itemBuilder: (context, index) {
                return _TvPlaylistCard(playlist: _playlists[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TvPlaylistCard extends StatefulWidget {
  final Playlist playlist;
  const _TvPlaylistCard({required this.playlist});

  @override
  State<_TvPlaylistCard> createState() => _TvPlaylistCardState();
}

class _TvPlaylistCardState extends State<_TvPlaylistCard> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final artwork = widget.playlist.imageHash != null 
        ? '${SwingApiService().baseUrl}/img/playlist/${widget.playlist.imageHash}.webp'
        : '';

    return RepaintBoundary(
      child: InkWell(
        onFocusChange: (f) => setState(() => _hasFocus = f),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
               builder: (_) => PlaylistTvScreen(playlist: widget.playlist)
            )
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: _hasFocus ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: _hasFocus ? Border.all(color: Colors.white, width: 3) : Border.all(color: Colors.transparent, width: 3),
            boxShadow: _hasFocus ? [BoxShadow(color: Sp.focus.withAlpha(128), blurRadius: 20)] : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9), // inner border radius to avoid visual clipping
                  child: Image.network(
                    artwork,
                    fit: BoxFit.cover,
                    headers: SwingApiService().authHeaders,
                    errorBuilder: (_, __, ___) => Container(
                      color: Sp.surface,
                      child: const Icon(Icons.queue_music_rounded, size: 64, color: Colors.white54),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _hasFocus ? Colors.white : Sp.textDim,
                ),
              ),
              Text(
                '${widget.playlist.trackCount} titres',
                maxLines: 1,
                style: const TextStyle(fontSize: 14, color: Sp.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
