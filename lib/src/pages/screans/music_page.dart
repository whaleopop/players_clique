import 'dart:async';
import 'dart:io' show File;

import 'package:cached_network_image/cached_network_image.dart';

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

  // ── Search (Yandex API) ───────────────────────────────────────────────────
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  List<TrackInfo> _searchResults = [];
  bool _searchLoading = false;
  Timer? _searchDebounce;

  // ── Player ────────────────────────────────────────────────────────────────
  late MusicService _musicService;
  final _player = AudioPlayer();
  List<TrackInfo> _queue = [];
  int _queueIdx = -1;
  bool _isPlaying = false;
  bool _playerLoading = false;
  Duration _pos = Duration.zero;
  Duration _dur = Duration.zero;

  // ── Legend ────────────────────────────────────────────────────────────────
  bool _isLegend = false;
  bool _isReplacing = false;

  // ── Helpers ───────────────────────────────────────────────────────────────
  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  bool get _isSearching => _searchQuery.isNotEmpty;

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
    _searchCtrl.addListener(_onSearchChanged);
    _loadToken();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _musicService = Provider.of<MusicService>(context, listen: false);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _listCtrl.dispose();
    _searchCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text;
    if (mounted) setState(() { _searchQuery = q; });
    _searchDebounce?.cancel();
    if (q.isEmpty) {
      if (mounted) setState(() { _searchResults = []; _searchLoading = false; });
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), _doSearch);
  }

  Future<void> _doSearch() async {
    if (_token == null || _searchQuery.isEmpty) return;
    setState(() => _searchLoading = true);
    try {
      final results = await YnisonService.searchTracks(_token!, _searchQuery);
      if (mounted) setState(() { _searchResults = results; _searchLoading = false; });
    } catch (_) {
      if (mounted) setState(() { _searchResults = []; _searchLoading = false; });
    }
  }

  void _onScroll() {
    if (!_isSearching &&
        _listCtrl.position.pixels >= _listCtrl.position.maxScrollExtent - 200) {
      _loadMoreLiked();
    }
  }

  // ── Token / auth ──────────────────────────────────────────────────────────

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

    if (token == null) {
      final uid = _uid;
      if (uid != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        token = doc.data()?['yandex_music_token'] as String?;
        if (token != null) await prefs.setString(_tokenKey, token);
      }
    }

    setState(() { _token = token; _loading = false; });
    if (token != null) _startTracking();
  }

  Future<void> _startTracking() async {
    _loadAllLiked();
    await _loadLegendStatus();
  }

  Future<void> _loadLegendStatus() async {
    final uid = _uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final legend = doc.data()?['isLegend'] as bool? ?? false;
    if (mounted) setState(() => _isLegend = legend);
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

  // ── Playback ──────────────────────────────────────────────────────────────

  Future<void> _playTrack(List<TrackInfo> queue, int index) async {
    if (index < 0 || index >= queue.length) return;
    final track = queue[index];
    if (track.id.isEmpty) return;
    setState(() {
      _queue = queue; _queueIdx = index;
      _playerLoading = true; _pos = Duration.zero; _dur = Duration.zero;
    });
    _musicService.setCurrentTrack(track, isPlaying: false);
    try {
      // Сначала проверяем глобальную замену (доступна всем)
      String? url;
      final doc = await FirebaseFirestore.instance
          .collection('globalTracks').doc(track.id).get();
      url = doc.data()?['audioUrl'] as String?;

      url ??= await YnisonService.fetchTrackUrl(_token!, track.id);
      if (!mounted) return;
      if (url == null) {
        setState(() => _playerLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Не удалось получить ссылку')));
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

  // ── Legend: глобальная замена трека ──────────────────────────────────────

  Future<void> _replaceTrack(TrackInfo track) async {
    if (!_isLegend) return;
    if (_isReplacing) return;
    final uid = _uid;
    if (uid == null) return;

    setState(() => _isReplacing = true);
    PlatformFile? file;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg', 'flac'],
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isReplacing = false);
        return;
      }
      file = result.files.first;
    } catch (e) {
      if (mounted) {
        setState(() => _isReplacing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Не удалось открыть файл: $e')));
      }
      return;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Загрузка...')));
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('global_tracks/${track.id}_$ts.mp3');
      final task = (!kIsWeb && file.path != null)
          ? ref.putFile(File(file.path!))
          : ref.putData(file.bytes!);
      final snap = await task;
      final url = await snap.ref.getDownloadURL();

      // Глобальная запись — слышат все
      await FirebaseFirestore.instance.collection('globalTracks').doc(track.id).set({
        'audioUrl': url,
        'trackId': track.id,
        'title': track.title,
        'artist': track.artist,
        'uploadedBy': uid,
        'uploadedAt': FieldValue.serverTimestamp(),
      });

      // Создаём пост в ленте
      await FirebaseFirestore.instance
          .collection('posts')
          .doc(uid)
          .collection('post')
          .add({
        'userId': uid,
        'namePost': track.title,
        'descPost': track.artist,
        'imageUrl': track.coverUrl ?? '',
        'mediaType': 'trackReplace',
        'trackId': track.id,
        'trackTitle': track.title,
        'trackArtist': track.artist,
        'trackCoverUrl': track.coverUrl ?? '',
        'replacementUrl': url,
        'timestamp': FieldValue.serverTimestamp(),
        'likedBy': <String>[],
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Версия загружена для всех')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _isReplacing = false);
    }
  }

  // ── OAuth ─────────────────────────────────────────────────────────────────

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
    setState(() {
      _token = null;
      _isLegend = false;
      _allIds = [];
      _likedTracks = [];
      _searchResults = [];
      _searchQuery = '';
      _queue = [];
      _queueIdx = -1;
    });
    _searchCtrl.clear();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
          GestureDetector(onTap: _openOAuth, child: _yandexLogo()),
          const SizedBox(height: 20),
          const Text('Яндекс Музыка',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFC3F1D))),
          const SizedBox(height: 8),
          Text('Нажми на логотип для входа',
              style: TextStyle(
                  fontSize: 14, color: cs.onSurface.withValues(alpha: 0.45))),
        ],
      ),
    );
  }

  Widget _buildConnected(ColorScheme cs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Шапка ─────────────────────────────────────────────────
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
                      blurRadius: 12, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('Я',
                      style: TextStyle(color: Colors.white, fontSize: 28,
                          fontWeight: FontWeight.bold, height: 1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('Яндекс Музыка',
                          style: TextStyle(fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFC3F1D))),
                      if (_isLegend) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                          ),
                          child: const Text('Лега',
                              style: TextStyle(fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFD700))),
                        ),
                      ],
                    ]),
                    Row(children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green.shade400, size: 13),
                      const SizedBox(width: 4),
                      Text('Подключено',
                          style: TextStyle(fontSize: 12,
                              color: Colors.green.shade400,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 19,
                    color: cs.onSurface.withValues(alpha: 0.3)),
                tooltip: 'Скопировать токен',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _token!));
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Токен скопирован'),
                          duration: Duration(seconds: 2)));
                },
              ),
              IconButton(
                icon: Icon(Icons.logout_rounded, size: 19,
                    color: cs.onSurface.withValues(alpha: 0.3)),
                tooltip: 'Выйти',
                onPressed: _logout,
              ),
            ],
          ),
        ),
        // ── Поиск ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Поиск по Яндекс Музыке...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20,
                  color: Color(0xFFFC3F1D)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => _searchCtrl.clear())
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
              filled: true,
              fillColor: cs.onSurface.withValues(alpha: 0.06),
            ),
          ),
        ),
        // ── Заголовок списка ──────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: [
              Icon(
                _isSearching ? Icons.search_rounded : Icons.favorite_rounded,
                size: 16, color: const Color(0xFFFC3F1D),
              ),
              const SizedBox(width: 6),
              Text(
                _isSearching
                    ? 'Результаты поиска'
                    : (_allIds.isEmpty
                        ? 'Любимые треки'
                        : 'Любимые треки (${_likedTracks.length}/${_allIds.length})'),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const Spacer(),
              if (!_isSearching)
                if (_likedLoading)
                  const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFC3F1D)))
                else
                  GestureDetector(
                    onTap: _loadAllLiked,
                    child: Icon(Icons.refresh_rounded, size: 18,
                        color: cs.onSurface.withValues(alpha: 0.3)),
                  ),
            ],
          ),
        ),
        // ── Список ────────────────────────────────────────────────
        Expanded(child: _buildList(cs)),
        // ── Мини-плеер ────────────────────────────────────────────
        if (_queueIdx >= 0) _buildMiniPlayer(cs),
      ],
    );
  }

  Widget _buildList(ColorScheme cs) {
    if (_isSearching) {
      if (_searchLoading) {
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFFFC3F1D)));
      }
      if (_searchResults.isEmpty) {
        return Center(
            child: Text('Ничего не найдено',
                style: TextStyle(
                    color: cs.onSurface.withValues(alpha: 0.35))));
      }
      return ListView.builder(
        padding: EdgeInsets.only(bottom: _queueIdx >= 0 ? 88 : 16),
        itemCount: _searchResults.length,
        itemBuilder: (context, i) =>
            _buildTrackTile(_searchResults[i], _searchResults, i, cs),
      );
    }

    // Любимые треки
    if (_likedLoading && _likedTracks.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFFFC3F1D)));
    }
    if (_likedTracks.isEmpty) {
      return Center(
          child: Text('Нет треков',
              style:
                  TextStyle(color: cs.onSurface.withValues(alpha: 0.35))));
    }
    return ListView.builder(
      controller: _listCtrl,
      padding: EdgeInsets.only(bottom: _queueIdx >= 0 ? 88 : 16),
      itemCount: _likedTracks.length + (_likedLoadingMore ? 1 : 0),
      itemBuilder: (context, i) {
        if (i == _likedTracks.length) {
          return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFFC3F1D))));
        }
        return _buildTrackTile(_likedTracks[i], _likedTracks, i, cs);
      },
    );
  }

  Widget _buildTrackTile(
      TrackInfo t, List<TrackInfo> queue, int i, ColorScheme cs) {
    final isActive = _queueIdx >= 0 &&
        _queueIdx < _queue.length &&
        _queue[_queueIdx].id == t.id;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      onTap: () => _playTrack(queue, i),
      onLongPress: () => _showTrackMenu(t, cs),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: t.coverUrl != null
            ? CachedNetworkImage(imageUrl: t.coverUrl!, width: 46, height: 46,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _trackPlaceholder())
            : _trackPlaceholder(),
      ),
      title: Text(t.title,
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: isActive ? const Color(0xFFFC3F1D) : null)),
      subtitle: GestureDetector(
        onTap: t.artistId.isNotEmpty && _token != null
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => _YandexArtistPage(
                        artistId: t.artistId, token: _token!,
                        isLegend: _isLegend,
                        onReplace: _replaceTrack)))
            : null,
        child: Text(t.artist,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                color: t.artistId.isNotEmpty
                    ? const Color(0xFFFC3F1D).withValues(alpha: 0.7)
                    : cs.onSurface.withValues(alpha: 0.5),
                decoration: t.artistId.isNotEmpty
                    ? TextDecoration.underline
                    : null)),
      ),
      trailing: isActive
          ? Icon(
              _isPlaying
                  ? Icons.equalizer_rounded
                  : Icons.pause_circle_outline_rounded,
              color: const Color(0xFFFC3F1D), size: 20)
          : null,
    );
  }

  void _showTrackMenu(TrackInfo t, ColorScheme cs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36, height: 4, margin: const EdgeInsets.only(top: 10, bottom: 6),
              decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                if (t.coverUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(imageUrl: t.coverUrl!, width: 40, height: 40,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => const SizedBox()),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
                  ]),
                ),
              ]),
            ),
            const Divider(height: 1),
            if (_isLegend)
              ListTile(
                leading: const Icon(Icons.upload_file_rounded, color: Color(0xFFFFD700)),
                title: const Text('Заменить версию (глобально)'),
                subtitle: const Text('Альтернативный файл услышат все'),
                onTap: () {
                  Navigator.pop(context);
                  Future.delayed(
                    const Duration(milliseconds: 350),
                    () { if (mounted) _replaceTrack(t); },
                  );
                },
              ),
            if (t.artistId.isNotEmpty && _token != null)
              ListTile(
                leading: const Icon(Icons.person_rounded, color: Color(0xFFFC3F1D)),
                title: Text('Артист: ${t.artist}'),
                subtitle: const Text('Открыть страницу артиста'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(
                      builder: (_) => _YandexArtistPage(
                          artistId: t.artistId, token: _token!,
                          isLegend: _isLegend, onReplace: _replaceTrack)));
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayer(ColorScheme cs) {
    final track = _queueIdx >= 0 && _queueIdx < _queue.length
        ? _queue[_queueIdx]
        : null;
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
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 12, offset: const Offset(0, -2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              trackHeight: 2,
            ),
            child: Slider(
              value: progress, min: 0, max: 1,
              activeColor: const Color(0xFFFC3F1D),
              inactiveColor: cs.onSurface.withValues(alpha: 0.1),
              onChanged: _dur.inMilliseconds > 0
                  ? (v) => _player.seek(Duration(
                      milliseconds: (v * _dur.inMilliseconds).round()))
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: track.coverUrl != null
                      ? CachedNetworkImage(imageUrl: track.coverUrl!, width: 42, height: 42,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _trackPlaceholder())
                      : _trackPlaceholder(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(track.artist, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11,
                            color: cs.onSurface.withValues(alpha: 0.5))),
                    Text('${fmt(_pos)} / ${fmt(_dur)}',
                        style: TextStyle(fontSize: 10,
                            color: cs.onSurface.withValues(alpha: 0.35))),
                  ]),
                ),
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFFC3F1D)))
                else
                  IconButton(
                    icon: Icon(_isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded),
                    iconSize: 32,
                    color: const Color(0xFFFC3F1D),
                    onPressed: _togglePlayPause,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 40),
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
        child: const Icon(Icons.music_note_rounded,
            color: Color(0xFFFC3F1D), size: 22),
      );

  Widget _yandexLogo() {
    return Container(
      width: 110, height: 110,
      decoration: BoxDecoration(
        color: const Color(0xFFFC3F1D),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFFFC3F1D).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 8)),
        ],
      ),
      child: const Center(
        child: Text('Я',
            style: TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.bold,
                height: 1)),
      ),
    );
  }
}

// ── OAuth WebView ─────────────────────────────────────────────────────────────

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
    final uri = Uri.parse(url);
    if (uri.host != _oauthRedirectHost) return null;
    return Uri.splitQueryString(uri.fragment)['access_token'];
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
                child: CircularProgressIndicator(color: Color(0xFFFC3F1D))),
        ],
      ),
    );
  }
}

// ── Страница артиста (Yandex Music API) ───────────────────────────────────────

class _YandexArtistPage extends StatefulWidget {
  final String artistId;
  final String token;
  final bool isLegend;
  final Future<void> Function(TrackInfo) onReplace;

  const _YandexArtistPage({
    required this.artistId,
    required this.token,
    required this.isLegend,
    required this.onReplace,
  });

  @override
  State<_YandexArtistPage> createState() => _YandexArtistPageState();
}

class _YandexArtistPageState extends State<_YandexArtistPage> {
  ArtistInfo? _artist;
  List<TrackInfo> _tracks = [];
  bool _loadingTracks = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final artist = await YnisonService.fetchArtistInfo(
        widget.token, widget.artistId);
    final tracks = await YnisonService.fetchArtistTracks(
        widget.token, widget.artistId);
    if (mounted) {
      setState(() {
        _artist = artist;
        _tracks = tracks;
        _loadingTracks = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = _artist?.name ?? '...';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Шапка артиста
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w800,
                      shadows: [Shadow(blurRadius: 8)])),
              background: _artist?.coverUrl != null
                  ? Stack(fit: StackFit.expand, children: [
                      CachedNetworkImage(imageUrl: _artist!.coverUrl!, fit: BoxFit.cover),
                      Container(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.7)
                                  ]))),
                    ])
                  : Container(
                      decoration: const BoxDecoration(
                          gradient: LinearGradient(
                              colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]))),
            ),
          ),
          // Legend badge
          if (widget.isLegend)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.4)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.upload_file_rounded, size: 13,
                          color: Color(0xFFFFD700)),
                      SizedBox(width: 5),
                      Text('Удерживай трек для замены',
                          style: TextStyle(fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFFFD700))),
                    ]),
                  ),
                ]),
              ),
            ),
          // Треки
          _loadingTracks
              ? const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(color: Color(0xFFFC3F1D))))
              : _tracks.isEmpty
                  ? SliverFillRemaining(
                      child: Center(
                          child: Text('Нет треков',
                              style: TextStyle(
                                  color: cs.onSurface.withValues(alpha: 0.4)))))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final t = _tracks[i];
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            onLongPress: widget.isLegend
                                ? () async {
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Заменить трек?'),
                                        content: Text(
                                            '"${t.title}" — замена будет слышна всем пользователям.'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context, false),
                                              child: const Text('Отмена')),
                                          ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      const Color(0xFFFFD700)),
                                              onPressed: () =>
                                                  Navigator.pop(context, true),
                                              child: const Text('Заменить',
                                                  style: TextStyle(
                                                      color: Colors.black))),
                                        ],
                                      ),
                                    );
                                    if (confirmed == true) {
                                      await Future.delayed(const Duration(milliseconds: 350));
                                      widget.onReplace(t);
                                    }
                                  }
                                : null,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: t.coverUrl != null
                                  ? CachedNetworkImage(imageUrl: t.coverUrl!, width: 46,
                                      height: 46, fit: BoxFit.cover)
                                  : Container(
                                      width: 46, height: 46,
                                      color: const Color(0xFFFC3F1D)
                                          .withValues(alpha: 0.1),
                                      child: const Icon(
                                          Icons.music_note_rounded,
                                          color: Color(0xFFFC3F1D), size: 22)),
                            ),
                            title: Text(t.title,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500, fontSize: 14)),
                            subtitle: Text(t.artist,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.5))),
                            trailing: widget.isLegend
                                ? const Icon(Icons.more_vert_rounded,
                                    size: 18, color: Color(0xFFFFD700))
                                : null,
                          );
                        },
                        childCount: _tracks.length,
                      ),
                    ),
        ],
      ),
    );
  }
}
