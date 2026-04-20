import 'package:flutter/material.dart';
import '../main.dart';
import '../core/services/api_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// TvFocusCard — carte générique focusable (albums, artistes, playlists)
// ══════════════════════════════════════════════════════════════════════════════
class TvFocusCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final bool autoFocus;
  final Color? glowColor;

  const TvFocusCard({
    super.key,
    required this.child,
    required this.onTap,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.autoFocus = false,
    this.glowColor,
  });

  @override
  State<TvFocusCard> createState() => _TvFocusCardState();
}

class _TvFocusCardState extends State<TvFocusCard>
    with SingleTickerProviderStateMixin {
  bool _hasFocus = false;
  late AnimationController _anim;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onFocus(bool f) {
    setState(() => _hasFocus = f);
    if (f) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final glow = widget.glowColor ?? Sp.focus;
    return Focus(
      autofocus: widget.autoFocus,
      onFocusChange: _onFocus,
      child: GestureDetector(
        onTap: widget.onTap,
        child: ScaleTransition(
          scale: _scale,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: _hasFocus ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: _hasFocus
                  ? [BoxShadow(color: glow.withOpacity(0.5), blurRadius: 24)]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TvNavItem — élément sidebar avec icône + label (rétractable)
// ══════════════════════════════════════════════════════════════════════════════
class TvNavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool expanded;
  final VoidCallback onTap;

  const TvNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.expanded,
    required this.onTap,
  });

  @override
  State<TvNavItem> createState() => _TvNavItemState();
}

class _TvNavItemState extends State<TvNavItem> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = Sp.g1;
    final iconColor = widget.active
        ? activeColor
        : (_hasFocus ? Colors.white : Sp.textDim);
    final bg = widget.active
        ? activeColor.withOpacity(0.15)
        : (_hasFocus ? Colors.white.withOpacity(0.08) : Colors.transparent);

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          padding: EdgeInsets.symmetric(
            horizontal: widget.expanded ? 16 : 12,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: widget.active ? activeColor : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: widget.expanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 26, color: iconColor),
              if (widget.expanded) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 16,
                      fontWeight: widget.active
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TvListTile — ligne de liste pour titres, playlists, etc.
// ══════════════════════════════════════════════════════════════════════════════
class TvListTile extends StatefulWidget {
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool isActive;
  final bool autoFocus;

  const TvListTile({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    required this.onTap,
    this.isActive = false,
    this.autoFocus = false,
  });

  @override
  State<TvListTile> createState() => _TvListTileState();
}

class _TvListTileState extends State<TvListTile> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: widget.autoFocus,
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: _hasFocus
                ? Colors.white.withOpacity(0.12)
                : (widget.isActive
                    ? Sp.focus.withOpacity(0.12)
                    : Sp.surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.transparent,
              width: 2,
            ),
            boxShadow: _hasFocus
                ? [BoxShadow(color: Sp.focus.withOpacity(0.3), blurRadius: 12)]
                : [],
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[
                widget.leading!,
                const SizedBox(width: 18),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        color: widget.isActive ? Sp.focus : Colors.white,
                        fontSize: 18,
                        fontWeight: widget.isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        style: TextStyle(
                          color: _hasFocus ? Colors.white70 : Sp.textDim,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 12),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TvSectionHeader — titre de section avec bouton "Tout voir" optionnel
// ══════════════════════════════════════════════════════════════════════════════
class TvSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;

  const TvSectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            _SeeAllBtn(onTap: onSeeAll!),
        ],
      ),
    );
  }
}

class _SeeAllBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _SeeAllBtn({required this.onTap});
  @override
  State<_SeeAllBtn> createState() => _SeeAllBtnState();
}

class _SeeAllBtnState extends State<_SeeAllBtn> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _hasFocus ? Colors.white.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hasFocus ? Colors.white : Colors.white24,
            ),
          ),
          child: Text(
            'Tout voir',
            style: TextStyle(
              color: _hasFocus ? Colors.white : Sp.textDim,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TvArtworkImage — image réseau avec fallback icône
// ══════════════════════════════════════════════════════════════════════════════
class TvArtworkImage extends StatelessWidget {
  final String url;
  final double size;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  const TvArtworkImage({
    super.key,
    required this.url,
    required this.size,
    this.borderRadius,
    this.fallbackIcon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final br = borderRadius ?? BorderRadius.circular(8);
    return ClipRRect(
      borderRadius: br,
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        headers: SwingApiService().authHeaders,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: Sp.surface,
          child: Icon(fallbackIcon, color: Colors.white24, size: size * 0.4),
        ),
      ),
    );
  }
}
