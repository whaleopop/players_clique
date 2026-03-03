import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

import '../../config/fcm_service_account.dart';

/// Sends FCM push notifications directly via FCM HTTP v1 API.
/// No Cloud Functions required — uses a service account for auth.
class NotificationSender {
  static const _projectId = 'players-clique';
  static const _fcmUrl =
      'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';
  static const _scopes = [
    'https://www.googleapis.com/auth/firebase.messaging'
  ];

  // Cache the access token (valid 1 hour).
  static String? _cachedToken;
  static DateTime? _tokenExpiry;

  static Future<String?> _getAccessToken() async {
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }
    try {
      final credentials =
          ServiceAccountCredentials.fromJson(fcmServiceAccount);
      final authClient =
          await clientViaServiceAccount(credentials, _scopes);
      _cachedToken = authClient.credentials.accessToken.data;
      _tokenExpiry = authClient.credentials.accessToken.expiry
          .subtract(const Duration(minutes: 2));
      authClient.close();
      return _cachedToken;
    } catch (e) {
      debugPrint('FCM auth error: $e');
      return null;
    }
  }

  static Future<void> _send(
      String fcmToken, String title, String body, Map<String, String> data) async {
    final accessToken = await _getAccessToken();
    if (accessToken == null) return;
    try {
      final res = await http.post(
        Uri.parse(_fcmUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': fcmToken,
            'notification': {'title': title, 'body': body},
            'data': data,
            'android': {'priority': 'high'},
            'apns': {
              'payload': {
                'aps': {'sound': 'default', 'badge': 1}
              }
            },
          },
        }),
      );
      if (res.statusCode != 200) {
        debugPrint('FCM send failed ${res.statusCode}: ${res.body}');
        // If token is stale, clean it up.
        if (res.statusCode == 404 || res.statusCode == 400) {
          final body = jsonDecode(res.body);
          final status = body['error']?['status'] as String? ?? '';
          if (status == 'UNREGISTERED' || status == 'INVALID_ARGUMENT') {
            // Token no longer valid — caller should clear it.
          }
        }
      }
    } catch (e) {
      debugPrint('FCM send error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Notify [receiverId] about a new message from [senderId].
  static Future<void> sendMessageNotification({
    required String senderId,
    required String receiverId,
    required String messageText,
    required String messageType,
    required String chatRoomId,
  }) async {
    final db = FirebaseFirestore.instance;

    // Get receiver token + sender name in parallel.
    final results = await Future.wait([
      db.collection('users').doc(receiverId).get(),
      db.collection('users').doc(senderId).get(),
    ]);

    final receiverData = results[0].data();
    final senderData = results[1].data();
    final fcmToken = receiverData?['fcmToken'] as String?;
    if (fcmToken == null || fcmToken.isEmpty) return;

    final senderName = senderData?['fio'] as String? ?? 'Пользователь';

    String body;
    if (messageType == 'image') {
      body = '📷 Фото';
    } else if (messageType == 'sticker') {
      body = '🎉 Стикер';
    } else {
      body = messageText.length > 120
          ? '${messageText.substring(0, 120)}…'
          : messageText;
    }

    await _send(fcmToken, senderName, body, {
      'type': 'message',
      'chatRoomId': chatRoomId,
      'senderId': senderId,
    });
  }

  /// Notify all friends of [authorId] about a new post.
  static Future<void> sendPostNotification({
    required String authorId,
    required String postTitle,
    required String postDesc,
    required String postId,
  }) async {
    final db = FirebaseFirestore.instance;
    final authorSnap = await db.collection('users').doc(authorId).get();
    final authorData = authorSnap.data();
    if (authorData == null) return;

    final authorName = authorData['fio'] as String? ?? 'Пользователь';
    final friends = List<String>.from(authorData['friends'] ?? []);
    if (friends.isEmpty) return;

    String body = postTitle.isNotEmpty ? postTitle : postDesc;
    if (body.length > 120) body = '${body.substring(0, 120)}…';
    if (body.isEmpty) body = 'Новый пост';

    // Send in parallel (batches of 10 to avoid overwhelming).
    const batchSize = 10;
    for (int i = 0; i < friends.length; i += batchSize) {
      final batch = friends.skip(i).take(batchSize).toList();
      final snaps = await Future.wait(
        batch.map((uid) => db.collection('users').doc(uid).get()),
      );
      await Future.wait(snaps.map((snap) async {
        final token = snap.data()?['fcmToken'] as String?;
        if (token == null || token.isEmpty) return;
        await _send(
          token,
          '$authorName опубликовал(а)',
          body,
          {'type': 'post', 'postId': postId, 'authorId': authorId},
        );
      }));
    }
  }
}
