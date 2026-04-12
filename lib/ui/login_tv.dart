import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/services/api_service.dart';
import '../main.dart';
import 'home_tv.dart';

class LoginTvScreen extends StatefulWidget {
  const LoginTvScreen({super.key});
  @override
  State<LoginTvScreen> createState() => _LoginTvScreenState();
}

class _LoginTvScreenState extends State<LoginTvScreen> {
  final _urlCtrl = TextEditingController(text: 'http://192.168.');
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _urlCtrl.text = SwingApiService().baseUrl;
  }

  Future<void> _login() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = SwingApiService();
      await api.saveUrl(_urlCtrl.text.trim());
      final ok = await api.login(_emailCtrl.text.trim(), _pwdCtrl.text.trim());
      if (ok) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeTvScreen()));
        }
      } else {
        setState(() => _error = 'Identifiants incorrects');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // GAUCHE : Logo & Bienvenue
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
                      child: const Icon(Icons.tv_rounded, size: 100, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    const Text('Askaria TV', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    const Text('Connectez-vous à votre serveur', style: TextStyle(fontSize: 18, color: Sp.textDim)),
                  ],
                ),
              ),
            ),
          ),
          
          // DROITE : Formulaire
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.withOpacity(0.2),
                      child: Text(_error!, style: const TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  _TvTextField(
                    label: 'URL du Serveur',
                    controller: _urlCtrl,
                    icon: Icons.link,
                    keyboardType: TextInputType.url,
                    autofocus: true,
                  ),
                  const SizedBox(height: 24),
                  _TvTextField(
                    label: 'Email',
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
                  
                  // Bouton avec gestion de Focus TV
                  _TvButton(
                    label: 'Se connecter',
                    isLoading: _loading,
                    onPressed: _login,
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
           (event.logicalKey == LogicalKeyboardKey.select || event.logicalKey == LogicalKeyboardKey.enter)) {
          // Ouvre de force le clavier virtuel lors du clic sur OK (télécommande TV)
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Sp.focus, width: 2),
          ),
        ),
      ),
    );
  }
}

class _TvButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const _TvButton({required this.label, required this.isLoading, required this.onPressed});

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
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: _hasFocus ? kGrad : null,
          color: _hasFocus ? null : Sp.surface,
          border: _hasFocus ? Border.all(color: Colors.white, width: 2) : null,
          boxShadow: _hasFocus ? [BoxShadow(color: Sp.g2.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)] : [],
        ),
        alignment: Alignment.center,
        child: widget.isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(widget.label, style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold, 
                color: _hasFocus ? Colors.white : Sp.textDim,
              )),
      ),
    );
  }
}
