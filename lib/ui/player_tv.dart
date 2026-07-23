import 'dart:ui';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/providers/player_provider.dart';
import '../core/services/api_service.dart';
import '../main.dart';
import '../core/widgets/waveform_seekbar.dart';

class PlayerTvScreen extends StatefulWidget {
  const PlayerTvScreen({super.key});

  @override
  State<PlayerTvScreen> createState() => _PlayerTvScreenState();
}

class _PlayerTvScreenState extends State<PlayerTvScreen> {
  List<double>? _waveform;
  String? _waveformHash;
  bool _showLyrics = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWaveform();
  }

  Future<void> _loadWaveform() async {
    final player = context.read<PlayerProvider>();
    final song = player.currentSong;
    if (song != null && song.hash != _waveformHash) {
      _waveformHash = song.hash;
      _waveform = null;
      final peaks = await SwingApiService().getWaveform(song.hash);
      if (mounted && _waveformHash == song.hash) {
        setState(() {
          _waveform = peaks;
        });
      }
    }
  }

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
          // Background flouté, optimisé avec petite image mise en cache
          Positioned.fill(
            child: CachedNetworkImage(
              imageUrl: artwork,
              fit: BoxFit.cover,
              httpHeaders: SwingApiService().authHeaders,
              memCacheWidth: 200, // Basse résolution car très flouté
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Pochette responsive : max 340px, min 160px selon hauteur dispo
                final artSize = (constraints.maxHeight * 0.55).clamp(160.0, 340.0);
                final hPad    = constraints.maxWidth  > 1200 ? 64.0 : 32.0;
                final vPad    = constraints.maxHeight > 700  ? 32.0 : 16.0;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                  child: Row(
                    children: [
                      // Pochette à gauche ou Paroles
                      if (_showLyrics && player.hasLyrics)
                        SizedBox(
                          width: artSize,
                          height: artSize,
                          child: _TvLyricsPage(
                            player: player,
                            accent: primaryColor,
                          ),
                        )
                      else
                        Hero(
                          tag: 'album_art_${song.hash}',
                          child: Container(
                            width: artSize,
                            height: artSize,
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
                                image: CachedNetworkImageProvider(
                                  artwork, 
                                  headers: SwingApiService().authHeaders,
                                  maxWidth: 500, // Optimize memory for cover
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      SizedBox(width: hPad),
                      
                      // Informations et Contrôles à droite
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: constraints.maxHeight > 700 ? 38 : 28,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: vPad * 0.25),
                            Text(
                              song.artist,
                              style: TextStyle(
                                color: Colors.white.withAlpha(200),
                                fontSize: constraints.maxHeight > 700 ? 22 : 18,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: vPad),
                            
                            // Ligne de progression
                            Row(
                              children: [
                                Text(
                                  _formatDuration(player.position),
                                  style: const TextStyle(color: Sp.textDim, fontSize: 16),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: WaveformSeekbar(
                                    peaks: _waveform,
                                    progress: player.progress,
                                    accentColor: primaryColor,
                                    onSeekDelta: (delta) {
                                      final newSeconds = player.position.inSeconds + delta;
                                      player.seek(Duration(seconds: newSeconds.clamp(0, player.duration.inSeconds)));
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  _formatDuration(player.duration),
                                  style: const TextStyle(color: Sp.textDim, fontSize: 16),
                                ),
                              ],
                            ),
                            SizedBox(height: vPad),
                            
                            // Contrôles
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _PlayerControlButton(
                                  icon: player.isFavourite(song.hash) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                  activeColor: player.isFavourite(song.hash) ? Colors.red : Sp.textDim,
                                  onTap: () => player.toggleFavourite(song.hash),
                                  size: 36,
                                ),
                                if (player.hasLyrics) ...[
                                  const SizedBox(width: 24),
                                  _PlayerControlButton(
                                    icon: Icons.lyrics_rounded,
                                    activeColor: _showLyrics ? primaryColor : Sp.textDim,
                                    onTap: () => setState(() => _showLyrics = !_showLyrics),
                                    size: 36,
                                  ),
                                ],
                                const SizedBox(width: 24),
                                _PlayerControlButton(
                                  icon: Icons.shuffle_rounded,
                                  activeColor: player.shuffle ? primaryColor : Sp.textDim,
                                  onTap: player.toggleShuffle,
                                  size: 36,
                                ),
                                const SizedBox(width: 24),
                                _PlayerControlButton(
                                  icon: Icons.skip_previous_rounded,
                                  onTap: player.previous,
                                  size: 48,
                                ),
                                const SizedBox(width: 24),
                                _PlayerControlButton(
                                  icon: player.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                                  onTap: player.playPause,
                                  size: 72,
                                  autoFocus: true,
                                ),
                                const SizedBox(width: 24),
                                _PlayerControlButton(
                                  icon: Icons.skip_next_rounded,
                                  onTap: player.next,
                                  size: 48,
                                ),
                                const SizedBox(width: 24),
                                _PlayerControlButton(
                                  icon: player.repeatMode == RepeatMode.one 
                                        ? Icons.repeat_one_rounded 
                                        : Icons.repeat_rounded,
                                  activeColor: player.repeatMode != RepeatMode.off ? primaryColor : Sp.textDim,
                                  onTap: player.toggleRepeat,
                                  size: 36,
                                ),
                                const SizedBox(width: 24),
                                _PlayerControlButton(
                                  icon: Icons.radio_rounded,
                                  activeColor: Sp.textDim,
                                  onTap: () async {
                                    final tracks = await SwingApiService().getRadio(song.hash);
                                    if (tracks.isNotEmpty && mounted) {
                                      if (!context.mounted) return;
                                      context.read<PlayerProvider>().playSong(tracks.first, queue: tracks, index: 0);
                                    }
                                  },
                                  size: 36,
                                ),
                              ],
                            ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                );
              },
            ),
          ),
          
          // Bouton de retour discret en haut à droite
          Positioned(
            top: 24,
            right: 24,
            child: _PlayerControlButton(
              icon: Icons.close_rounded,
              onTap: () => Navigator.of(context).pop(),
              size: 36,
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
      onKeyEvent: (_, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter)) {
          widget.onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
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
class _TvLyricsPage extends StatefulWidget {
  final PlayerProvider player;
  final Color accent;
  const _TvLyricsPage({required this.player, required this.accent});

  @override
  State<_TvLyricsPage> createState() => _TvLyricsPageState();
}

class _TvLyricsPageState extends State<_TvLyricsPage> {
  final _scroll = ScrollController();
  int _line = 0;
  final Map<int, GlobalKey> _keys = {};

  GlobalKey _keyFor(int i) {
    _keys[i] ??= GlobalKey();
    return _keys[i]!;
  }

  void _centerLine(int idx) {
    final key = _keys[idx];
    if (key == null) return;
    final ctx = key.currentContext;
    if (ctx == null) return;

    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  void _sync({bool forceCenter = false}) {
    if (!mounted) return;
    final lines = widget.player.syncedLines;
    if (lines == null || lines.isEmpty) return;
    final pos = widget.player.position.inMilliseconds;
    int idx = 0;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i]['time'] <= pos) idx = i;
    }
    if (idx != _line || forceCenter) {
      if (idx != _line) setState(() => _line = idx);
      WidgetsBinding.instance.addPostFrameCallback((_) => _centerLine(idx));
    }
  }

  void _onPlayerUpdate() => _sync();

  @override
  void initState() {
    super.initState();
    widget.player.addListener(_onPlayerUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sync(forceCenter: true);
    });
  }

  @override
  void didUpdateWidget(_TvLyricsPage old) {
    super.didUpdateWidget(old);
    if (old.player != widget.player) {
      old.player.removeListener(_onPlayerUpdate);
      widget.player.addListener(_onPlayerUpdate);
    }
    if (old.player.currentSong?.hash != widget.player.currentSong?.hash) {
      _line = 0;
    }
  }

  @override
  void dispose() {
    widget.player.removeListener(_onPlayerUpdate);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final p = widget.player;
    final accent = widget.accent;

    if (p.lyricsLoading) return Center(
      child: CircularProgressIndicator(color: accent, strokeWidth: 2));

    if (p.lyricsSynced && p.syncedLines != null && p.syncedLines!.isNotEmpty) {
      return ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 150),
        itemCount: p.syncedLines!.length,
        itemBuilder: (ctx, i) {
          final active = i == _line;
          final text = p.syncedLines![i]['text'] as String;
          if (text.trim().isEmpty) return const SizedBox(height: 20);
          return Padding(
            key: _keyFor(i),
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 350),
              style: active
                  ? TextStyle(color: accent, fontSize: 26,
                      fontWeight: FontWeight.bold, height: 1.4)
                  : TextStyle(color: Colors.white.withAlpha(55),
                      fontSize: 18, height: 1.4, fontWeight: FontWeight.w600),
              child: Text(text, textAlign: TextAlign.center),
            ),
          );
        },
      );
    }
    
    if (p.unsyncedLines != null && p.unsyncedLines!.isNotEmpty) {
      return SingleChildScrollView(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
        child: Text(p.unsyncedLines!.join('\n'),
          style: const TextStyle(color: Colors.white70, fontSize: 16, height: 2.0),
          textAlign: TextAlign.center));
    }
    
    return const SizedBox.shrink();
  }
}
