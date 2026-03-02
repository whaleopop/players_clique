import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _token = prefs.getString(_tokenKey);
      _loading = false;
    });
  }

  Future<void> _openOAuth() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const _OAuthWebView()),
    );
    if (result != null && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, result);
      setState(() => _token = result);
    }
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
              Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 18),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.onSurface.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.vpn_key_rounded, size: 16, color: Color(0xFFFC3F1D)),
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
                  Icon(Icons.copy_rounded, size: 14, color: cs.onSurface.withValues(alpha: 0.35)),
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
            icon: Icon(Icons.logout_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.4)),
            label: Text(
              'Выйти',
              style: TextStyle(color: cs.onSurface.withValues(alpha: 0.4)),
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

// ── OAuth WebView ─────────────────────────────────────────────────────────────

class _OAuthWebView extends StatefulWidget {
  const _OAuthWebView();

  @override
  State<_OAuthWebView> createState() => _OAuthWebViewState();
}

class _OAuthWebViewState extends State<_OAuthWebView> {
  late final WebViewController _controller;
  bool _pageLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          _tryExtractToken(url);
          if (mounted) setState(() => _pageLoading = true);
        },
        onPageFinished: (url) {
          _tryExtractToken(url);
          if (mounted) setState(() => _pageLoading = false);
        },
        onNavigationRequest: (request) {
          _tryExtractToken(request.url);
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(_oauthUrl));
  }

  void _tryExtractToken(String url) {
    if (!url.contains('access_token=')) return;

    // Токен находится в fragment (#), парсим как query-параметры
    final fragment = Uri.parse(url).fragment;
    final params = Uri.splitQueryString(fragment);
    final token = params['access_token'];

    if (token != null && token.isNotEmpty && mounted) {
      Navigator.pop(context, token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0.5,
        title: const Text('Войти в Яндекс', style: TextStyle(fontSize: 17)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_pageLoading)
            const LinearProgressIndicator(
              color: Color(0xFFFC3F1D),
              backgroundColor: Colors.transparent,
            ),
        ],
      ),
    );
  }
}
