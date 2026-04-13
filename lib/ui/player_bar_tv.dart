import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/player_provider.dart';
import '../core/services/api_service.dart';
import '../main.dart';
import 'player_tv.dart';

class MiniPlayerTv extends StatefulWidget {
  const MiniPlayerTv({super.key});

  @override
  State<MiniPlayerTv> createState() => _MiniPlayerTvState();
}

class _MiniPlayerTvState extends State<MiniPlayerTv> {
  bool _hasFocus = false;

  void _openPlayer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PlayerTvScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) return const SizedBox.shrink();

    final artwork =
        '${SwingApiService().baseUrl}/img/thumbnail/${song.image ?? song.hash}';

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: _openPlayer,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 80,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hasFocus ? Sp.surface.withAlpha(255) : Sp.surface.withAlpha(200),
            borderRadius: BorderRadius.circular(16),
            border: _hasFocus
                ? Border.all(color: Colors.white, width: 2)
                : Border.all(color: Colors.white24, width: 1),
            boxShadow: _hasFocus
                ? [BoxShadow(color: Sp.focus.withAlpha(128), blurRadius: 16)]
                : [BoxShadow(color: Colors.black.withAlpha(100), blurRadius: 8)],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  artwork,
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  headers: SwingApiService().authHeaders,
                  errorBuilder: (_, __, ___) => Container(
                    width: 56, height: 56,
                    color: Colors.white12,
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      song.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Sp.textDim,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Mini Equalizer icon if playing
              if (player.isPlaying)
                const Icon(Icons.graphic_eq_rounded, color: Sp.focus, size: 28)
              else
                const Icon(Icons.pause_circle_filled_rounded, color: Sp.textDim, size: 28),
              const SizedBox(width: 16),
              Text(
                'Ouvrir le lecteur',
                style: TextStyle(
                  color: _hasFocus ? Colors.white : Colors.transparent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
