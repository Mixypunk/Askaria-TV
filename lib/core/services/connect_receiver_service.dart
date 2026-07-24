import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:nsd/nsd.dart';
import '../providers/player_provider.dart';
import '../models/song.dart';

class ConnectReceiverService {
  ConnectReceiverService._privateConstructor();
  static final ConnectReceiverService instance = ConnectReceiverService._privateConstructor();

  HttpServer? _server;
  Registration? _registration;
  final List<WebSocket> _clients = [];
  PlayerProvider? _playerProvider;

  Future<void> init(PlayerProvider playerProvider) async {
    if (_server != null) return; // Already initialized
    _playerProvider = playerProvider;
    try {
      // Démarrer le serveur HTTP sur un port disponible (0)
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      debugPrint('[ConnectReceiver] Serveur démarré sur le port ${_server!.port}');

      // Écouter les requêtes WebSocket
      _server!.listen((HttpRequest request) async {
        if (request.uri.path == '/connect' && WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          _handleWebSocket(socket);
        } else {
          request.response
            ..statusCode = HttpStatus.notFound
            ..close();
        }
      });

      // Enregistrer le service mDNS
      final service = Service(
        name: 'Askaria TV',
        type: '_askaria._tcp',
        port: _server!.port,
      );
      _registration = await register(service);
      debugPrint('[ConnectReceiver] mDNS enregistré: ${_registration?.service.name}');
    } catch (e) {
      debugPrint('[ConnectReceiver] Erreur init: $e');
    }
  }

  void _handleWebSocket(WebSocket socket) {
    _clients.add(socket);
    debugPrint('[ConnectReceiver] Client connecté. Total: ${_clients.length}');
    
    // Envoyer l'état initial
    broadcastState();

    socket.listen((message) {
      _handleMessage(message);
    }, onDone: () {
      _clients.remove(socket);
      debugPrint('[ConnectReceiver] Client déconnecté. Total: ${_clients.length}');
    }, onError: (e) {
      _clients.remove(socket);
      debugPrint('[ConnectReceiver] Erreur WebSocket: $e');
    });
  }

  void _handleMessage(dynamic message) {
    if (_playerProvider == null) return;
    try {
      if (message is String) {
        final data = json.decode(message);
        final action = data['action'];
        
        debugPrint('[ConnectReceiver] Commande reçue: $action');
        
        switch (action) {
          case 'play':
            if (data['song'] != null) {
              final song = Song.fromJson(data['song']);
              _playerProvider!.playSong(song);
            } else {
              if (!_playerProvider!.isPlaying) {
                 _playerProvider!.playPause();
              }
            }
            break;
          case 'pause':
            if (_playerProvider!.isPlaying) {
               _playerProvider!.playPause();
            }
            break;
          case 'play_pause':
            _playerProvider!.playPause();
            break;
          case 'next':
            _playerProvider!.next();
            break;
          case 'previous':
            _playerProvider!.previous();
            break;
          case 'seek':
            final positionMs = data['position_ms'] as int;
            _playerProvider!.seek(Duration(milliseconds: positionMs));
            break;
        }
      }
    } catch (e) {
      debugPrint('[ConnectReceiver] Erreur traitement message: $e');
    }
  }

  void broadcastState() {
    if (_playerProvider == null || _clients.isEmpty) return;
    
    final currentSong = _playerProvider!.currentSong;
    final state = {
      'type': 'state_update',
      'is_playing': _playerProvider!.isPlaying,
      'position_ms': _playerProvider!.position.inMilliseconds,
      'duration_ms': _playerProvider!.duration.inMilliseconds,
      'song': currentSong != null ? {
        'hash': currentSong.hash,
        'title': currentSong.title,
        'artist': currentSong.artist,
        'image': currentSong.image,
        'filepath': currentSong.filepath,
      } : null,
    };
    
    final jsonStr = json.encode(state);
    for (final client in _clients) {
      client.add(jsonStr);
    }
  }

  Future<void> dispose() async {
    for (final client in _clients) {
      client.close();
    }
    _clients.clear();
    
    if (_registration != null) {
      await unregister(_registration!);
      _registration = null;
    }
    await _server?.close();
    _server = null;
  }
}
