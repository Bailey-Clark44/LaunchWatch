import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Web push needs a VAPID key from Firebase console → Project settings →
/// Cloud Messaging → Web Push certificates. Build with
/// `--dart-define=VAPID_KEY=...`. Phones do not need it.
const _vapidKey = String.fromEnvironment('VAPID_KEY');

class ForegroundAlert {
  const ForegroundAlert({required this.title, required this.body, this.launchId});
  final String title;
  final String body;
  final String? launchId;
}

/// Registers this device for push and reports taps and foreground messages.
class NotificationService {
  final _foreground = StreamController<ForegroundAlert>.broadcast();
  final _opened = StreamController<String>.broadcast();
  final _subs = <StreamSubscription<dynamic>>[];
  String? _token;
  bool _listening = false;

  /// Alerts that arrive while the app is open.
  Stream<ForegroundAlert> get foreground => _foreground.stream;

  /// Launch ids from tapped notifications.
  Stream<String> get opened => _opened.stream;

  bool get webPushConfigured => !kIsWeb || _vapidKey.isNotEmpty;

  FirebaseMessaging? get _messaging {
    try {
      return FirebaseMessaging.instance;
    } catch (_) {
      return null;
    }
  }

  void _listen() {
    if (_listening) return;
    final messaging = _messaging;
    if (messaging == null) return;
    _listening = true;
    _subs
      ..add(FirebaseMessaging.onMessage.listen((m) {
        _foreground.add(ForegroundAlert(
          title: m.notification?.title ?? 'LaunchWatch',
          body: m.notification?.body ?? '',
          launchId: m.data['launchId'] as String?,
        ));
      }))
      ..add(FirebaseMessaging.onMessageOpenedApp.listen((m) {
        final id = m.data['launchId'] as String?;
        if (id != null && id.isNotEmpty) _opened.add(id);
      }));
    messaging.getInitialMessage().then((m) {
      final id = m?.data['launchId'] as String?;
      if (id != null && id.isNotEmpty) _opened.add(id);
    }).catchError((_) {});
  }

  Future<bool> permissionGranted() async {
    final messaging = _messaging;
    if (messaging == null) return false;
    try {
      final settings = await messaging.getNotificationSettings();
      return settings.authorizationStatus == AuthorizationStatus.authorized || settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Saves this device's token under the user. Returns false when alerts
  /// cannot be delivered here (permission denied, or web push not configured).
  /// Alerts still land in the in-app inbox either way.
  Future<bool> register(DocumentReference<Map<String, dynamic>> user, {bool requestPermission = false}) async {
    final messaging = _messaging;
    if (messaging == null || !webPushConfigured) return false;
    try {
      if (requestPermission) {
        final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
        if (settings.authorizationStatus == AuthorizationStatus.denied) return false;
      } else if (!await permissionGranted()) {
        return false;
      }
      _listen();
      // FCM tokens, not the newer installation IDs from register(): the Admin
      // SDK used by the Cloud Functions (firebase-admin 13) sends to tokens.
      // ignore: deprecated_member_use
      final token = await messaging.getToken(vapidKey: kIsWeb ? _vapidKey : null);
      if (token == null) return false;
      _token = token;
      await _save(user, token);
      // ignore: deprecated_member_use
      _subs.add(messaging.onTokenRefresh.listen((t) {
        _token = t;
        _save(user, t);
      }));
      return true;
    } catch (error) {
      debugPrint('Push registration failed: $error');
      return false;
    }
  }

  Future<void> _save(DocumentReference<Map<String, dynamic>> user, String token) {
    return user.collection('devices').doc(tokenId(token)).set({
      'token': token,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stops this device receiving the user's alerts, for sign-out and deletion.
  Future<void> unregister(DocumentReference<Map<String, dynamic>>? user) async {
    final token = _token;
    if (user == null || token == null) return;
    try {
      await user.collection('devices').doc(tokenId(token)).delete();
    } catch (_) {}
    _token = null;
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _foreground.close();
    _opened.close();
  }
}

/// A stable document id for a token: two FNV-1a 32-bit passes, hex.
/// Written with shifts so it gives the same answer on the web (no 64-bit ints).
/// Re-registering the same token overwrites one row.
String tokenId(String token) {
  int fnv(int seed, Iterable<int> units) {
    var hash = seed;
    for (final unit in units) {
      hash = (hash ^ unit) & 0xFFFFFFFF;
      hash = (hash + (hash << 1) + (hash << 4) + (hash << 7) + (hash << 8) + (hash << 24)) & 0xFFFFFFFF;
    }
    return hash;
  }

  final a = fnv(0x811c9dc5, token.codeUnits);
  final b = fnv(0x050c5d1f, token.codeUnits.reversed);
  return '${a.toRadixString(16).padLeft(8, '0')}${b.toRadixString(16).padLeft(8, '0')}';
}
