import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/ynison_service.dart';

const _oauthUrl =
    'https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d';
const _oauthRedirectHost = 'music.yandex.ru';
const _tokenKey = 'yandex_music_token';

class _TrackInfo {
  final String title;
  final String artist;
  final String? coverUrl;

  const _TrackInfo({
    required this.title,
    required this.artist,
    this.coverUrl,
  });
}

class Music_Page extends StatefulWidget {
  const Music_Page({super.key});

  @override
  State<Music_Page> createState() => _MusicPageState();
}

class _MusicPageState extends State<Music_Page> {
  String? _token;
  bool _loading = true;
  _TrackInfo? _currentTrack;
  bool _trackLoading = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _saveTokenRemote(String token) async {
    final uid = _uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'yandex_music_token': token}, SetOptions(merge: true));
  }

  Future<void> _removeTokenRemote() async {
    final uid = _uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({'yandex_music_token': FieldValue.delete()});
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(_tokenKey);

    // Если нет локально — тянем из Firestore и кэшируем
    if (token == null) {
      final uid = _uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        token = doc.data()?['yandex_music_token'] as String?;
        if (token != null) {
          await prefs.setString(_tokenKey, token);
        }
      }
    }

    setState(() {
      _token = token;
      _loading = false;
    });
    if (token != null) _startTracking();
  }

  void _startTracking() {
    _fetchCurrentTrack();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchCurrentTrack();
    });
  }

  Future<void> _fetchCurrentTrack() async {
    if (_token == null) return;
    setState(() => _trackLoading = true);

    try {
      final info = await YnisonService.fetchCurrentTrack(_token!);
      if (!mounted) return;
      setState(() {
        _currentTrack = info == null
            ? null
            : _TrackInfo(
                title: info.title,
                artist: info.artist,
                coverUrl: info.coverUrl,
              );
        _trackLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentTrack = null;
        _trackLoading = false;
      });
    }
  }

  Future<void> _openOAuth() async {
    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _YandexOAuthPage()),
    );
    if (token != null && token.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      await _saveTokenRemote(token);
      setState(() => _token = token);
      _startTracking();
    }
  }

  Future<void> _logout() async {
    _refreshTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await _removeTokenRemote();
    setState(() {
      _token = null;
      _currentTrack = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _token == null ? _buildLogin(cs) : _buildConnected(cs),
      ),
    );
  }

  Widget _buildLogin(ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _openOAuth,
            child: _yandexLogo(),
          ),
          const SizedBox(height: 20),
          const Text(
            'Яндекс Музыка',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFC3F1D),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Нажми на логотип для входа',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnected(ColorScheme cs) {
    final shortToken = _token!.length > 20
        ? '${_token!.substring(0, 10)}...${_token!.substring(_token!.length - 6)}'
        : _token!;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _yandexLogo(),
          const SizedBox(height: 20),
          const Text(
            'Яндекс Музыка',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFC3F1D),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_rounded,
                  color: Colors.green.shade400, size: 18),
              const SizedBox(width: 6),
              Text(
                'Подключено',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.green.shade400,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Текущий трек
          _buildNowPlaying(cs),

          const SizedBox(height: 20),

          // Карточка с токеном
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: _token!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Токен скопирован'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded,
                      size: 16, color: Color(0xFFFC3F1D)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      shortToken,
                      style: TextStyle(
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  Icon(Icons.copy_rounded,
                      size: 14,
                      color: cs.onSurface.withValues(alpha: 0.35)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _logout,
            icon: Icon(Icons.logout_rounded,
                size: 16, color: cs.onSurface.withValues(alpha: 0.4)),
            label: Text(
              'Выйти',
              style:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNowPlaying(ColorScheme cs) {
    if (_trackLoading && _currentTrack == null) {
      return const SizedBox(
        height: 20,
        width: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Color(0xFFFC3F1D),
        ),
      );
    }

    if (_currentTrack == null) {
      return Text(
        'Сейчас ничего не играет',
        style: TextStyle(
          fontSize: 13,
          color: cs.onSurface.withValues(alpha: 0.35),
        ),
      );
    }

    final track = _currentTrack!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          // Обложка
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: track.coverUrl != null
                ? Image.network(
                    track.coverUrl!,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _coverPlaceholder(),
                  )
                : _coverPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.music_note_rounded,
                        size: 11, color: Color(0xFFFC3F1D)),
                    const SizedBox(width: 4),
                    Text(
                      'Сейчас играет',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  track.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  track.artist,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Кнопка обновить
          IconButton(
            onPressed: _fetchCurrentTrack,
            icon: _trackLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFFFC3F1D),
                    ),
                  )
                : Icon(Icons.refresh_rounded,
                    size: 18,
                    color: cs.onSurface.withValues(alpha: 0.35)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFFC3F1D).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.music_note_rounded,
          color: Color(0xFFFC3F1D), size: 24),
    );
  }

  Widget _yandexLogo() {
    return Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFFC3F1D),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFC3F1D).withValues(alpha: 0.4),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'Я',
          style: TextStyle(
            color: Colors.white,
            fontSize: 64,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _YandexOAuthPage extends StatefulWidget {
  const _YandexOAuthPage();

  @override
  State<_YandexOAuthPage> createState() => _YandexOAuthPageState();
}

class _YandexOAuthPageState extends State<_YandexOAuthPage> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (url) {
          setState(() => _loading = false);
          _checkUrl(url);
        },
        onNavigationRequest: (req) {
          if (_extractToken(req.url) != null) {
            _handleToken(_extractToken(req.url)!);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(_oauthUrl));
  }

  String? _extractToken(String url) {
    // Token is in the fragment: https://music.yandex.ru/#access_token=...
    final uri = Uri.parse(url);
    if (uri.host != _oauthRedirectHost) return null;
    final params = Uri.splitQueryString(uri.fragment);
    return params['access_token'];
  }

  void _checkUrl(String url) {
    final token = _extractToken(url);
    if (token != null) _handleToken(token);
  }

  void _handleToken(String token) {
    if (mounted) Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Войти через Яндекс'),
        backgroundColor: const Color(0xFFFC3F1D),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFFC3F1D)),
            ),
        ],
      ),
    );
  }
}
