import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/models/song.dart';
import '../core/services/api_service.dart';
import '../core/providers/player_provider.dart';
import '../main.dart';
import 'package:flutter/services.dart';

class SearchTvScreen extends StatefulWidget {
  const SearchTvScreen({super.key});

  @override
  State<SearchTvScreen> createState() => _SearchTvScreenState();
}

class _SearchTvScreenState extends State<SearchTvScreen> {
  final TextEditingController _controller = TextEditingController();
  List<dynamic> _results = [];
  bool _loading = false;
  bool _hasSearched = false;
  bool _isDeezer = false;

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    
    if (mounted) setState(() { _loading = true; _hasSearched = true; });
    
    try {
      if (_isDeezer) {
        final res = await SwingApiService().searchDeezer(query);
        if (mounted) {
          setState(() {
            _results = res;
            _loading = false;
          });
        }
      } else {
        final res = await SwingApiService().searchSongs(query);
        if (mounted) {
          setState(() {
            _results = res;
            _loading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _playTrack(Song song, int index) {
    // Only pass Song objects to queue
    final queue = _results.whereType<Song>().toList();
    context.read<PlayerProvider>().playSong(song, queue: queue, index: queue.indexOf(song));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recherche',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // ── Champ de recherche ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _TvSearchField(
                  controller: _controller,
                  onSubmitted: _performSearch,
                ),
              ),
              const SizedBox(width: 24),
              _TvSearchButton(
                onTap: () => _performSearch(_controller.text),
              ),
              const SizedBox(width: 24),
              Row(
                children: [
                  _SourceToggle(
                    label: 'Askaria',
                    active: !_isDeezer,
                    onTap: () {
                      setState(() => _isDeezer = false);
                      _performSearch(_controller.text);
                    },
                  ),
                  const SizedBox(width: 8),
                  _SourceToggle(
                    label: 'Deezer',
                    active: _isDeezer,
                    onTap: () {
                      setState(() => _isDeezer = true);
                      _performSearch(_controller.text);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          // ── Résultats ──────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Sp.focus))
                : _hasSearched && _results.isEmpty
                    ? const Center(child: Text("Aucun résultat trouvé.", style: TextStyle(color: Sp.textDim, fontSize: 18)))
                    : !_hasSearched
                        ? const Center(child: Icon(Icons.search, size: 84, color: Colors.white12))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              if (_isDeezer) {
                                return _DeezerResultTile(
                                  item: item,
                                  onDownload: () async {
                                    final success = await SwingApiService().downloadDeezerTrack(item['id'].toString());
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(success ? "Téléchargement lancé !" : "Erreur"),
                                          backgroundColor: success ? Colors.green : Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                );
                              } else {
                                final song = item as Song;
                                final isPlaying = context.watch<PlayerProvider>().currentSong?.hash == song.hash;
                                return _TvSearchResultTile(
                                  song: song,
                                  isPlaying: isPlaying,
                                  onTap: () => _playTrack(song, index),
                                );
                              }
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class _TvSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  const _TvSearchField({required this.controller, required this.onSubmitted});

  @override
  State<_TvSearchField> createState() => _TvSearchFieldState();
}

class _TvSearchFieldState extends State<_TvSearchField> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: _hasFocus ? Colors.white.withAlpha(25) : Sp.surface,
          borderRadius: BorderRadius.circular(16),
          border: _hasFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.white12, width: 2),
        ),
        child: TextField(
          controller: widget.controller,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: const InputDecoration(
            border: InputBorder.none,
            hintText: 'Titres, albums, artistes...',
            hintStyle: TextStyle(color: Sp.textDim),
            icon: Icon(Icons.search, color: Sp.textDim),
          ),
          onSubmitted: widget.onSubmitted,
        ),
      ),
    );
  }
}

class _TvSearchButton extends StatefulWidget {
  final VoidCallback onTap;
  const _TvSearchButton({required this.onTap});

  @override
  State<_TvSearchButton> createState() => _TvSearchButtonState();
}

class _TvSearchButtonState extends State<_TvSearchButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white : Sp.focus,
            borderRadius: BorderRadius.circular(16),
            boxShadow: _hasFocus ? [BoxShadow(color: Sp.focus.withAlpha(128), blurRadius: 20)] : [],
          ),
          child: Text(
            "Rechercher",
            style: TextStyle(
              color: _hasFocus ? Sp.bg : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _TvSearchResultTile extends StatefulWidget {
  final Song song;
  final bool isPlaying;
  final VoidCallback onTap;

  const _TvSearchResultTile({
    required this.song,
    required this.isPlaying,
    required this.onTap,
  });

  @override
  State<_TvSearchResultTile> createState() => _TvSearchResultTileState();
}

class _TvSearchResultTileState extends State<_TvSearchResultTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final artwork = widget.song.image != null 
        ? '${SwingApiService().baseUrl}/img/thumbnail/${widget.song.image}'
        : '';

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withAlpha(25) : 
                   (widget.isPlaying ? Sp.focus.withAlpha(51) : Sp.surface),
            borderRadius: BorderRadius.circular(12),
            border: _hasFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  artwork,
                  width: 56, height: 56, fit: BoxFit.cover,
                  headers: SwingApiService().authHeaders,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56, height: 56, color: Colors.white12,
                    child: const Icon(Icons.music_note, color: Colors.white54),
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
                      '${widget.song.artist} • ${widget.song.album}',
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

class _SourceToggle extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _SourceToggle({required this.label, required this.active, required this.onTap});

  @override
  State<_SourceToggle> createState() => _SourceToggleState();
}

class _SourceToggleState extends State<_SourceToggle> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: widget.active ? Sp.focus : (_hasFocus ? Colors.white.withAlpha(25) : Sp.surface),
            borderRadius: BorderRadius.circular(16),
            border: _hasFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: widget.active ? Colors.white : Sp.textDim,
              fontSize: 16,
              fontWeight: widget.active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _DeezerResultTile extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onDownload;

  const _DeezerResultTile({required this.item, required this.onDownload});

  @override
  State<_DeezerResultTile> createState() => _DeezerResultTileState();
}

class _DeezerResultTileState extends State<_DeezerResultTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.item['title_short'] ?? widget.item['title'] ?? 'Inconnu';
    final artist = widget.item['artist']?['name'] ?? 'Inconnu';
    final album = widget.item['album']?['title'] ?? 'Inconnu';
    final artwork = widget.item['album']?['cover_small'] ?? '';

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onDownload();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: widget.onDownload,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withAlpha(25) : Sp.surface,
            borderRadius: BorderRadius.circular(12),
            border: _hasFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  artwork,
                  width: 56, height: 56, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56, height: 56, color: Colors.white12,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$artist • $album',
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
              Icon(Icons.download_rounded, color: _hasFocus ? Colors.white : Sp.textDim, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
