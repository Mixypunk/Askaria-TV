import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/services/update_service.dart';
import '../main.dart';
import 'login_tv.dart';
import 'widgets_tv.dart';

// ══════════════════════════════════════════════════════════════════════════════
// Service de MAJ spécifique à Askaria TV
// ══════════════════════════════════════════════════════════════════════════════
class _TvUpdateService {
  static const _owner  = 'Mixypunk';
  static const _repo   = 'Askaria-TV';
  static const _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio()
        ..options.connectTimeout = const Duration(seconds: 10)
        ..options.receiveTimeout = const Duration(seconds: 10);

      final resp = await dio.get(_apiUrl, options: Options(
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        validateStatus: (s) => s != null && s < 500,
      ));

      if (resp.statusCode != 200) return null;
      final data = resp.data as Map<String, dynamic>;

      // Tag: "Askaria-TV-v1.0.42" → version = "1.0.42"
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      if (rawTag.isEmpty) return null;

      final cleaned = rawTag
          .replaceFirst(RegExp(r'^Askaria-TV-v', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
          .split('+').first.trim();

      final info    = await PackageInfo.fromPlatform();
      final current = info.version.split('+').first.trim();

      if (!_isNewer(cleaned, current)) return null;

      final assets = data['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = a['browser_download_url'] as String?;
          break;
        }
      }
      if (apkUrl == null || apkUrl.isEmpty) return null;

      return UpdateInfo(
        version:      cleaned,
        tagName:      rawTag,
        downloadUrl:  apkUrl,
        releaseNotes: data['body'] as String? ?? '',
      );
    } catch (_) { return null; }
  }

  bool _isNewer(String latest, String current) {
    try {
      final l = latest.replaceFirst(RegExp(r'^v'), '').split('.').map(int.parse).toList();
      final c = current.replaceFirst(RegExp(r'^v'), '').split('.').map(int.parse).toList();
      while (l.length < 3) l.add(0);
      while (c.length < 3) c.add(0);
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (_) {}
    return false;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SettingsTvScreen
// ══════════════════════════════════════════════════════════════════════════════
class SettingsTvScreen extends StatefulWidget {
  const SettingsTvScreen({super.key});
  @override
  State<SettingsTvScreen> createState() => _SettingsTvScreenState();
}

class _SettingsTvScreenState extends State<SettingsTvScreen> {
  // ── State ─────────────────────────────────────────────────────────────────
  Map<String, dynamic> _profile = {};
  bool   _loadingProfile = true;
  String _appVersion     = '';
  String _buildNumber    = '';
  String _serverUrl      = '';

  // Audio
  bool   _lossless       = true;
  bool   _crossfadeEnabled = false;
  double _crossfadeSecs  = 3.0;
  bool   _normalizeVolume = false;
  String _audioQuality   = 'auto';   // 'auto' | 'lossless' | 'high' | 'medium'

  // UI
  bool   _animationsEnabled = true;

  // Update
  bool        _checkingUpdate = false;
  UpdateInfo? _updateInfo;
  String?     _updateMsg;
  bool        _updateIsError  = false;

  // Serveur
  bool   _checking = false;
  String? _serverStatus;
  bool   _serverOk = false;

  // Cache
  String _cacheSize = '…';

  @override
  void initState() {
    super.initState();
    _loadAll();
    _computeCacheSize();
  }

  Future<void> _loadAll() async {
    final api   = SwingApiService();
    final prefs = await SharedPreferences.getInstance();
    final info  = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion       = info.version;
        _buildNumber      = info.buildNumber;
        _serverUrl        = api.baseUrl;
        _lossless         = prefs.getBool('audio_lossless')        ?? true;
        _crossfadeEnabled = prefs.getBool('audio_crossfade')       ?? false;
        _crossfadeSecs    = prefs.getDouble('crossfade_secs')      ?? 3.0;
        _normalizeVolume  = prefs.getBool('audio_normalize')       ?? false;
        _audioQuality     = prefs.getString('audio_quality')       ?? 'auto';
        _animationsEnabled= prefs.getBool('animations_enabled')    ?? true;
      });
    }
    try {
      final profile = await api.getMyProfile();
      if (mounted) setState(() { _profile = profile; _loadingProfile = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _computeCacheSize() async {
    try {
      final dir  = await getTemporaryDirectory();
      int total  = 0;
      await for (final f in dir.list(recursive: true)) {
        if (f is File) total += await f.length();
      }
      if (mounted) {
        setState(() => _cacheSize = total > 1024*1024
            ? '${(total / (1024*1024)).toStringAsFixed(1)} Mo'
            : '${(total / 1024).toStringAsFixed(0)} Ko');
      }
    } catch (_) {
      if (mounted) setState(() => _cacheSize = 'Inconnu');
    }
  }

  Future<void> _clearCache() async {
    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
      if (mounted) {
        setState(() => _cacheSize = '0 Ko');
        _showSnack('Cache vidé avec succès', ok: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Erreur : $e');
    }
  }

  Future<void> _setLossless(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_lossless', val);
    if (mounted) setState(() => _lossless = val);
  }

  Future<void> _setCrossfade(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_crossfade', val);
    if (mounted) setState(() => _crossfadeEnabled = val);
  }

  Future<void> _setCrossfadeSecs(double v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('crossfade_secs', v);
    if (mounted) setState(() => _crossfadeSecs = v);
  }

  Future<void> _setNormalize(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_normalize', val);
    if (mounted) setState(() => _normalizeVolume = val);
  }

  Future<void> _setQuality(String q) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('audio_quality', q);
    if (mounted) setState(() => _audioQuality = q);
  }

  Future<void> _setAnimations(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('animations_enabled', v);
    if (mounted) setState(() => _animationsEnabled = v);
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() {
      _checkingUpdate = true;
      _updateMsg = null;
      _updateInfo = null;
      _updateIsError = false;
    });
    try {
      final info = await _TvUpdateService().checkForUpdate();
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
          if (info == null) {
            _updateMsg    = '✓ Vous êtes à jour (v$_appVersion)';
            _updateIsError = false;
          } else {
            _updateInfo = info;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
          _updateMsg      = 'Erreur : $e';
          _updateIsError  = true;
        });
      }
    }
  }

  Future<void> _pingServer() async {
    if (_checking) return;
    setState(() { _checking = true; _serverStatus = null; });
    try {
      final api = SwingApiService();
      final watch = Stopwatch()..start();
      await api.searchSongs('ping_test~qwerty', limit: 1);
      watch.stop();
      if (mounted) {
        setState(() {
          _checking     = false;
          _serverOk     = true;
          _serverStatus = 'Serveur accessible — ${watch.elapsedMilliseconds} ms';
        });
      }
    } catch (_) {
      final api  = SwingApiService();
      final watch = Stopwatch()..start();
      try {
        final dio = Dio();
        await dio.get(api.baseUrl,
            options: Options(validateStatus: (s) => s != null && s < 600));
        watch.stop();
        if (mounted) setState(() {
          _checking = false;
          _serverOk = true;
          _serverStatus = 'Serveur accessible — ${watch.elapsedMilliseconds} ms';
        });
      } catch (e) {
        if (mounted) setState(() {
          _checking = false;
          _serverOk = false;
          _serverStatus = 'Serveur inaccessible : $e';
        });
      }
    }
  }

  Future<void> _logout() async {
    final ok = await _showConfirmDialog(
      'Déconnexion',
      'Voulez-vous vraiment vous déconnecter ?',
    );
    if (!ok || !mounted) return;
    await SwingApiService().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginTvScreen()),
        (_) => false,
      );
    }
  }

  Future<bool> _showConfirmDialog(String title, String msg) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Sp.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler', style: TextStyle(color: Sp.textDim)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Sp.focus),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? const Color(0xFF1D9E75) : const Color(0xFFE24B4A),
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(48, 36, 48, 48),
      children: [
        const Text(
          'Paramètres',
          style: TextStyle(
            fontSize: 32, fontWeight: FontWeight.bold,
            color: Colors.white, letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Version ${'v$_appVersion'}${_buildNumber.isNotEmpty ? "+$_buildNumber" : ""}',
          style: const TextStyle(color: Sp.textDim, fontSize: 14),
        ),
        const SizedBox(height: 32),

        // ── 1. COMPTE ──────────────────────────────────────────────────────
        _TvSection(
          icon: Icons.account_circle_rounded,
          title: 'COMPTE',
          child: _loadingProfile
              ? const SizedBox(height: 80,
                  child: Center(child: CircularProgressIndicator(color: Sp.focus, strokeWidth: 2)))
              : _profile.isEmpty
                  ? const Text('Profil indisponible', style: TextStyle(color: Sp.textDim))
                  : _ProfileCard(profile: _profile, onLogout: _logout),
        ),
        const SizedBox(height: 20),

        // ── 2. MISES À JOUR ────────────────────────────────────────────────
        _TvSection(
          icon: Icons.system_update_rounded,
          title: 'MISES À JOUR',
          child: _UpdateSection(
            appVersion: _appVersion,
            buildNumber: _buildNumber,
            checking: _checkingUpdate,
            updateInfo: _updateInfo,
            updateMsg: _updateMsg,
            updateIsError: _updateIsError,
            onCheck: _checkUpdate,
          ),
        ),
        const SizedBox(height: 20),

        // ── 3. QUALITÉ AUDIO ───────────────────────────────────────────────
        _TvSection(
          icon: Icons.equalizer_rounded,
          title: 'AUDIO',
          child: _AudioSection(
            lossless: _lossless,
            crossfadeEnabled: _crossfadeEnabled,
            crossfadeSecs: _crossfadeSecs,
            normalizeVolume: _normalizeVolume,
            audioQuality: _audioQuality,
            onLossless: _setLossless,
            onCrossfade: _setCrossfade,
            onCrossfadeSecs: _setCrossfadeSecs,
            onNormalize: _setNormalize,
            onQuality: _setQuality,
          ),
        ),
        const SizedBox(height: 20),

        // ── 4. AFFICHAGE ──────────────────────────────────────────────────
        _TvSection(
          icon: Icons.palette_rounded,
          title: 'AFFICHAGE',
          child: Column(
            children: [
              _SettingRow(
                label: 'Animations',
                description: 'Effets de transition et d\'animation (désactiver pour améliorer les performances)',
                trailing: TvSwitch(value: _animationsEnabled, onChanged: _setAnimations),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── 5. SERVEUR ─────────────────────────────────────────────────────
        _TvSection(
          icon: Icons.dns_rounded,
          title: 'SERVEUR',
          child: _ServerSection(
            serverUrl: _serverUrl,
            checking: _checking,
            serverStatus: _serverStatus,
            serverOk: _serverOk,
            onPing: _pingServer,
          ),
        ),
        const SizedBox(height: 20),

        // ── 6. STOCKAGE & CACHE ────────────────────────────────────────────
        _TvSection(
          icon: Icons.storage_rounded,
          title: 'STOCKAGE',
          child: Column(
            children: [
              _SettingRow(
                label: 'Cache temporaire',
                description: 'Taille des fichiers temporaires',
                trailing: Row(
                  children: [
                    Text(_cacheSize,
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                    const SizedBox(width: 20),
                    TvButton(
                      label: 'Vider',
                      onTap: _clearCache,
                      icon: Icons.delete_sweep_rounded,
                      outlined: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── 7. À PROPOS ────────────────────────────────────────────────────
        _TvSection(
          icon: Icons.info_outline_rounded,
          title: 'À PROPOS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow('Application', 'Askaria TV'),
              _InfoRow('Version', 'v$_appVersion+$_buildNumber'),
              _InfoRow('Développeur', 'Mixypunk'),
              _InfoRow('Plateforme', 'Android TV / Leanback'),
              _InfoRow('Repo', 'github.com/Mixypunk/Askaria-TV'),
              const SizedBox(height: 16),
              const Divider(color: Colors.white12),
              const SizedBox(height: 12),
              const Text(
                '© 2024–2025 Askaria Music. Tous droits réservés.',
                style: TextStyle(color: Sp.textDim, fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),

        // ── Bouton déconnexion ─────────────────────────────────────────────
        Center(
          child: TvButton(
            label: 'Se déconnecter',
            onTap: _logout,
            danger: true,
            icon: Icons.logout_rounded,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section container
// ══════════════════════════════════════════════════════════════════════════════
class _TvSection extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Widget   child;
  const _TvSection({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Sp.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: Sp.focus, size: 16),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(
              color: Sp.textDim, fontSize: 11,
              fontWeight: FontWeight.bold, letterSpacing: 1.4,
            )),
          ]),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ProfileCard
// ══════════════════════════════════════════════════════════════════════════════
class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  final VoidCallback onLogout;
  const _ProfileCard({required this.profile, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final username = (profile['username'] ?? profile['name'] ?? '').toString();
    final email    = (profile['email'] ?? '').toString();
    final role     = (profile['role']  ?? profile['type'] ?? '').toString();
    final initial  = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Row(
      children: [
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(colors: [Sp.g1, Sp.g3],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: Center(child: Text(initial, style: const TextStyle(
            color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 22),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(username.isNotEmpty ? username : '—',
                style: const TextStyle(color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
            if (email.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.email_outlined, size: 14, color: Sp.textDim),
                const SizedBox(width: 6),
                Text(email, style: const TextStyle(color: Sp.textDim, fontSize: 14)),
              ]),
            ],
            if (role.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Sp.focus.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Sp.focus.withOpacity(0.4)),
                ),
                child: Text(role.toUpperCase(), style: const TextStyle(
                  color: Sp.focus, fontSize: 11,
                  fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              ),
            ],
          ],
        )),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _UpdateSection
// ══════════════════════════════════════════════════════════════════════════════
class _UpdateSection extends StatefulWidget {
  final String      appVersion;
  final String      buildNumber;
  final bool        checking;
  final UpdateInfo? updateInfo;
  final String?     updateMsg;
  final bool        updateIsError;
  final VoidCallback onCheck;

  const _UpdateSection({
    required this.appVersion,
    required this.buildNumber,
    required this.checking,
    required this.updateInfo,
    required this.updateMsg,
    required this.updateIsError,
    required this.onCheck,
  });
  @override
  State<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<_UpdateSection> {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Askaria TV', style: TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              'Installé : v${widget.appVersion}'
              '${widget.buildNumber.isNotEmpty ? "+${widget.buildNumber}" : ""}',
              style: const TextStyle(color: Sp.textDim, fontSize: 14)),
            const SizedBox(height: 2),
            const Text('Source : github.com/Mixypunk/Askaria-TV',
                style: TextStyle(color: Sp.textDim, fontSize: 12)),
          ],
        )),
        TvButton(
          label: 'Vérifier',
          loading: widget.checking,
          onTap: widget.onCheck,
          icon: Icons.refresh_rounded,
          autoFocus: true,
        ),
      ]),

      // Message de statut
      if (widget.updateMsg != null) ...[
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: (widget.updateIsError
                ? const Color(0xFFE24B4A)
                : const Color(0xFF1D9E75)).withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: widget.updateIsError
                ? const Color(0xFFE24B4A) : const Color(0xFF1D9E75),
                width: 1),
          ),
          child: Row(children: [
            Icon(widget.updateIsError
                ? Icons.error_outline_rounded
                : Icons.check_circle_rounded,
              color: widget.updateIsError
                  ? const Color(0xFFE24B4A) : const Color(0xFF1D9E75),
              size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(widget.updateMsg!, style: TextStyle(
              color: widget.updateIsError
                  ? const Color(0xFFE24B4A) : const Color(0xFF1D9E75),
              fontSize: 14))),
          ]),
        ),
      ],

      // Nouvelle version disponible
      if (widget.updateInfo != null) ...[
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Sp.g1, Sp.g2],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            const Icon(Icons.new_releases_rounded, color: Colors.white, size: 32),
            const SizedBox(width: 16),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Version ${widget.updateInfo!.version} disponible !',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                const Text('Téléchargement et installation automatiques.',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            )),
            const SizedBox(width: 16),
            TvButton(
              label: 'Mettre à jour',
              icon: Icons.download_rounded,
              autoFocus: true,
              onTap: () => _TvUpdateDialog.show(context, widget.updateInfo!),
            ),
          ]),
        ),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _AudioSection
// ══════════════════════════════════════════════════════════════════════════════
class _AudioSection extends StatelessWidget {
  final bool   lossless;
  final bool   crossfadeEnabled;
  final double crossfadeSecs;
  final bool   normalizeVolume;
  final String audioQuality;
  final ValueChanged<bool>   onLossless;
  final ValueChanged<bool>   onCrossfade;
  final ValueChanged<double> onCrossfadeSecs;
  final ValueChanged<bool>   onNormalize;
  final ValueChanged<String> onQuality;

  const _AudioSection({
    required this.lossless,
    required this.crossfadeEnabled,
    required this.crossfadeSecs,
    required this.normalizeVolume,
    required this.audioQuality,
    required this.onLossless,
    required this.onCrossfade,
    required this.onCrossfadeSecs,
    required this.onNormalize,
    required this.onQuality,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _SettingRow(
        label: 'Lecture Lossless',
        description: 'FLAC / WAV — bitrate original sans compression',
        badge: lossless ? 'ACTIVÉ' : null,
        trailing: TvSwitch(value: lossless, onChanged: onLossless),
      ),
      const SizedBox(height: 20),
      _SettingRow(
        label: 'Normalisation du volume',
        description: 'Égalise le niveau sonore entre les titres',
        trailing: TvSwitch(value: normalizeVolume, onChanged: onNormalize),
      ),
      const SizedBox(height: 20),
      _SettingRow(
        label: 'Crossfade',
        description: 'Fondu enchaîné entre les titres',
        trailing: TvSwitch(value: crossfadeEnabled, onChanged: onCrossfade),
      ),
      if (crossfadeEnabled) ...[
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(children: [
            const Icon(Icons.tune_rounded, color: Sp.textDim, size: 16),
            const SizedBox(width: 10),
            Text('Durée : ${crossfadeSecs.toStringAsFixed(1)} s',
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            const SizedBox(width: 16),
            Expanded(
              child: SliderTheme(
                data: const SliderThemeData(
                  activeTrackColor: Sp.focus,
                  thumbColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  trackHeight: 4,
                ),
                child: Slider(
                  value: crossfadeSecs,
                  min: 1, max: 10, divisions: 9,
                  onChanged: onCrossfadeSecs,
                ),
              ),
            ),
          ]),
        ),
      ],
      const SizedBox(height: 20),
      // Qualité audio
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Qualité de streaming',
            style: TextStyle(color: Colors.white, fontSize: 17,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        const Text('Choisir selon la bande passante',
            style: TextStyle(color: Sp.textDim, fontSize: 13)),
        const SizedBox(height: 12),
        Row(children: [
          for (final q in ['auto', 'lossless', 'high', 'medium'])
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _QualityChip(
                label: q[0].toUpperCase() + q.substring(1),
                selected: audioQuality == q,
                onTap: () => onQuality(q),
              ),
            ),
        ]),
      ]),
    ]);
  }
}

class _QualityChip extends StatefulWidget {
  final String label;
  final bool   selected;
  final VoidCallback onTap;
  const _QualityChip({required this.label, required this.selected, required this.onTap});
  @override
  State<_QualityChip> createState() => _QualityChipState();
}
class _QualityChipState extends State<_QualityChip> {
  bool _hasFocus = false;
  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      onKeyEvent: (_, event) => handleDpadSelect(event, widget.onTap),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: widget.selected ? Sp.focus : (_hasFocus ? Colors.white12 : Colors.transparent),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _hasFocus ? Colors.white : (widget.selected ? Sp.focus : Colors.white24),
              width: _hasFocus ? 2 : 1,
            ),
          ),
          child: Text(widget.label, style: TextStyle(
            color: widget.selected || _hasFocus ? Colors.white : Sp.textDim,
            fontWeight: widget.selected ? FontWeight.bold : FontWeight.normal,
            fontSize: 15,
          )),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _ServerSection
// ══════════════════════════════════════════════════════════════════════════════
class _ServerSection extends StatelessWidget {
  final String  serverUrl;
  final bool    checking;
  final String? serverStatus;
  final bool    serverOk;
  final VoidCallback onPing;

  const _ServerSection({
    required this.serverUrl,
    required this.checking,
    required this.serverStatus,
    required this.serverOk,
    required this.onPing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.link_rounded, color: Sp.focus, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          serverUrl.isEmpty ? 'Non configuré' : serverUrl,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        )),
        const SizedBox(width: 20),
        TvButton(
          label: 'Ping',
          loading: checking,
          onTap: onPing,
          icon: Icons.network_check_rounded,
          outlined: true,
        ),
      ]),
      if (serverStatus != null) ...[
        const SizedBox(height: 12),
        Row(children: [
          Icon(serverOk ? Icons.check_circle_rounded : Icons.error_rounded,
              color: serverOk ? const Color(0xFF1D9E75) : const Color(0xFFE24B4A),
              size: 18),
          const SizedBox(width: 8),
          Flexible(child: Text(serverStatus!, style: TextStyle(
            color: serverOk ? const Color(0xFF1D9E75) : const Color(0xFFE24B4A),
            fontSize: 14))),
        ]),
      ],
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets utilitaires settings
// ══════════════════════════════════════════════════════════════════════════════
class _SettingRow extends StatelessWidget {
  final String  label;
  final String? description;
  final String? badge;
  final Widget  trailing;
  const _SettingRow({
    required this.label,
    this.description,
    this.badge,
    required this.trailing,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Text(label, style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
              if (badge != null) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Sp.focus.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Sp.focus),
                  ),
                  child: Text(badge!, style: const TextStyle(
                      color: Sp.focus, fontSize: 10,
                      fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                ),
              ],
            ]),
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(description!, style: const TextStyle(
                  color: Sp.textDim, fontSize: 13)),
            ],
          ],
        )),
        const SizedBox(width: 24),
        trailing,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 160,
            child: Text(label, style: const TextStyle(color: Sp.textDim, fontSize: 14))),
        Expanded(child: Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w500))),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _TvUpdateDialog — dialogue de MAJ adapté D-Pad TV
// ══════════════════════════════════════════════════════════════════════════════
class _TvUpdateDialog extends StatefulWidget {
  final UpdateInfo info;
  const _TvUpdateDialog({required this.info});

  static Future<void> show(BuildContext context, UpdateInfo info) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TvUpdateDialog(info: info),
    );
  }

  @override
  State<_TvUpdateDialog> createState() => _TvUpdateDialogState();
}

class _TvUpdateDialogState extends State<_TvUpdateDialog> {
  _DlStep _step = _DlStep.idle;
  String? _error;
  final _progress = ValueNotifier<double>(0);

  @override
  void dispose() { _progress.dispose(); super.dispose(); }

  Future<void> _startUpdate() async {
    setState(() { _step = _DlStep.downloading; _error = null; });
    try {
      final svc = UpdateService();
      final path = await svc.downloadApk(widget.info, _progress);
      if (mounted) setState(() => _step = _DlStep.installing);
      await svc.installApk(path);
      if (mounted) setState(() => _step = _DlStep.done);
    } catch (e) {
      if (mounted) setState(() { _step = _DlStep.idle; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      title: Row(children: [
        const Icon(Icons.system_update_rounded, color: Sp.focus, size: 30),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mise à jour disponible',
                style: TextStyle(color: Colors.white, fontSize: 20)),
            Text('Version ${widget.info.version}',
                style: const TextStyle(color: Sp.focus, fontSize: 14)),
          ],
        )),
      ]),
      content: SizedBox(
        width: 600,
        child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_step == _DlStep.idle)
              const Text('Télécharger et installer la mise à jour ?',
                  style: TextStyle(color: Sp.textDim, fontSize: 16)),

            if (_step == _DlStep.downloading) ...[
              const Text('Téléchargement en cours…',
                  style: TextStyle(color: Sp.textDim, fontSize: 16)),
              const SizedBox(height: 16),
              ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (_, v, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: v > 0 ? v : null,
                        backgroundColor: Colors.white12,
                        valueColor: const AlwaysStoppedAnimation(Sp.focus),
                        minHeight: 8)),
                    const SizedBox(height: 8),
                    Text(v > 0 ? '${(v * 100).toStringAsFixed(0)} %' : '…',
                        style: const TextStyle(color: Sp.textDim, fontSize: 14)),
                  ],
                ),
              ),
            ],

            if (_step == _DlStep.installing)
              const Row(children: [
                SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Sp.focus, strokeWidth: 2)),
                SizedBox(width: 12),
                Text('Lancement de l\'installation…',
                    style: TextStyle(color: Sp.textDim, fontSize: 16)),
              ]),

            if (_step == _DlStep.done)
              const Row(children: [
                Icon(Icons.check_circle_rounded, color: Color(0xFF1D9E75), size: 24),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Installation lancée — suivez les instructions Android.',
                  style: TextStyle(color: Color(0xFF1D9E75), fontSize: 15))),
              ]),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(
                  color: Color(0xFFE24B4A), fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        if (_step == _DlStep.idle) ...[
          TextButton(
            focusColor: Colors.white12,
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard', style: TextStyle(color: Sp.textDim, fontSize: 15)),
          ),
          const SizedBox(width: 8),
          TvButton(label: 'Mettre à jour', autoFocus: true,
              icon: Icons.download_rounded, onTap: _startUpdate),
        ],
        if (_step == _DlStep.done)
          TvButton(label: 'Fermer', autoFocus: true,
              onTap: () => Navigator.pop(context)),
      ],
    );
  }
}

enum _DlStep { idle, downloading, installing, done }
