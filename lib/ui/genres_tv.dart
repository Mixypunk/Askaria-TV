import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/services/api_service.dart';
import '../core/models/song.dart';
import '../core/providers/player_provider.dart';
import 'widgets_tv.dart';

class GenresTvScreen extends StatefulWidget {
  const GenresTvScreen({super.key});

  @override
  State<GenresTvScreen> createState() => _GenresTvScreenState();
}

class _GenresTvScreenState extends State<GenresTvScreen> {
  final api = SwingApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _genres = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _genres = await api.getGenres();
    if (mounted) setState(() => _loading = false);
  }

  Color _getColorForGenre(String name) {
    final hash = name.hashCode;
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.7, 0.4).toColor();
  }

  @override
  Widget build(BuildContext context) {
    return TvPage(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Genres'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Sp.focus))
            : GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _genres.length,
                itemBuilder: (ctx, i) {
                  final genre = _genres[i];
                  final name = genre['name']?.toString() ?? 'Inconnu';
                  final count = genre['track_count'] ?? genre['count'] ?? 0;
                  final color = _getColorForGenre(name);

                  return TvFocusCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GenreTracksTvScreen(genre: name),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color.withOpacity(0.8), color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$count titres',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class GenreTracksTvScreen extends StatefulWidget {
  final String genre;
  const GenreTracksTvScreen({super.key, required this.genre});

  @override
  State<GenreTracksTvScreen> createState() => _GenreTracksTvScreenState();
}

class _GenreTracksTvScreenState extends State<GenreTracksTvScreen> {
  final api = SwingApiService();
  bool _loading = true;
  List<Song> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _tracks = await api.getGenreTracks(widget.genre);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return TvPage(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Genre: ${widget.genre}'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Sp.focus))
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _tracks.length,
                itemBuilder: (ctx, i) {
                  final t = _tracks[i];
                  return TvListTile(
                    title: t.title,
                    subtitle: t.artist,
                    leading: TvArtworkImage(
                      url: api.getArtworkUrl(t.image ?? ''), size: 40),
                    onTap: () {
                      context.read<PlayerProvider>().playSong(t, queue: _tracks, index: i);
                    },
                  );
                },
              ),
      ),
    );
  }
}
