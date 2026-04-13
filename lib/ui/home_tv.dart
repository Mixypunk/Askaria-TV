import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/models/album.dart';
import '../main.dart';
import 'settings_tv.dart';
import 'album_tv.dart';
import 'library_tv.dart';
import 'search_tv.dart';
import 'player_bar_tv.dart';

// Indices onglets
const _kHome     = 0;
const _kSearch   = 1;
const _kLibrary  = 2;
const _kSettings = 3;

class HomeTvScreen extends StatefulWidget {
  const HomeTvScreen({super.key});

  @override
  State<HomeTvScreen> createState() => _HomeTvScreenState();
}

class _HomeTvScreenState extends State<HomeTvScreen> {
  int _selectedTab = _kHome;

  List<Album> _albums  = [];
  bool        _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await SwingApiService().getAlbums(limit: 50);
      if (mounted) setState(() { _albums = res; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildContent() {
    switch (_selectedTab) {
      case _kSettings:
        return const _EmbeddedSettings();
      case _kSearch:
        return const SearchTvScreen();
      case _kLibrary:
        return const LibraryTvScreen();
      default:
        return _HomeContent(albums: _albums, loading: _loading);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── Sidebar navigation ─────────────────────────────────────────
          Container(
            width: 80,
            color: Sp.surface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TvNavIcon(
                  icon:   Icons.home_filled,
                  active: _selectedTab == _kHome,
                  onTap:  () => setState(() => _selectedTab = _kHome),
                ),
                const SizedBox(height: 24),
                _TvNavIcon(
                  icon:   Icons.search,
                  active: _selectedTab == _kSearch,
                  onTap:  () => setState(() => _selectedTab = _kSearch),
                ),
                const SizedBox(height: 24),
                _TvNavIcon(
                  icon:   Icons.library_music,
                  active: _selectedTab == _kLibrary,
                  onTap:  () => setState(() => _selectedTab = _kLibrary),
                ),
                const SizedBox(height: 24),
                _TvNavIcon(
                  icon:   Icons.settings,
                  active: _selectedTab == _kSettings,
                  onTap:  () => setState(() => _selectedTab = _kSettings),
                ),
              ],
            ),
          ),

          // ── Contenu principal ─────────────────────────────────────────────
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildContent()),
                const MiniPlayerTv(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contenu Accueil ───────────────────────────────────────────────────────────
class _HomeContent extends StatelessWidget {
  final List<Album> albums;
  final bool        loading;
  const _HomeContent({required this.albums, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Récemment ajoutés',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(color: Sp.focus))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: albums.length,
                    itemBuilder: (context, index) {
                      return _TvAlbumCard(album: albums[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Placeholder pour onglets à venir ─────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _PlaceholderTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: Sp.textDim),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              fontSize: 22,
              color: Sp.textDim,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bientôt disponible',
            style: TextStyle(fontSize: 15, color: Sp.textDim),
          ),
        ],
      ),
    );
  }
}

// ── Settings intégré directement dans l'Expanded de HomeTvScreen ────────────
// SettingsTvScreen retourne un ListView (sans Scaffold ni sidebar propre)
class _EmbeddedSettings extends StatelessWidget {
  const _EmbeddedSettings();

  @override
  Widget build(BuildContext context) => const SettingsTvScreen();
}

// ── Icône de nav sidebar ──────────────────────────────────────────────────────
class _TvNavIcon extends StatefulWidget {
  final IconData     icon;
  final bool         active;
  final VoidCallback onTap;
  const _TvNavIcon({
    required this.icon,
    required this.active,
    required this.onTap,
  });

  @override
  State<_TvNavIcon> createState() => _TvNavIconState();
}

class _TvNavIconState extends State<_TvNavIcon> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(40),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56, height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.active
              ? Sp.focus.withOpacity(0.2)
              : (_hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent),
          border: widget.active
              ? Border.all(color: Sp.focus, width: 2)
              : (_hasFocus ? Border.all(color: Colors.white, width: 2) : null),
        ),
        child: Icon(
          widget.icon,
          size: 28,
          color: widget.active
              ? Sp.focus
              : (_hasFocus ? Colors.white : Sp.textDim),
        ),
      ),
    );
  }
}

// ── Carte album ───────────────────────────────────────────────────────────────
class _TvAlbumCard extends StatefulWidget {
  final Album album;
  const _TvAlbumCard({required this.album});

  @override
  State<_TvAlbumCard> createState() => _TvAlbumCardState();
}

class _TvAlbumCardState extends State<_TvAlbumCard> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final artwork =
        '${SwingApiService().baseUrl}/img/thumbnail/${widget.album.image}';

    return RepaintBoundary(
      child: InkWell(
        onFocusChange: (f) => setState(() => _hasFocus = f),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AlbumTvScreen(album: widget.album),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 180,
          margin: const EdgeInsets.only(right: 24),
          transform: _hasFocus
              ? (Matrix4.identity()..scale(1.05))
              : Matrix4.identity(),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: _hasFocus
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: _hasFocus
                ? [BoxShadow(
                    color: Sp.focus.withOpacity(0.5),
                    blurRadius: 20)]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  artwork,
                  width: 180, height: 180,
                  fit: BoxFit.cover,
                  cacheWidth: 360, cacheHeight: 360,
                  headers: SwingApiService().authHeaders,
                  errorBuilder: (_, __, ___) => Container(
                    width: 180, height: 180,
                    color: Sp.surface,
                    child: const Icon(Icons.album, size: 64),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.album.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _hasFocus ? Colors.white : Sp.textDim,
                ),
              ),
              Text(
                widget.album.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Sp.textDim),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
