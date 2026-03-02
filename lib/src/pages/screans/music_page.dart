import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _oauthUrl =
    'https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d';
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
  final _tokenController = TextEditingController();
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
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
      // 1. Получаем текущий трек
      final resp = await http.get(
        Uri.parse('http://api.mipoh.ru/get_current_track_beta'),
        headers: {'ya-token': _token!},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode != 200) {
        setState(() {
          _currentTrack = null;
          _trackLoading = false;
        });
        return;
      }

      final data = jsonDecode(resp.body);
      final trackId = data['track']?['track_id']?.toString();

      if (trackId == null) {
        setState(() {
          _currentTrack = null;
          _trackLoading = false;
        });
        return;
      }

      // 2. Получаем детали трека через Yandex Music API
      final trackResp = await http.get(
        Uri.parse('https://api.music.yandex.net/tracks/$trackId'),
        headers: {'Authorization': 'OAuth $_token'},
      ).timeout(const Duration(seconds: 10));

      if (trackResp.statusCode != 200) {
        setState(() {
          _currentTrack = null;
          _trackLoading = false;
        });
        return;
      }

      final trackData = jsonDecode(trackResp.body);
      final result = trackData['result'];
      final track = (result is List && result.isNotEmpty) ? result[0] : result;

      final title = track['title'] as String? ?? 'Неизвестный трек';
      final artists = (track['artists'] as List?)
              ?.map((a) => a['name'] as String? ?? '')
              .where((n) => n.isNotEmpty)
              .join(', ') ??
          'Неизвестный артист';

      String? coverUrl;
      final albums = track['albums'] as List?;
      if (albums != null && albums.isNotEmpty) {
        final raw = albums[0]['coverUri'] as String?;
        if (raw != null) {
          coverUrl = 'https://${raw.replaceFirst('//', '').replaceAll('%%', '400x400')}';
        }
      }

      setState(() {
        _currentTrack = _TrackInfo(title: title, artist: artists, coverUrl: coverUrl);
        _trackLoading = false;
      });
    } catch (_) {
      setState(() {
        _currentTrack = null;
        _trackLoading = false;
      });
    }
  }

  Future<void> _openOAuth() async {
    await launchUrl(Uri.parse(_oauthUrl), mode: LaunchMode.inAppBrowserView);
  }

  Future<void> _saveTokenFromInput() async {
    final raw = _tokenController.text.trim();
    if (raw.isEmpty) return;

    String? token;
    if (raw.contains('access_token=')) {
      final fragment = Uri.parse(raw).fragment;
      final params = Uri.splitQueryString(fragment);
      token = params['access_token'];
    } else {
      token = raw;
    }

    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось извлечь токен из ссылки')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    _tokenController.clear();
    setState(() => _token = token);
    _startTracking();
  }

  Future<void> _logout() async {
    _refreshTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
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
            'Нажми на логотип — откроется браузер',
            style: TextStyle(
              fontSize: 14,
              color: cs.onSurface.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Авторизуйся и скопируй ссылку из адресной строки',
            style: TextStyle(
              fontSize: 12,
              color: cs.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: TextField(
              controller: _tokenController,
              decoration: InputDecoration(
                hintText: 'Вставь ссылку или токен сюда',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withValues(alpha: 0.35),
                ),
                filled: true,
                fillColor: cs.onSurface.withValues(alpha: 0.06),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: cs.onSurface.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: cs.onSurface.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFC3F1D)),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_rounded,
                      color: Color(0xFFFC3F1D)),
                  onPressed: _saveTokenFromInput,
                ),
              ),
              style: TextStyle(fontSize: 13, color: cs.onSurface),
              onSubmitted: (_) => _saveTokenFromInput(),
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
