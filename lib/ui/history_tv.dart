import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../core/services/api_service.dart';
import '../core/models/song.dart';
import '../core/providers/player_provider.dart';
import 'widgets_tv.dart';

class HistoryTvScreen extends StatefulWidget {
  const HistoryTvScreen({super.key});

  @override
  State<HistoryTvScreen> createState() => _HistoryTvScreenState();
}

class _HistoryTvScreenState extends State<HistoryTvScreen> {
  final api = SwingApiService();
  bool _loading = true;
  List<dynamic> _history = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await api.getHistory(limit: 50);
    _history = data['items'] ?? data['history'] ?? [];
    if (mounted) setState(() => _loading = false);
  }

  String _formatRelativeTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'il y a ${diff.inHours}h';
      if (diff.inDays == 1) return 'hier';
      return 'il y a ${diff.inDays} jours';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return TvPage(
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Écoutés récemment'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: Sp.focus))
            : ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: _history.length,
                itemBuilder: (ctx, i) {
                  final item = _history[i];
                  final trackMap = item['track'] ?? item;
                  final playedAt = item['played_at'];
                  final t = Song.fromJson(trackMap);

                  return TvListTile(
                    title: t.title,
                    subtitle: '${t.artist} • ${_formatRelativeTime(playedAt)}',
                    leading: TvArtworkImage(
                        url: api.getArtworkUrl(t.image ?? ''), size: 40),
                    onTap: () {
                      context.read<PlayerProvider>().playSong(t, queue: [t], index: 0);
                    },
                  );
                },
              ),
      ),
    );
  }
}
