import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/providers/player_provider.dart';
import 'core/services/api_service.dart';
import 'ui/login_tv.dart';
import 'ui/home_tv.dart';

// --- TV Design System ---
class Sp {
  static const bg      = Color(0xFF0F0F14); // Noir profond TV
  static const surface = Color(0xFF1C1C24);
  static const focus   = Color(0xFF4776E6); // Couleur de focus D-PAD
  static const text    = Color(0xFFFFFFFF);
  static const textDim = Color(0xFF8A8A99);
  
  static const g1 = Color(0xFF4776E6);
  static const g2 = Color(0xFF8E54E9);
  static const g3 = Color(0xFFD63AF9);
}

const kGrad = LinearGradient(colors: [Sp.g1, Sp.g2, Sp.g3]);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Bloquer en mode paysage pour la TV
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Focus & UI initialization
  // JustAudioBackground is removed for TV to avoid crashes without complex Manifest services.

  runApp(const AskariaTvWrapper());
}

class AskariaTvWrapper extends StatefulWidget {
  const AskariaTvWrapper({super.key});

  @override
  State<AskariaTvWrapper> createState() => _AskariaTvWrapperState();
}

class _AskariaTvWrapperState extends State<AskariaTvWrapper> {
  bool _ready = false;
  bool _logged = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    try {
      final api = SwingApiService();
      await api.loadSettings();
      _logged = await api.checkAuth();
    } catch (_) {
      _logged = false;
    }
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: Sp.bg),
        home: const Scaffold(body: Center(child: CircularProgressIndicator(color: Sp.focus))),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: MaterialApp(
        title: 'Askaria TV',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: false,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: Sp.bg,
          colorScheme: const ColorScheme.dark(
            primary: Sp.focus,
            surface: Sp.surface,
            background: Sp.bg,
          ),
          // Configuration cruciale pour la TV : l'highlight color est utilisé
          // quand on navigue au D-Pad sur un élément.
          focusColor: Sp.focus.withOpacity(0.4),
          highlightColor: Sp.focus.withOpacity(0.2),
          fontFamily: 'Montserrat', // Assure-toi d'avoir importé la font si besoin
        ),
        home: _logged ? const HomeTvScreen() : const LoginTvScreen(),
      ),
    );
  }
}
