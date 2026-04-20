import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/services/api_service.dart';
import '../core/models/song.dart';
import '../core/providers/player_provider.dart';
import '../main.dart';
import 'widgets_tv.dart';

// ══════════════════════════════════════════════════════════════════════════════
// FavouritesTvSection — liste de tous les titres favoris
// ══════════════════════════════════════════════════════════════════════════════
class FavouritesTvSection extends StatefulWidget {
  const FavouritesTvSection({super.key});
  @override State<FavouritesTvSection> createState() => _FavouritesTvSectionState();
}

class _FavouritesTvSectionState extends State<FavouritesTvSection> {
  List<Song> _favourites = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await SwingApiService().getFavourites();
      if (mounted) setState(() { _favourites = res; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final player = context.read<PlayerProvider>();

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TvSectionHeader(title: '❤️  Favoris'),
              const SizedBox(width: 16),
              if (_favourites.isNotEmpty)
                _TvPlayAllBtn(
                  onTap: () => player.playSong(
                    _favourites.first,
                    queue: _favourites,
                    index: 0,
                  ),
                ),
            ],
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Sp.focus))
                : _favourites.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.favorite_border_rounded, color: Colors.white12, size: 80),
                            SizedBox(height: 16),
                            Text('Aucun favori', style: TextStyle(color: Sp.textDim, fontSize: 20)),
                            SizedBox(height: 8),
                            Text('Appuyez sur ♥ sur un titre pour l\'ajouter',
                                style: TextStyle(color: Colors.white24, fontSize: 14)),
                          ],
                        ),
                      )
                    : RefreshIndicatorTV(
                        onRefresh: _load,
                        child: ListView.builder(
                          itemCount: _favourites.length,
                          itemBuilder: (ctx, i) {
                            final song = _favourites[i];
                            final isPlaying = context.watch<PlayerProvider>().currentSong?.hash == song.hash;
                            final artUrl = '${SwingApiService().baseUrl}/img/thumbnail/${song.image ?? song.hash}';
                            return TvListTile(
                              key: ValueKey(song.hash),
                              autoFocus: i == 0,
                              leading: Stack(
                                children: [
                                  TvArtworkImage(url: artUrl, size: 56),
                                  if (isPlaying)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.graphic_eq_rounded, color: Sp.focus, size: 22),
                                      ),
                                    ),
                                ],
                              ),
                              title: song.title,
                              subtitle: '${song.artist} • ${song.album ?? ''}',
                              isActive: isPlaying,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(song.formattedDuration,
                                      style: const TextStyle(color: Sp.textDim, fontSize: 14)),
                                  const SizedBox(width: 12),
                                  _FavBtn(
                                    song: song,
                                    onToggled: _load,
                                  ),
                                ],
                              ),
                              onTap: () => player.playSong(song, queue: _favourites, index: i),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Bouton "Tout lire" ────────────────────────────────────────────────────────
class _TvPlayAllBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _TvPlayAllBtn({required this.onTap});
  @override State<_TvPlayAllBtn> createState() => _TvPlayAllBtnState();
}
class _TvPlayAllBtnState extends State<_TvPlayAllBtn> {
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
            color: _hasFocus ? Colors.white : Sp.focus,
            borderRadius: BorderRadius.circular(50),
            boxShadow: _hasFocus
                ? [BoxShadow(color: Sp.focus.withOpacity(0.4), blurRadius: 16)]
                : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.play_arrow_rounded, color: _hasFocus ? Sp.bg : Colors.white, size: 20),
            const SizedBox(width: 6),
            Text('Tout lire', style: TextStyle(
              color: _hasFocus ? Sp.bg : Colors.white,
              fontSize: 14, fontWeight: FontWeight.w700,
            )),
          ]),
        ),
      ),
    );
  }
}

// ── Bouton favori inline ──────────────────────────────────────────────────────
class _FavBtn extends StatefulWidget {
  final Song song;
  final VoidCallback onToggled;
  const _FavBtn({required this.song, required this.onToggled});
  @override State<_FavBtn> createState() => _FavBtnState();
}
class _FavBtnState extends State<_FavBtn> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final isFav = player.isFavourite(widget.song.hash);
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: () async {
          await player.toggleFavourite(widget.song.hash);
          widget.onToggled();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _hasFocus ? Colors.white : Colors.transparent),
          ),
          child: Icon(
            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFav ? Colors.redAccent : Sp.textDim,
            size: 20,
          ),
        ),
      ),
    );
  }
}

// ── RefreshIndicator TV (pas de geste pull → bouton focus) ───────────────────
class RefreshIndicatorTV extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  const RefreshIndicatorTV({super.key, required this.child, required this.onRefresh});
  @override
  Widget build(BuildContext context) => child; // Sur TV, le refresh se fait via D-Pad
}
