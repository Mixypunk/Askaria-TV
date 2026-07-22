import 'package:flutter/material.dart';
import '../main.dart';
import '../core/services/api_service.dart';
import 'widgets_tv.dart';

class StatsTvScreen extends StatefulWidget {
  const StatsTvScreen({super.key});

  @override
  State<StatsTvScreen> createState() => _StatsTvScreenState();
}

class _StatsTvScreenState extends State<StatsTvScreen> {
  final api = SwingApiService();
  bool _loading = true;
  String _period = 'all'; // all, month, week

  Map<String, dynamic> _overview = {};
  List<dynamic> _topTracks = [];
  List<dynamic> _topArtists = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final futures = await Future.wait([
        api.getStatsOverview(),
        api.getTopTracks(limit: 10, period: _period),
        api.getTopArtists(limit: 10, period: _period),
        api.getHeatmap(),
        api.getDailyStats(days: 7),
        api.getTopGenres(),
      ]);

      _overview = futures[0] as Map<String, dynamic>;
      _topTracks = (futures[1] as Map<String, dynamic>)['tracks'] ?? [];
      _topArtists = (futures[2] as Map<String, dynamic>)['artists'] ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return TvPage(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Statistiques'),
          actions: [
            _buildPeriodChip('all', 'Tout'),
            _buildPeriodChip('month', 'Mois'),
            _buildPeriodChip('week', 'Semaine'),
            const SizedBox(width: 20),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Sp.focus))
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildOverviewCards(),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            const TvSectionHeader(title: 'Top Titres'),
                            ..._topTracks.map((t) => TvListTile(
                                  title: t['title'] ?? '',
                                  subtitle: t['artist'] ?? '',
                                  leading: TvArtworkImage(
                                      url: api.getArtworkUrl(t['image'] ?? ''),
                                      size: 40),
                                  onTap: () {
                                    // Handle play
                                  },
                                )),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            const TvSectionHeader(title: 'Top Artistes'),
                            ..._topArtists.map((a) => TvListTile(
                                  title: a['name'] ?? '',
                                  subtitle: '${a['play_count'] ?? 0} lectures',
                                  onTap: () {},
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPeriodChip(String id, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TvButton(
        label: label,
        outlined: _period != id,
        onTap: () {
          if (_period != id) {
            setState(() => _period = id);
            _loadData();
          }
        },
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        _buildCard('Lectures', '${_overview['total_plays'] ?? 0}', Sp.g1),
        const SizedBox(width: 16),
        _buildCard('Heures', '${_overview['total_hours'] ?? 0}', Sp.g2),
        const SizedBox(width: 16),
        _buildCard('Titres', '${_overview['total_songs'] ?? 0}', Sp.g3),
        const SizedBox(width: 16),
        _buildCard('Artistes', '${_overview['total_artists'] ?? 0}', Sp.focus),
      ],
    );
  }

  Widget _buildCard(String title, String value, Color color) {
    return Expanded(
      child: TvFocusCard(
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.8), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 8),
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
