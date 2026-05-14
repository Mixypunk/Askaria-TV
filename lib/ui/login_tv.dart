import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/services/api_service.dart';
import '../main.dart';
import 'home_tv.dart';

class LoginTvScreen extends StatefulWidget {
  const LoginTvScreen({super.key});
  @override
  State<LoginTvScreen> createState() => _LoginTvScreenState();
}

class _LoginTvScreenState extends State<LoginTvScreen>
    with SingleTickerProviderStateMixin {
  // ── Controllers ──────────────────────────────────────────────────────────────
  final _urlCtrl   = TextEditingController(text: 'http://192.168.');
  final _emailCtrl = TextEditingController();
  final _pwdCtrl   = TextEditingController();
  late final TabController _tabCtrl;

  // ── État onglet 1 (login classique) ──────────────────────────────────────────
  bool    _loading       = false;
  bool    _testingServer = false;
  String? _error;
  String? _serverOk;

  // ── État onglet 2 (via mobile) ────────────────────────────────────────────────
  String?  _tvCode;
  Timer?   _pollTimer;
  Timer?   _countdownTimer;
  int      _secondsLeft  = 300; // 5 minutes
  bool     _codeLoading  = false;
  String?  _pairError;
  bool     _pairSuccess  = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _urlCtrl.text = SwingApiService().baseUrl;

    // Générer le code dès qu'on passe sur l'onglet 2
    _tabCtrl.addListener(() {
      if (_tabCtrl.index == 1 && _tvCode == null && !_codeLoading) {
        _generateCode();
      }
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _urlCtrl.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Onglet 1 — Login classique
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _testServer() async {
    setState(() { _testingServer = true; _error = null; _serverOk = null; });
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      setState(() {
        _error       = 'URL invalide. Exemple: http://192.168.1.10:7777';
        _testingServer = false;
      });
      return;
    }
    try {
      final cleanUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
      final response = await http
          .get(Uri.parse('$cleanUrl/auth/users'))
          .timeout(const Duration(seconds: 8));
      setState(() => response.statusCode == 200
          ? _serverOk = '✅ Serveur joignable !'
          : _error    = '⚠️ Serveur répond HTTP ${response.statusCode}');
    } on Exception catch (e) {
      setState(() => _error = 'Serveur inaccessible: $e');
    } finally {
      if (mounted) setState(() => _testingServer = false);
    }
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; _serverOk = null; });
    try {
      final api = SwingApiService();
      await api.saveUrl(_urlCtrl.text.trim());
      final ok = await api.login(_emailCtrl.text.trim(), _pwdCtrl.text.trim());
      if (ok && mounted) {
        Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const HomeTvScreen()));
      }
    } on Exception catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ────────────────────────────────────────────────────────────────────────────
  // Onglet 2 — Via Mobile (code 6 chiffres)
  // ────────────────────────────────────────────────────────────────────────────

  Future<void> _generateCode() async {
    // Annuler les timers précédents
    _pollTimer?.cancel();
    _countdownTimer?.cancel();

    setState(() {
      _codeLoading  = true;
      _pairError    = null;
      _pairSuccess  = false;
      _tvCode       = null;
      _secondsLeft  = 300;
    });

    try {
      // Sauvegarder l'URL si elle a changé
      final url = _urlCtrl.text.trim();
      if (url.isNotEmpty && url.startsWith('http')) {
        await SwingApiService().saveUrl(url);
      }

      final code = await SwingApiService().createTvPairCode();
      if (!mounted) return;

      setState(() {
        _tvCode      = code;
        _codeLoading = false;
      });

      _startPolling();
      _startCountdown();
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _pairError   = e.toString().replaceFirst('Exception: ', '');
          _codeLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (_tvCode == null || !mounted) return;
      try {
        final result = await SwingApiService().pollTvPair(_tvCode!);
        if (result != null && mounted) {
          // Approuvé !
          _pollTimer?.cancel();
          _countdownTimer?.cancel();
          setState(() => _pairSuccess = true);
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const HomeTvScreen()));
          }
        }
      } on Exception catch (e) {
        // Code expiré ou erreur → arrêter le polling et afficher l'erreur
        _pollTimer?.cancel();
        _countdownTimer?.cancel();
        if (mounted) {
          setState(() {
            _pairError = e.toString().replaceFirst('Exception: ', '');
            _tvCode    = null;
          });
        }
      }
    });
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _countdownTimer?.cancel();
        _pollTimer?.cancel();
        if (mounted) {
          setState(() {
            _pairError = 'Code expiré. Appuyez sur "Nouveau code".';
            _tvCode    = null;
          });
        }
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  String _fmtCode(String code) {
    // Affiche "482 619" pour plus de lisibilité sur TV
    if (code.length == 6) return '${code.substring(0, 3)} ${code.substring(3)}';
    return code;
  }

  String _fmtTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ────────────────────────────────────────────────────────────────────────────
  // UI
  // ────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ── GAUCHE : Logo ─────────────────────────────────────────────────
          Expanded(
            flex: 4,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Sp.bg, Sp.surface],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => kGrad.createShader(b),
                      child: const Icon(Icons.tv_rounded,
                          size: 100, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text('Askaria TV',
                        style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    const Text('Connectez-vous à votre serveur',
                        style: TextStyle(fontSize: 18, color: Sp.textDim)),
                  ],
                ),
              ),
            ),
          ),

          // ── DROITE : Formulaire avec onglets ─────────────────────────────
          Expanded(
            flex: 5,
            child: Column(
              children: [
                // Onglets
                Container(
                  margin: const EdgeInsets.fromLTRB(60, 40, 60, 0),
                  decoration: BoxDecoration(
                    color: Sp.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    indicator: BoxDecoration(
                      gradient: kGrad,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Colors.white,
                    unselectedLabelColor: Sp.textDim,
                    labelStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Email / MDP'),
                      Tab(text: 'Via l\'app mobile'),
                    ],
                  ),
                ),
                // Contenu des onglets
                Expanded(
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildClassicLogin(),
                      _buildMobilePair(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Onglet 1 : Login classique ───────────────────────────────────────────────
  Widget _buildClassicLogin() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Erreur
          if (_error != null) ...[
            _ErrorBanner(_error!),
            const SizedBox(height: 20),
          ],
          // Succès test serveur
          if (_serverOk != null) ...[
            _SuccessBanner(_serverOk!),
            const SizedBox(height: 20),
          ],

          // URL + Tester
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TvTextField(
                  label: 'URL du Serveur',
                  controller: _urlCtrl,
                  icon: Icons.link,
                  keyboardType: TextInputType.url,
                  autofocus: true,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 60,
                child: _TvButton(
                  label: _testingServer ? '...' : 'Tester',
                  isLoading: _testingServer,
                  isCompact: true,
                  onPressed: _testServer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _TvTextField(
            label: 'Email ou Nom d\'utilisateur',
            controller: _emailCtrl,
            icon: Icons.person,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 24),
          _TvTextField(
            label: 'Mot de passe',
            controller: _pwdCtrl,
            icon: Icons.lock,
            obscure: true,
          ),
          const SizedBox(height: 48),
          _TvButton(
            label: 'Se connecter',
            isLoading: _loading,
            onPressed: _login,
          ),
        ],
      ),
    );
  }

  // ── Onglet 2 : Via Mobile ────────────────────────────────────────────────────
  Widget _buildMobilePair() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          const Text(
            'Depuis votre app Askaria mobile :',
            textAlign: TextAlign.center,
            style: TextStyle(color: Sp.textDim, fontSize: 16),
          ),
          const SizedBox(height: 8),
          const Text(
            'Paramètres → Connecter la TV → Saisir le code',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 40),

          // ── État : chargement ─────────────────────────────────────────────
          if (_codeLoading)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: Sp.g2, strokeWidth: 2),
                  SizedBox(height: 16),
                  Text('Génération du code…',
                      style: TextStyle(color: Sp.textDim, fontSize: 15)),
                ],
              ),
            )

          // ── État : succès ─────────────────────────────────────────────────
          else if (_pairSuccess)
            Center(
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (b) => kGrad.createShader(b),
                    child: const Icon(Icons.check_circle_rounded,
                        size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text('Connexion réussie !',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            )

          // ── État : erreur sans code ────────────────────────────────────────
          else if (_pairError != null && _tvCode == null)
            Column(
              children: [
                _ErrorBanner(_pairError!),
                const SizedBox(height: 24),
                _TvButton(
                  label: 'Nouveau code',
                  isLoading: false,
                  onPressed: _generateCode,
                ),
              ],
            )

          // ── État : code affiché ───────────────────────────────────────────
          else if (_tvCode != null)
            Column(
              children: [
                // Code en grand
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Sp.g1.withOpacity(0.15),
                        Sp.g2.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Sp.g2.withOpacity(0.4), width: 2),
                  ),
                  child: ShaderMask(
                    shaderCallback: (b) => kGrad.createShader(b),
                    child: Text(
                      _fmtCode(_tvCode!),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 12,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Indicateur de polling
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Sp.g2.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('En attente de validation…',
                        style: TextStyle(color: Sp.textDim, fontSize: 14)),
                  ],
                ),
                const SizedBox(height: 12),

                // Countdown
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      color: _secondsLeft < 60
                          ? Colors.orange
                          : Sp.textDim,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Expire dans ${_fmtTime(_secondsLeft)}',
                      style: TextStyle(
                        color: _secondsLeft < 60 ? Colors.orange : Sp.textDim,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Barre de progression
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _secondsLeft / 300,
                    backgroundColor: Sp.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _secondsLeft < 60 ? Colors.orange : Sp.g2,
                    ),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 28),

                // Bouton nouveau code
                _TvButton(
                  label: 'Nouveau code',
                  isLoading: false,
                  isCompact: true,
                  onPressed: _generateCode,
                ),
              ],
            )

          // ── État initial (ne devrait pas apparaître) ──────────────────────
          else
            Center(
              child: _TvButton(
                label: 'Générer un code',
                isLoading: false,
                onPressed: _generateCode,
              ),
            ),
        ],
      ),
    );
  }
}

// ── Banners ───────────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.red.withOpacity(0.15),
      border: Border.all(color: Colors.red.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(message,
            style: const TextStyle(color: Colors.red, fontSize: 15))),
      ],
    ),
  );
}

class _SuccessBanner extends StatelessWidget {
  final String message;
  const _SuccessBanner(this.message);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.green.withOpacity(0.15),
      border: Border.all(color: Colors.green.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
        const SizedBox(width: 10),
        Text(message,
            style: const TextStyle(color: Colors.green, fontSize: 15)),
      ],
    ),
  );
}

// ── TextField TV ──────────────────────────────────────────────────────────────

class _TvTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final bool autofocus;

  const _TvTextField({
    required this.label,
    required this.controller,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.autofocus = false,
  });

  @override
  State<_TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<_TvTextField> {
  late FocusNode _node;

  @override
  void initState() {
    super.initState();
    _node = FocusNode();
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter)) {
          _node.requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.show');
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TextField(
        focusNode: _node,
        autofocus: widget.autofocus,
        controller: widget.controller,
        obscureText: widget.obscure,
        keyboardType: widget.keyboardType,
        textInputAction: TextInputAction.next,
        style: const TextStyle(fontSize: 18, color: Colors.white),
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: const TextStyle(color: Sp.textDim),
          prefixIcon: Icon(widget.icon, color: Sp.textDim),
          filled: true,
          fillColor: Sp.surface,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Sp.focus, width: 2),
          ),
        ),
      ),
    );
  }
}

// ── Bouton TV ─────────────────────────────────────────────────────────────────

class _TvButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;
  final bool isCompact;

  const _TvButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.isCompact = false,
  });

  @override
  State<_TvButton> createState() => _TvButtonState();
}

class _TvButtonState extends State<_TvButton> {
  bool _hasFocus = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onFocusChange: (focus) => setState(() => _hasFocus = focus),
      onTap: widget.isLoading ? null : widget.onPressed,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: widget.isCompact ? 60 : 64,
        padding: widget.isCompact
            ? const EdgeInsets.symmetric(horizontal: 20)
            : EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: _hasFocus ? kGrad : null,
          color: _hasFocus ? null : Sp.surface,
          border:
              _hasFocus ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: _hasFocus
              ? [
                  BoxShadow(
                      color: Sp.g2.withOpacity(0.5),
                      blurRadius: 15,
                      spreadRadius: 2)
                ]
              : [],
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(
                widget.label,
                style: TextStyle(
                  fontSize: widget.isCompact ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: _hasFocus ? Colors.white : Sp.textDim,
                ),
              ),
      ),
    );
  }
}
