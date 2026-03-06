import 'dart:io' show File;

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/music_service.dart';
import '../../services/ynison_service.dart';

const _oauthUrl =
    'https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d';
const _oauthRedirectHost = 'music.yandex.ru';
const _tokenKey = 'yandex_music_token';

class Music_Page extends StatefulWidget {
  const Music_Page({super.key});

  @override
  State<Music_Page> createState() => _MusicPageState();
}

const _kPageSize = 30;

class _MusicPageState extends State<Music_Page> {
  // ── Token ─────────────────────────────────────────────────────────────────
  String? _token;
  bool _loading = true;

  // ── Liked tracks (paginated) ──────────────────────────────────────────────
  List<Map<String, String>> _allIds = [];
  List<TrackInfo> _likedTracks = [];
  bool _likedLoading = false;
  bool _likedLoadingMore = false;
  final _listCtrl = ScrollController();

  // ── Search ────────────────────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';

  // ── Player ────────────────────────────────────────────────────────────────
  late MusicService _musicService;
  final _player = AudioPlayer();
  List<TrackInfo> _queue = [];
  int _queueIdx = -1;
  bool _isPlaying = false;
  bool _playerLoading = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  // ── My Wave ───────────────────────────────────────────────────────────────
  bool _waveLoading = false;

  List<TrackInfo> get _filteredTracks => _searchQuery.isEmpty
      ? _likedTracks
      : _likedTracks.where((t) =>
            t.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            t.artist.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  @override
  void initState() {
    super.initState();
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _pos = p); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _dur = d); });
    _player.onPlayerStateChanged.listen((s) {
      final playing = s == PlayerState.playing;
      if (mounted) {
        setState(() => _isPlaying = playing);
        _musicService.setPlaying(playing);
      }
    });
    _player.onPlayerComplete.listen((_) => _playNext());
    _listCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() { if (mounted) setState(() => _searchQuery = _searchCtrl.text); });
    _loadToken();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _musicService = Provider.of<MusicService>(context, listen: false);
  }

  @override
  void dispose() {
    _listCtrl.dispose();
    _searchCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_listCtrl.position.pixels >= _listCtrl.position.maxScrollExtent - 200) {
      _loadMoreLiked();
    }
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
    _loadAllLiked();
  }

  // ── Liked tracks pagination ───────────────────────────────────────────────

  Future<void> _loadAllLiked() async {
    if (_token == null) return;
    setState(() { _likedLoading = true; _allIds = []; _likedTracks = []; });
    try {
      final ids = await YnisonService.fetchLikedIds(_token!);
      if (!mounted) return;
      setState(() { _allIds = ids; });
      await _loadMoreLiked();
    } catch (_) {
      if (mounted) setState(() => _likedLoading = false);
    }
  }

  Future<void> _loadMoreLiked() async {
    if (_token == null || _likedLoadingMore) return;
    if (_likedTracks.length >= _allIds.length) return;
    setState(() { _likedLoadingMore = true; _likedLoading = false; });
    try {
      final next = _allIds.skip(_likedTracks.length).take(_kPageSize).toList();
      final details = await YnisonService.fetchTracksDetails(_token!, next);
      if (!mounted) return;
      setState(() { _likedTracks = [..._likedTracks, ...details]; _likedLoadingMore = false; });
    } catch (_) {
      if (mounted) setState(() => _likedLoadingMore = false);
    }
  }

  // ── Playback ─────────────────────────────────────────────────────────────

  Future<void> _playTrack(List<TrackInfo> queue, int index) async {
    if (index < 0 || index >= queue.length) return;
    final track = queue[index];
    if (track.id.isEmpty) return;
    setState(() { _queue = queue; _queueIdx = index; _playerLoading = true; _pos = Duration.zero; _dur = Duration.zero; });
    _musicService.setCurrentTrack(track, isPlaying: false);
    try {
      // Сначала проверяем кастомную версию
      String? url;
      final uid = _uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users').doc(uid).collection('customTracks').doc(track.id).get();
        url = doc.data()?['audioUrl'] as String?;
      }
      url ??= await YnisonService.fetchTrackUrl(_token!, track.id);
      if (!mounted) return;
      if (url == null) {
        setState(() => _playerLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось получить ссылку')));
        return;
      }
      await _player.play(UrlSource(url));
      if (mounted) {
        setState(() => _playerLoading = false);
        _musicService.setCurrentTrack(track, isPlaying: true);
      }
    } catch (_) {
      if (mounted) setState(() => _playerLoading = false);
    }
  }

  Future<void> _replaceTrack(TrackInfo track) async {
    final uid = _uid;
    if (uid == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Загрузка...')));
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance.ref().child('custom_tracks/$uid/${track.id}_$ts.mp3');
      final task = (!kIsWeb && file.path != null)
          ? ref.putFile(File(file.path!))
          : ref.putData(file.bytes!);
      final snap = await task;
      final url = await snap.ref.getDownloadURL();
      await FirebaseFirestore.instance
          .collection('users').doc(uid).collection('customTracks').doc(track.id)
          .set({'audioUrl': url, 'trackId': track.id, 'uploadedAt': FieldValue.serverTimestamp()});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Версия загружена')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  void _playNext() {
    if (_queueIdx < _queue.length - 1) _playTrack(_queue, _queueIdx + 1);
  }

  void _playPrev() {
    if (_pos.inSeconds > 3) {
      _player.seek(Duration.zero);
    } else if (_queueIdx > 0) {
      _playTrack(_queue, _queueIdx - 1);
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.resume();
    }
  }

  // ── My Wave ───────────────────────────────────────────────────────────────

  Future<void> _startMyWave() async {
    if (_token == null || _waveLoading) return;
    setState(() => _waveLoading = true);
    try {
      final tracks = await YnisonService.fetchMyWaveTracks(_token!);
      if (!mounted) return;
      if (tracks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Моя Волна недоступна')));
        return;
      }
      _playTrack(tracks, 0);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ошибка загрузки волны')));
    } finally {
      if (mounted) setState(() => _waveLoading = false);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await _removeTokenRemote();
    _musicService.clear();
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Шапка: лого + название + выход ──────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFC3F1D),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFC3F1D).withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('Я', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Яндекс Музыка',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFC3F1D))),
                    Row(children: [
                      Icon(Icons.check_circle_rounded, color: Colors.green.shade400, size: 13),
                      const SizedBox(width: 4),
                      Text('Подключено',
                          style: TextStyle(fontSize: 12, color: Colors.green.shade400, fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 19, color: cs.onSurface.withValues(alpha: 0.3)),
                tooltip: 'Скопировать токен',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _token!));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Токен скопирован'), duration: Duration(seconds: 2)),
                  );
                },
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded, size: 19, color: cs.onSurface.withValues(alpha: 0.3)),
                tooltip: 'Выйти',
                onPressed: _logout,
              ),
            ],
          ),
        ),
        // ── Поиск ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Поиск по трекам...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFFFC3F1D)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _searchCtrl.clear(),
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: cs.onSurface.withValues(alpha: 0.06),
            ),
          ),
        ),
        // ── Заголовок списка + Моя Волна ──────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.favorite_rounded, size: 16, color: Color(0xFFFC3F1D)),
              const SizedBox(width: 6),
              Text(
                _allIds.isEmpty
                    ? 'Любимые треки'
                    : 'Любимые треки (${_likedTracks.length}/${_allIds.length})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              // Моя Волна
              GestureDetector(
                onTap: _waveLoading ? null : _startMyWave,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFC3F1D).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _waveLoading
                      ? const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFC3F1D)),
                        )
                      : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.waves_rounded, size: 13, color: Color(0xFFFC3F1D)),
                            SizedBox(width: 4),
                            Text('Моя Волна',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFFC3F1D))),
                          ],
                        ),
                ),
              ),
              const SizedBox(width: 8),
              if (_likedLoading)
                const SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFC3F1D)),
                )
              else
                GestureDetector(
                  onTap: _loadAllLiked,
                  child: Icon(Icons.refresh_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.3)),
                ),
            ],
          ),
        ),
        // ── Список треков ─────────────────────────────────────────
        Expanded(
          child: _likedLoading && _likedTracks.isEmpty
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFC3F1D)))
              : _filteredTracks.isEmpty
                  ? Center(
                      child: Text(
                        _searchQuery.isNotEmpty ? 'Ничего не найдено' : 'Нет треков',
                        style: TextStyle(color: cs.onSurface.withValues(alpha: 0.35)),
                      ),
                    )
                  : ListView.builder(
                      controller: _listCtrl,
                      padding: EdgeInsets.only(bottom: _queueIdx >= 0 ? 88 : 16),
                      itemCount: _filteredTracks.length + (_likedLoadingMore && _searchQuery.isEmpty ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _filteredTracks.length) {
                          return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFC3F1D)),
                            ),
                          );
                        }
                        final t = _filteredTracks[i];
                        final isActive = _queueIdx >= 0 &&
                            _queueIdx < _queue.length &&
                            _queue[_queueIdx].id == t.id;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                          onTap: () {
                            final srcList = _searchQuery.isEmpty ? _likedTracks : _filteredTracks;
                            _playTrack(srcList, i);
                          },
                          onLongPress: () => showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (_) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(Icons.upload_file_rounded, color: Color(0xFFFC3F1D)),
                                    title: const Text('Заменить версию'),
                                    subtitle: const Text('Загрузить свой аудиофайл'),
                                    onTap: () { Navigator.pop(context); _replaceTrack(t); },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: t.coverUrl != null
                                ? Image.network(t.coverUrl!, width: 46, height: 46, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _trackPlaceholder())
                                : _trackPlaceholder(),
                          ),
                          title: Text(t.title,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                                color: isActive ? const Color(0xFFFC3F1D) : null,
                              )),
                          subtitle: Text(t.artist,
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5))),
                          trailing: isActive
                              ? Icon(
                                  _isPlaying ? Icons.equalizer_rounded : Icons.pause_circle_outline_rounded,
                                  color: const Color(0xFFFC3F1D),
                                  size: 20,
                                )
                              : null,
                        );
                      },
                    ),
        ),
        // ── Мини-плеер ────────────────────────────────────────────
        if (_queueIdx >= 0) _buildMiniPlayer(cs),
      ],
    );
  }

  Widget _buildMiniPlayer(ColorScheme cs) {
    final track = _queueIdx >= 0 && _queueIdx < _queue.length ? _queue[_queueIdx] : null;
    if (track == null) return const SizedBox.shrink();

    final progress = _dur.inMilliseconds > 0
        ? (_pos.inMilliseconds / _dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    String fmt(Duration d) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '$m:$s';
    }

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Прогресс-бар
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              trackHeight: 2,
            ),
            child: Slider(
              value: progress,
              min: 0,
              max: 1,
              activeColor: const Color(0xFFFC3F1D),
              inactiveColor: cs.onSurface.withValues(alpha: 0.1),
              onChanged: _dur.inMilliseconds > 0
                  ? (v) => _player.seek(Duration(milliseconds: (v * _dur.inMilliseconds).round()))
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                // Обложка
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: track.coverUrl != null
                      ? Image.network(track.coverUrl!, width: 42, height: 42, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _trackPlaceholder())
                      : _trackPlaceholder(),
                ),
                const SizedBox(width: 10),
                // Название + прогресс
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(track.artist,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                      Text('${fmt(_pos)} / ${fmt(_dur)}',
                          style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.35))),
                    ],
                  ),
                ),
                // Управление
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  iconSize: 26,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  onPressed: _playPrev,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                if (_playerLoading)
                  const SizedBox(
                    width: 32, height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFC3F1D)),
                  )
                else
                  IconButton(
                    icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    iconSize: 32,
                    color: const Color(0xFFFC3F1D),
                    onPressed: _togglePlayPause,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 26,
                  color: cs.onSurface.withValues(alpha: 0.7),
                  onPressed: _playNext,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackPlaceholder() => Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFFFC3F1D).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: const Icon(Icons.music_note_rounded, color: Color(0xFFFC3F1D), size: 22),
      );


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
