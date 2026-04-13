import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/providers/player_provider.dart';
import '../core/services/api_service.dart';
import '../main.dart';

class PlayerTvScreen extends StatefulWidget {
  const PlayerTvScreen({super.key});

  @override
  State<PlayerTvScreen> createState() => _PlayerTvScreenState();
}

class _PlayerTvScreenState extends State<PlayerTvScreen> {
  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final song = player.currentSong;

    if (song == null) {
      return const Scaffold(
        body: Center(child: Text("Aucune lecture en cours")),
      );
    }

    final artwork = '${SwingApiService().baseUrl}/img/thumbnail/${song.image ?? song.hash}';
    final colors = player.dynamicColors;
    final primaryColor = colors.accent;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background flouté
          Positioned.fill(
            child: Image.network(
              artwork,
              fit: BoxFit.cover,
              headers: SwingApiService().authHeaders,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(
                color: Colors.black.withAlpha(150),
              ),
            ),
          ),
          
          // Contenu principal
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
              child: Row(
                children: [
                  // Pochette à gauche
                  Hero(
                    tag: 'album_art_${song.hash}', // Tag possible si on vient de la vue Album
                    child: Container(
                      width: 360,
                      height: 360,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(128),
                            blurRadius: 32,
                            offset: const Offset(0, 16),
                          )
                        ],
                        image: DecorationImage(
                          image: NetworkImage(artwork, headers: SwingApiService().authHeaders),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 64),
                  
                  // Informations et Contrôles à droite
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          song.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          song.artist,
                          style: TextStyle(
                            color: Colors.white.withAlpha(200),
                            fontSize: 24,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 48),
                        
                        // Ligne de progression
                        Row(
                          children: [
                            Text(
                              _formatDuration(player.position),
                              style: const TextStyle(color: Sp.textDim, fontSize: 16),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: Colors.white30,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: player.progress.clamp(0.0, 1.0),
                                    child: Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: primaryColor.withAlpha(128),
                                            blurRadius: 8,
                                          )
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              _formatDuration(player.duration),
                              style: const TextStyle(color: Sp.textDim, fontSize: 16),
                            ),
                          ],
                        ),
                        const SizedBox(height: 48),
                        
                        // Contrôles
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _PlayerControlButton(
                              icon: Icons.shuffle_rounded,
                              activeColor: player.shuffle ? primaryColor : Sp.textDim,
                              onTap: player.toggleShuffle,
                              size: 42,
                            ),
                            const SizedBox(width: 32),
                            _PlayerControlButton(
                              icon: Icons.skip_previous_rounded,
                              onTap: player.previous,
                              size: 56,
                            ),
                            const SizedBox(width: 32),
                            _PlayerControlButton(
                              icon: player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                              onTap: player.playPause,
                              size: 84,
                              autoFocus: true, // Auto focus sur Play
                            ),
                            const SizedBox(width: 32),
                            _PlayerControlButton(
                              icon: Icons.skip_next_rounded,
                              onTap: player.next,
                              size: 56,
                            ),
                            const SizedBox(width: 32),
                            _PlayerControlButton(
                              icon: player.repeatMode == RepeatMode.one 
                                    ? Icons.repeat_one_rounded 
                                    : Icons.repeat_rounded,
                              activeColor: player.repeatMode != RepeatMode.off ? primaryColor : Sp.textDim,
                              onTap: player.toggleRepeat,
                              size: 42,
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // Bouton de retour discret en haut à droite
          Positioned(
            top: 24,
            right: 24,
            child: _PlayerControlButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
              size: 42,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final min = twoDigits(d.inMinutes.remainder(60));
    final sec = twoDigits(d.inSeconds.remainder(60));
    return '$min:$sec';
  }
}

class _PlayerControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final Color? activeColor;
  final bool autoFocus;

  const _PlayerControlButton({
    required this.icon,
    required this.onTap,
    required this.size,
    this.activeColor,
    this.autoFocus = false,
  });

  @override
  State<_PlayerControlButton> createState() => _PlayerControlButtonState();
}

class _PlayerControlButtonState extends State<_PlayerControlButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.activeColor ?? Colors.white;

    return Focus(
      autofocus: widget.autoFocus,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hasFocus ? Colors.white.withAlpha(25) : Colors.transparent,
            border: _hasFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
            boxShadow: _hasFocus ? [BoxShadow(color: color.withAlpha(70), blurRadius: 10)] : [],
          ),
          padding: const EdgeInsets.all(8),
          transform: _hasFocus ? (Matrix4.identity()..scale(1.1)) : Matrix4.identity(),
          child: Icon(
            widget.icon,
            size: widget.size,
            color: color,
          ),
        ),
      ),
    );
  }
}
