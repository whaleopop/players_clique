import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const _oauthUrl =
    'https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d';
const _tokenKey = 'yandex_music_token';

class Music_Page extends StatefulWidget {
  const Music_Page({super.key});

  @override
  State<Music_Page> createState() => _MusicPageState();
}

class _MusicPageState extends State<Music_Page> {
  String? _token;
  bool _loading = true;
  final _tokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString(_tokenKey);
      _loading = false;
    });
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
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    setState(() => _token = null);
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
          const SizedBox(height: 16),
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
          const SizedBox(height: 12),
          Text(
            'щщщщщ узбеки спят',
            style: TextStyle(
              fontSize: 16,
              color: cs.onSurface.withValues(alpha: 0.5),
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
