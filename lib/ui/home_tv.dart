import 'package:flutter/material.dart';
import '../core/services/api_service.dart';
import '../core/models/album.dart';
import '../main.dart';

class HomeTvScreen extends StatefulWidget {
  const HomeTvScreen({super.key});
  @override
  State<HomeTvScreen> createState() => _HomeTvScreenState();
}

class _HomeTvScreenState extends State<HomeTvScreen> {
  List<Album> _albums = [];
  bool _loading = true;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // SIDEBAR (Navigation TV)
          Container(
            width: 80,
            color: Sp.surface,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TvNavIcon(icon: Icons.home_filled, active: true, onTap: () {}),
                const SizedBox(height: 24),
                _TvNavIcon(icon: Icons.search, active: false, onTap: () {}),
                const SizedBox(height: 24),
                _TvNavIcon(icon: Icons.library_music, active: false, onTap: () {}),
                const SizedBox(height: 24),
                _TvNavIcon(icon: Icons.settings, active: false, onTap: () {}),
              ],
            ),
          ),
          
          // CONTENU (Leanback Grid/List horizontales)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Récemment ajoutés', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 24),
                  
                  Expanded(
                    child: _loading 
                    ? const Center(child: CircularProgressIndicator(color: Sp.focus))
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _albums.length,
                        itemBuilder: (context, index) {
                          return _TvAlbumCard(album: _albums[index]);
                        },
                      ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvNavIcon extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback onTap;
  const _TvNavIcon({required this.icon, required this.active, required this.onTap});

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
          color: _hasFocus ? Colors.white.withOpacity(0.1) : Colors.transparent,
          border: _hasFocus ? Border.all(color: Colors.white, width: 2) : null,
        ),
        child: Icon(widget.icon, size: 28, color: widget.active ? Sp.focus : (_hasFocus ? Colors.white : Sp.textDim)),
      ),
    );
  }
}

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
    final artwork = '${SwingApiService().baseUrl}/img/thumbnail/${widget.album.image}';

    return InkWell(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onTap: () {
        // Todo: Ouvrir la vue de l'album
      },
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 180,
        margin: const EdgeInsets.only(right: 24),
        transform: _hasFocus ? (Matrix4.identity()..scale(1.05)) : Matrix4.identity(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: _hasFocus ? Border.all(color: Colors.white, width: 3) : null,
          boxShadow: _hasFocus ? [BoxShadow(color: Sp.focus.withOpacity(0.5), blurRadius: 20)] : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             ClipRRect(
               borderRadius: BorderRadius.circular(12),
               child: Image.network(
                  artwork, width: 180, height: 180, fit: BoxFit.cover,
                  headers: SwingApiService().authHeaders,
                  errorBuilder: (_,__,___) => Container(width: 180, height: 180, color: Sp.surface, child: const Icon(Icons.album, size: 64)),
               ),
             ),
             const SizedBox(height: 12),
             Text(widget.album.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _hasFocus ? Colors.white : Sp.textDim)),
             Text(widget.album.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, color: Sp.textDim)),
          ],
        ),
      ),
    );
  }
}
