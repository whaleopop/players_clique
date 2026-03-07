import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TrackInfo {
  final String id;
  final String title;
  final String artist;
  final String artistId;
  final String? coverUrl;
  final bool paused;

  const TrackInfo({
    this.id = '',
    required this.title,
    required this.artist,
    this.artistId = '',
    this.coverUrl,
    this.paused = false,
  });
}

class ArtistInfo {
  final String id;
  final String name;
  final String? coverUrl;
  const ArtistInfo({required this.id, required this.name, this.coverUrl});
}

class YnisonService {
  static const _base = 'https://api.music.yandex.net';

  /// Возвращает Яндекс UID текущего пользователя.
  static Future<int?> fetchAccountUid(String token) async {
    final resp = await http.get(
      Uri.parse('$_base/account/status'),
      headers: {'Authorization': 'OAuth $token'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    return data['result']?['account']?['uid'] as int?;
  }

  // ── Liked tracks ──────────────────────────────────────────────────────────

  /// Возвращает все ID любимых треков (быстро — только идентификаторы).
  static Future<List<Map<String, String>>> fetchLikedIds(String token) async {
    final uid = await fetchAccountUid(token);
    if (uid == null) return [];
    final resp = await http.get(
      Uri.parse('$_base/users/$uid/likes/tracks'),
      headers: {'Authorization': 'OAuth $token'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];
    final raw = (jsonDecode(resp.body) as Map<String, dynamic>)['result']?['library']?['tracks'] as List? ?? [];
    return raw
        .map((t) => {'id': t['id']?.toString() ?? '', 'albumId': t['albumId']?.toString() ?? ''})
        .where((m) => m['id']!.isNotEmpty)
        .toList();
  }

  /// Загружает детали для конкретного среза [ids] (для пагинации).
  static Future<List<TrackInfo>> fetchTracksDetails(
      String token, List<Map<String, String>> ids) async {
    if (ids.isEmpty) return [];
    final trackIds = ids.map((m) {
      final id = m['id']!;
      final albumId = m['albumId'] ?? '';
      return albumId.isNotEmpty ? '$id:$albumId' : id;
    }).toList();
    final body = trackIds.map((id) => 'track-ids=${Uri.encodeComponent(id)}').join('&');
    final resp = await http.post(
      Uri.parse('$_base/tracks'),
      headers: {'Authorization': 'OAuth $token', 'Content-Type': 'application/x-www-form-urlencoded'},
      body: body,
    ).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) return [];
    return ((jsonDecode(resp.body)['result'] as List?) ?? []).map(_parseTrack).toList();
  }

  // ── Track URL (MD5) ────────────────────────────────────────────────────────

  /// Возвращает прямую ссылку для воспроизведения трека.
  static Future<String?> fetchTrackUrl(String token, String trackId) async {
    final resp = await http.get(
      Uri.parse('$_base/tracks/$trackId/download-info'),
      headers: {'Authorization': 'OAuth $token'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;

    final infos = (jsonDecode(resp.body)['result'] as List?) ?? [];
    final mp3s = infos.where((i) => i['codec'] == 'mp3').toList()
      ..sort((a, b) => (b['bitrateInKbps'] as int? ?? 0)
          .compareTo(a['bitrateInKbps'] as int? ?? 0));
    if (mp3s.isEmpty) return null;

    final infoUrl = mp3s.first['downloadInfoUrl'] as String?;
    if (infoUrl == null) return null;

    final xmlResp = await http.get(Uri.parse(infoUrl)).timeout(const Duration(seconds: 10));
    if (xmlResp.statusCode != 200) return null;

    final x = xmlResp.body;
    final host = _xmlTag(x, 'host');
    final path = _xmlTag(x, 'path');
    final ts = _xmlTag(x, 'ts');
    final s = _xmlTag(x, 's');
    if (host == null || path == null || ts == null || s == null) return null;

    final sign = md5.convert(utf8.encode('XGRlBW9FXlekgbPrRHuSiA${path.substring(1)}$s')).toString();
    return 'https://$host/get-mp3/$sign/$ts$path';
  }

  static String? _xmlTag(String xml, String tag) {
    final s = xml.indexOf('<$tag>');
    final e = xml.indexOf('</$tag>');
    if (s == -1 || e == -1) return null;
    return xml.substring(s + tag.length + 2, e);
  }

  // ── My Wave ────────────────────────────────────────────────────────────────

  /// Загружает треки «Моей волны».
  static Future<List<TrackInfo>> fetchMyWaveTracks(String token) async {
    final resp = await http.post(
      Uri.parse('$_base/rotor/station/user:onyourwave/tracks'),
      headers: {'Authorization': 'OAuth $token', 'Content-Type': 'application/json'},
      body: '{}',
    ).timeout(const Duration(seconds: 12));
    if (resp.statusCode != 200) return [];
    final sequence = (jsonDecode(resp.body)['result']?['sequence'] as List?) ?? [];
    return sequence
        .map((item) => _parseTrack(item['track'] as Map<String, dynamic>? ?? {}))
        .where((t) => t.id.isNotEmpty)
        .toList();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static TrackInfo _parseTrack(dynamic t) {
    final id = t['id']?.toString() ?? '';
    final title = t['title'] as String? ?? 'Неизвестный трек';
    final artists = t['artists'] as List? ?? [];
    final artist = artists
            .map((a) => a['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ');
    final artistId = (artists.isNotEmpty ? artists[0]['id']?.toString() : null) ?? '';
    String? coverUrl;
    final albums = t['albums'] as List?;
    if (albums != null && albums.isNotEmpty) {
      final rawUri = albums[0]['coverUri'] as String?;
      if (rawUri != null) {
        coverUrl = 'https://${rawUri.replaceFirst('//', '').replaceAll('%%', '200x200')}';
      }
    }
    return TrackInfo(
      id: id,
      title: title,
      artist: artist.isEmpty ? 'Неизвестный артист' : artist,
      artistId: artistId,
      coverUrl: coverUrl,
    );
  }

  // ── Search ────────────────────────────────────────────────────────────────

  static Future<List<TrackInfo>> searchTracks(String token, String query) async {
    if (query.isEmpty) return [];
    final resp = await http.get(
      Uri.parse('$_base/search?text=${Uri.encodeComponent(query)}&type=track&page=0'),
      headers: {'Authorization': 'OAuth $token'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];
    final results = (jsonDecode(resp.body)['result']?['tracks']?['results'] as List?) ?? [];
    return results.map(_parseTrack).toList();
  }

  // ── Artist ────────────────────────────────────────────────────────────────

  static Future<ArtistInfo?> fetchArtistInfo(String token, String artistId) async {
    final resp = await http.get(
      Uri.parse('$_base/artists/$artistId/brief-info'),
      headers: {'Authorization': 'OAuth $token'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return null;
    final a = jsonDecode(resp.body)['result']?['artist'] as Map<String, dynamic>?;
    if (a == null) return null;
    final name = a['name'] as String? ?? '';
    String? coverUrl;
    final rawCover = a['cover']?['uri'] as String?;
    if (rawCover != null) {
      coverUrl = 'https://${rawCover.replaceFirst('//', '').replaceAll('%%', '300x300')}';
    }
    return ArtistInfo(id: artistId, name: name, coverUrl: coverUrl);
  }

  static Future<List<TrackInfo>> fetchArtistTracks(String token, String artistId, {int page = 0}) async {
    final resp = await http.get(
      Uri.parse('$_base/artists/$artistId/tracks?page=$page&pageSize=30'),
      headers: {'Authorization': 'OAuth $token'},
    ).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) return [];
    final list = (jsonDecode(resp.body)['result']?['tracks'] as List?) ?? [];
    return list.map(_parseTrack).toList();
  }

  static String _deviceId() {
    final r = Random();
    const chars = 'abcdef0123456789';
    return List.generate(32, (_) => chars[r.nextInt(chars.length)]).join();
  }

  // Браузер не поддерживает произвольные символы в Sec-WebSocket-Protocol
  static Future<TrackInfo?> fetchCurrentTrack(String token) async {
    if (kIsWeb) return null;

    final deviceId = _deviceId();
    final wsProto = <String, dynamic>{
      'Ynison-Device-Id': deviceId,
      'Ynison-Device-Info': jsonEncode({'app_name': 'Chrome', 'type': 1}),
    };

    // ── 1. Редирект ──────────────────────────────────────────────────────────
    final protoHeader = 'Bearer, v2, ${jsonEncode(wsProto)}';
    final redirectWs = await io.WebSocket.connect(
      'wss://ynison.music.yandex.ru/redirector.YnisonRedirectService/GetRedirectToYnison',
      headers: {
        'Sec-WebSocket-Protocol': protoHeader,
        'Authorization': 'OAuth $token',
        'Origin': 'http://music.yandex.ru',
      },
    ).timeout(const Duration(seconds: 10));

    final Map<String, dynamic> redirectJson;
    try {
      final raw = await redirectWs
          .timeout(const Duration(seconds: 10))
          .first;
      redirectJson = jsonDecode(raw as String);
    } finally {
      await redirectWs.close();
    }

    final host = redirectJson['host'] as String;
    final ticket = redirectJson['redirect_ticket'] as String;
    wsProto['Ynison-Redirect-Ticket'] = ticket;

    // ── 2. Получаем состояние плеера ─────────────────────────────────────────
    final payload = jsonEncode({
      'update_full_state': {
        'player_state': {
          'player_queue': {
            'current_playable_index': -1,
            'entity_id': '',
            'entity_type': 'VARIOUS',
            'playable_list': [],
            'options': {'repeat_mode': 'NONE'},
            'entity_context': 'BASED_ON_ENTITY_BY_DEFAULT',
            'version': {
              'device_id': deviceId,
              'version': 9021243204784340992,
              'timestamp_ms': 0,
            },
            'from_optional': '',
          },
          'status': {
            'duration_ms': 0,
            'paused': true,
            'playback_speed': 1,
            'progress_ms': 0,
            'version': {
              'device_id': deviceId,
              'version': 8321822175199936512,
              'timestamp_ms': 0,
            },
          },
        },
        'device': {
          'capabilities': {
            'can_be_player': true,
            'can_be_remote_controller': false,
            'volume_granularity': 16,
          },
          'info': {
            'device_id': deviceId,
            'type': 'WEB',
            'title': 'Chrome Browser',
            'app_name': 'Chrome',
          },
          'volume_info': {'volume': 0},
          'is_shadow': true,
        },
        'is_currently_active': false,
      },
      'rid': 'ac281c26-a047-4419-ad00-e4fbfda1cba3',
      'player_action_timestamp_ms': 0,
      'activity_interception_type': 'DO_NOT_INTERCEPT_BY_DEFAULT',
    });

    final stateProtoHeader = 'Bearer, v2, ${jsonEncode(wsProto)}';
    final stateWs = await io.WebSocket.connect(
      'wss://$host/ynison_state.YnisonStateService/PutYnisonState',
      headers: {
        'Sec-WebSocket-Protocol': stateProtoHeader,
        'Authorization': 'OAuth $token',
        'Origin': 'http://music.yandex.ru',
      },
    ).timeout(const Duration(seconds: 10));

    final Map<String, dynamic> ynison;
    try {
      stateWs.add(payload);
      final raw = await stateWs
          .timeout(const Duration(seconds: 10))
          .first;
      ynison = jsonDecode(raw as String);
    } finally {
      await stateWs.close();
    }

    // ── 3. Извлекаем трек ────────────────────────────────────────────────────
    final playerQueue =
        ynison['player_state']?['player_queue'] as Map<String, dynamic>?;
    if (playerQueue == null) return null;

    final currentIndex = playerQueue['current_playable_index'] as int? ?? -1;
    final playableList = playerQueue['playable_list'] as List? ?? [];

    if (currentIndex < 0 || currentIndex >= playableList.length) return null;

    final trackId = playableList[currentIndex]['playable_id'] as String?;
    if (trackId == null) return null;

    final paused =
        ynison['player_state']?['status']?['paused'] as bool? ?? true;

    // ── 4. Детали трека через Yandex Music API ───────────────────────────────
    final trackResp = await http.get(
      Uri.parse('https://api.music.yandex.net/tracks/$trackId'),
      headers: {'Authorization': 'OAuth $token'},
    ).timeout(const Duration(seconds: 10));

    if (trackResp.statusCode != 200) return null;

    final trackData = jsonDecode(trackResp.body);
    final result = trackData['result'];
    final t = (result is List && result.isNotEmpty) ? result[0] : result;

    final title = t['title'] as String? ?? 'Неизвестный трек';
    final artist = (t['artists'] as List?)
            ?.map((a) => a['name'] as String? ?? '')
            .where((n) => n.isNotEmpty)
            .join(', ') ??
        'Неизвестный артист';

    String? coverUrl;
    final albums = t['albums'] as List?;
    if (albums != null && albums.isNotEmpty) {
      final raw = albums[0]['coverUri'] as String?;
      if (raw != null) {
        coverUrl =
            'https://${raw.replaceFirst('//', '').replaceAll('%%', '400x400')}';
      }
    }

    return TrackInfo(
      title: title,
      artist: artist,
      coverUrl: coverUrl,
      paused: paused,
    );
  }
}
