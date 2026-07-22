import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/services/api_service.dart';
import '../core/models/song.dart';
import '../core/providers/player_provider.dart';
import 'widgets_tv.dart';

class DecadesTvScreen extends StatefulWidget {
  const DecadesTvScreen({super.key});

  @override
  State<DecadesTvScreen> createState() => _DecadesTvScreenState();
}

class _DecadesTvScreenState extends State<DecadesTvScreen> {
  final api = SwingApiService();
  bool _loading = true;
  List<Map<String, dynamic>> _decades = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _decades = await api.getDecades();
    if (mounted) setState(() => _loading = false);
  }

  Color _getColorForDecade(String name) {
    if (name.contains('60')) return Colors.orange;
    if (name.contains('70')) return Colors.deepPurple;
    if (name.contains('80')) return Colors.pinkAccent;
    if (name.contains('90')) return Colors.cyan;
    if (name.contains('2000')) return Colors.blueAccent;
    if (name.contains('2010')) return Colors.teal;
    return Sp.focus;
  }

  @override
  Widget build(BuildContext context) {
    return TvPage(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Décennies'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Sp.focus))
            : GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2.0,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _decades.length,
                itemBuilder: (ctx, i) {
                  final decade = _decades[i];
                  final name = decade['name']?.toString() ?? 'Inconnu';
                  final count = decade['track_count'] ?? decade['count'] ?? 0;
                  final color = _getColorForDecade(name);

                  return TvFocusCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DecadeTracksTvScreen(decade: name),
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
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$count titres',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.white70),
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

class DecadeTracksTvScreen extends StatefulWidget {
  final String decade;
  const DecadeTracksTvScreen({super.key, required this.decade});

  @override
  State<DecadeTracksTvScreen> createState() => _DecadeTracksTvScreenState();
}

class _DecadeTracksTvScreenState extends State<DecadeTracksTvScreen> {
  final api = SwingApiService();
  bool _loading = true;
  List<Song> _tracks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    _tracks = await api.getDecadeTracks(widget.decade);
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return TvPage(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Décennie: ${widget.decade}'),
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
