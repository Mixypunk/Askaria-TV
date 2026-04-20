import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/player_provider.dart';
import '../core/services/api_service.dart';
import '../main.dart';
import 'player_tv.dart';
import 'widgets_tv.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MiniPlayerTv — mini-player compact pour sidebar
// ══════════════════════════════════════════════════════════════════════════════
class MiniPlayerTv extends StatefulWidget {
  const MiniPlayerTv({super.key});
  @override State<MiniPlayerTv> createState() => _MiniPlayerTvState();
}

class _MiniPlayerTvState extends State<MiniPlayerTv> {
  bool _hasFocus = false;

  void _openPlayer() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const PlayerTvScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) return const SizedBox.shrink();

    final artwork = '${SwingApiService().baseUrl}/img/thumbnail/${song.image ?? song.hash}';

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: _openPlayer,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hasFocus
                ? Colors.white.withOpacity(0.12)
                : Sp.bg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.white12,
              width: _hasFocus ? 2 : 1,
            ),
            boxShadow: _hasFocus
                ? [BoxShadow(color: Sp.focus.withOpacity(0.35), blurRadius: 12)]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Artwork + info
              Row(
                children: [
                  TvArtworkImage(
                    url: artwork,
                    size: 44,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Sp.textDim,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icône état lecture
                  if (player.isPlaying)
                    const Icon(Icons.graphic_eq_rounded, color: Sp.focus, size: 18)
                  else
                    const Icon(Icons.pause_rounded, color: Sp.textDim, size: 18),
                ],
              ),
              // Barre de progression
              const SizedBox(height: 8),
              _ProgressBar(progress: player.progress),
              // Contrôles rapides
              const SizedBox(height: 6),
              _QuickControls(player: player),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  const _ProgressBar({required this.progress});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        return Container(
          height: 3,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: kGrad,
                borderRadius: BorderRadius.circular(2),
                boxShadow: [BoxShadow(color: Sp.focus.withOpacity(0.5), blurRadius: 4)],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _QuickControls extends StatelessWidget {
  final PlayerProvider player;
  const _QuickControls({required this.player});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickBtn(
          icon: Icons.skip_previous_rounded,
          onTap: player.previous,
          size: 18,
        ),
        _QuickBtn(
          icon: player.isPlaying
              ? Icons.pause_circle_filled_rounded
              : Icons.play_circle_filled_rounded,
          onTap: player.playPause,
          size: 24,
          accent: true,
        ),
        _QuickBtn(
          icon: Icons.skip_next_rounded,
          onTap: player.next,
          size: 18,
        ),
      ],
    );
  }
}

class _QuickBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool accent;
  const _QuickBtn({required this.icon, required this.onTap, required this.size, this.accent = false});
  @override State<_QuickBtn> createState() => _QuickBtnState();
}
class _QuickBtnState extends State<_QuickBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) => Focus(
    onFocusChange: (f) => setState(() => _hasFocus = f),
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _hasFocus ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          widget.icon,
          size: widget.size,
          color: _hasFocus
              ? Colors.white
              : (widget.accent ? Sp.focus : Sp.textDim),
        ),
      ),
    ),
  );
}
