import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TrackInfo {
  final String title;
  final String artist;
  final String? coverUrl;
  final bool paused;

  const TrackInfo({
    required this.title,
    required this.artist,
    this.coverUrl,
    this.paused = false,
  });
}

class YnisonService {
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
