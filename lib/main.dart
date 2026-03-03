import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:players_clique/firebase_options.dart';
import 'package:players_clique/src/services/auth/auth_gate.dart';
import 'package:players_clique/src/services/auth/auth_service.dart';
import 'package:players_clique/src/services/theme/theme_service.dart';
import 'package:provider/provider.dart';

/// Global ScaffoldMessenger key — used to show notification banners from anywhere.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Save the FCM token to the current user's Firestore document.
Future<void> _saveFcmToken() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      // ignore: avoid_print
      print('🔔 FCM TOKEN: $token');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
    // Refresh token when it rotates.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'fcmToken': newToken}, SetOptions(merge: true));
    });
  } catch (_) {}
}

/// Show a banner in the app when a push notification arrives in foreground.
void _showForegroundNotificationBanner(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;

  final title = notification.title ?? '';
  final body = notification.body ?? '';
  final isMessage = message.data['type'] == 'message';

  scaffoldMessengerKey.currentState?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: const Color(0xFF0071BC),
      duration: const Duration(seconds: 4),
      content: Row(
        children: [
          Icon(
            isMessage ? Icons.chat_bubble_outline : Icons.article_outlined,
            color: Colors.white,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                if (body.isNotEmpty)
                  Text(
                    body,
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Request notification permission (iOS + Android 13+ + web).
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // Save FCM token whenever auth state changes (login / app restart).
  FirebaseAuth.instance.authStateChanges().listen((user) {
    if (user != null) _saveFcmToken();
  });

  // Show in-app banner for foreground notifications.
  FirebaseMessaging.onMessage.listen(_showForegroundNotificationBanner);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ThemeService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeService.themeMode,
        scaffoldMessengerKey: scaffoldMessengerKey,

        // ── Light theme ────────────────────────────────────────────────────
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0071BC),
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF0071BC),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
        ),

        // ── Dark theme ─────────────────────────────────────────────────────
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0071BC),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xFF0D1117),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF161B22),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
          ),
          cardTheme: CardThemeData(
            color: const Color(0xFF21262D),
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          dialogTheme: const DialogThemeData(
            backgroundColor: Color(0xFF161B22),
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: Color(0xFF161B22),
          ),
          dividerColor: Colors.white12,
        ),

        home: const AuthGate(),
      ),
    );
  }
}
