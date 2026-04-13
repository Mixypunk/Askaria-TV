import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/services/api_service.dart';
import '../core/services/update_service.dart';
import '../main.dart';
import 'login_tv.dart';

// ── TV Update Service (repo Askaria-TV) ──────────────────────────────────────
// Séparé de l'UpdateService mobile qui pointe sur askaria-Music
class _TvUpdateService {
  static const _owner  = 'Mixypunk';
  static const _repo   = 'Askaria-TV';
  static const _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final dio = Dio()
        ..options.connectTimeout = const Duration(seconds: 8)
        ..options.receiveTimeout = const Duration(seconds: 8);

      final resp = await dio.get(_apiUrl, options: Options(
        headers: {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
        validateStatus: (s) => s != null && s < 500,
      ));

      if (resp.statusCode != 200) return null;
      final data = resp.data as Map<String, dynamic>;

      // Le tag ressemble à "Askaria-TV V1.0.0+build.5" ou "v1.0.0+build.5"
      // On extrait la version X.X.X
      final rawTag = (data['tag_name'] as String? ?? '').trim();
      if (rawTag.isEmpty) return null;

      // Supprimer les préfixes "Askaria-TV V", "v", etc. et les suffixes "+build.N"
      final cleaned = rawTag
          .replaceFirst(RegExp(r'^Askaria-TV\s*V', caseSensitive: false), '')
          .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
          .split('+')
          .first
          .trim();

      final info = await PackageInfo.fromPlatform();
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
    } catch (_) {
      return null;
    }
  }

  bool _isNewer(String latest, String current) {
    try {
      final l = latest.split('.').map(int.parse).toList();
      final c = current.split('.').map(int.parse).toList();
      while (l.length < 3) { l.add(0); }
      while (c.length < 3) { c.add(0); }
      for (int i = 0; i < 3; i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
    } catch (_) {}
    return false;
  }
}

// ── Écran Paramètres ──────────────────────────────────────────────────────────
// Utilisé comme body dans HomeTvScreen (sans sidebar propre).
// Pour usage standalone (ex: test), envelopper dans un Scaffold.
class SettingsTvScreen extends StatefulWidget {
  const SettingsTvScreen({super.key});

  @override
  State<SettingsTvScreen> createState() => _SettingsTvScreenState();
}

class _SettingsTvScreenState extends State<SettingsTvScreen> {
  Map<String, dynamic> _profile = {};
  bool _loadingProfile = true;
  bool _lossless = true;
  String _appVersion   = '';
  String _buildNumber  = '';
  bool   _checkingUpdate = false;
  UpdateInfo? _updateInfo;
  String? _updateMsg;
  bool   _updateIsError = false;
  String  _serverUrl   = '';

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final api   = SwingApiService();
    final prefs = await SharedPreferences.getInstance();
    final info  = await PackageInfo.fromPlatform();

    if (mounted) {
      setState(() {
        _appVersion  = info.version;
        _buildNumber = info.buildNumber;
        _lossless    = prefs.getBool('audio_lossless') ?? true;
        _serverUrl   = api.baseUrl;
      });
    }

    try {
      final profile = await api.getMyProfile();
      if (mounted) setState(() { _profile = profile; _loadingProfile = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  Future<void> _toggleLossless(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('audio_lossless', val);
    if (mounted) setState(() => _lossless = val);
  }

  Future<void> _checkUpdate() async {
    if (_checkingUpdate) return;
    setState(() {
      _checkingUpdate = true;
      _updateMsg  = null;
      _updateInfo = null;
      _updateIsError = false;
    });
    try {
      final info = await _TvUpdateService().checkForUpdate();
      if (mounted) {
        setState(() {
          _checkingUpdate = false;
          if (info == null) {
            _updateMsg     = 'Vous êtes à jour ! (v$_appVersion)';
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
          _updateMsg      = 'Erreur de vérification : $e';
          _updateIsError  = true;
        });
      }
    }
  }

  Future<void> _logout() async {
    await SwingApiService().logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginTvScreen()),
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retourne uniquement le contenu : HomeTvScreen est le shell (sidebar + Scaffold)
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
      children: [
                const Text(
                  'Paramètres',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 28),

                // ── Profil utilisateur ───────────────────────────────────────
                _SettingsSection(
                  icon: Icons.account_circle_rounded,
                  title: 'COMPTE',
                  child: _loadingProfile
                      ? const SizedBox(
                          height: 80,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Sp.focus, strokeWidth: 2),
                          ),
                        )
                      : _profile.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'Profil indisponible',
                                style: TextStyle(color: Sp.textDim),
                              ),
                            )
                          : _ProfileCard(profile: _profile),
                ),
                const SizedBox(height: 20),

                // ── Qualité audio ─────────────────────────────────────────────
                _SettingsSection(
                  icon: Icons.high_quality_rounded,
                  title: 'QUALITÉ AUDIO',
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'Lecture Lossless',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Badge statut
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: _lossless
                                        ? const Color(0xFF1D9E75).withOpacity(0.2)
                                        : Colors.white12,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _lossless
                                          ? const Color(0xFF1D9E75)
                                          : Colors.white24,
                                    ),
                                  ),
                                  child: Text(
                                    _lossless ? 'ACTIVÉ' : 'DÉSACTIVÉ',
                                    style: TextStyle(
                                      color: _lossless
                                          ? const Color(0xFF1D9E75)
                                          : Sp.textDim,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _lossless
                                  ? 'Streaming sans compression — FLAC / WAV (bitrate original)'
                                  : 'Streaming compressé — 192 kbps AAC/MP3',
                              style: const TextStyle(color: Sp.textDim, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 24),
                      _TvSwitch(value: _lossless, onChanged: _toggleLossless),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Mises à jour ───────────────────────────────────────────────
                _SettingsSection(
                  icon: Icons.system_update_rounded,
                  title: 'MISES À JOUR',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Askaria TV',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Version installée : v$_appVersion'
                                  '${_buildNumber.isNotEmpty ? "+$_buildNumber" : ""}',
                                  style: const TextStyle(
                                    color: Sp.textDim, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Source : github.com/Mixypunk/Askaria-TV',
                                  style: TextStyle(
                                    color: Sp.textDim, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          _TvFocusButton(
                            label: 'Vérifier',
                            loading: _checkingUpdate,
                            onTap: _checkUpdate,
                          ),
                        ],
                      ),

                      // Feedback vérification
                      if (_updateMsg != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(
                              _updateIsError
                                  ? Icons.error_outline_rounded
                                  : Icons.check_circle_rounded,
                              color: _updateIsError
                                  ? const Color(0xFFE24B4A)
                                  : const Color(0xFF1D9E75),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _updateMsg!,
                                style: TextStyle(
                                  color: _updateIsError
                                      ? const Color(0xFFE24B4A)
                                      : const Color(0xFF1D9E75),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Nouvelle version disponible
                      if (_updateInfo != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Sp.g1, Sp.g2],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.new_releases_rounded,
                                  color: Colors.white, size: 28),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Version ${_updateInfo!.version} disponible !',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    const Text(
                                      'Sélectionnez Mettre à jour pour télécharger et installer.',
                                      style: TextStyle(
                                        color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              _TvFocusButton(
                                label: 'Mettre à jour',
                                onTap: () => UpdateDialog.show(
                                    context, _updateInfo!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Infos serveur ──────────────────────────────────────────────
                _SettingsSection(
                  icon: Icons.dns_rounded,
                  title: 'SERVEUR',
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: Sp.focus, size: 20),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          _serverUrl.isEmpty ? 'Non configuré' : _serverUrl,
                          style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),

                // ── Déconnexion ───────────────────────────────────────────────
                Center(
                  child: _TvFocusButton(
                    label: 'Se déconnecter',
                    onTap: _logout,
                    danger: true,
                    icon: Icons.logout_rounded,
                  ),
                ),
                const SizedBox(height: 24),
      ],
    );
  }
}


class _SettingsSection extends StatelessWidget {
  final IconData icon;
  final String  title;
  final Widget  child;
  const _SettingsSection({
    required this.icon,
    required this.title,
    required this.child,
  });

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
          // En-tête de section
          Row(
            children: [
              Icon(icon, color: Sp.focus, size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Sp.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final Map<String, dynamic> profile;
  const _ProfileCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final username = (profile['username'] ?? profile['name'] ?? '').toString();
    final email    = (profile['email'] ?? '').toString();
    final role     = (profile['role']  ?? profile['type'] ?? '').toString();
    final initial  = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Row(
      children: [
        // Avatar initiale avec dégradé
        Container(
          width: 72, height: 72,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Sp.g1, Sp.g3],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                username.isNotEmpty ? username : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 14, color: Sp.textDim),
                    const SizedBox(width: 6),
                    Text(email,
                        style: const TextStyle(color: Sp.textDim, fontSize: 14)),
                  ],
                ),
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
                  child: Text(
                    role.toUpperCase(),
                    style: const TextStyle(
                      color: Sp.focus,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// Toggle switch adapté D-PAD
class _TvSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const _TvSwitch({required this.value, required this.onChanged});

  @override
  State<_TvSwitch> createState() => _TvSwitchState();
}

class _TvSwitchState extends State<_TvSwitch> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: () => widget.onChanged(!widget.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 62, height: 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            color: widget.value ? Sp.focus : Colors.white24,
            border: _hasFocus
                ? Border.all(color: Colors.white, width: 2)
                : null,
            boxShadow: _hasFocus
                ? [BoxShadow(color: Sp.focus.withOpacity(0.5), blurRadius: 12)]
                : [],
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 250),
            alignment:
                widget.value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.all(4),
              width: 26, height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Bouton d'action pour la TV (D-PAD focusable)
class _TvFocusButton extends StatefulWidget {
  final String   label;
  final VoidCallback onTap;
  final bool     loading;
  final bool     danger;
  final IconData? icon;
  const _TvFocusButton({
    required this.label,
    required this.onTap,
    this.loading = false,
    this.danger  = false,
    this.icon,
  });

  @override
  State<_TvFocusButton> createState() => _TvFocusButtonState();
}

class _TvFocusButtonState extends State<_TvFocusButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    final gradient = widget.danger
        ? const LinearGradient(
            colors: [Color(0xFFE24B4A), Color(0xFFB71C1C)])
        : const LinearGradient(
            colors: [Sp.g1, Sp.g2],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight);

    return Focus(
      onFocusChange: (f) => setState(() => _hasFocus = f),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(30),
            border: _hasFocus
                ? Border.all(color: Colors.white, width: 2)
                : null,
            boxShadow: _hasFocus
                ? [
                    BoxShadow(
                      color: (widget.danger ? Colors.red : Sp.focus)
                          .withOpacity(0.5),
                      blurRadius: 18,
                    )
                  ]
                : [],
          ),
          child: widget.loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                    ],
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
