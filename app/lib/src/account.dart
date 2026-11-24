import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'launch_repository.dart';
import 'notifications.dart';
import 'visibility.dart';

/// Alert preferences. The same five switches live on the user and on each follow.
class AlertPrefs {
  const AlertPrefs({this.slips = true, this.status = true, this.liftoff = true, this.outcome = true, this.reminder24h = true});

  final bool slips;
  final bool status;
  final bool liftoff;
  final bool outcome;
  final bool reminder24h;

  factory AlertPrefs.fromMap(Object? raw) {
    final m = raw is Map ? raw : const {};
    bool v(String k) => m[k] is bool ? m[k] as bool : true;
    return AlertPrefs(slips: v('slips'), status: v('status'), liftoff: v('liftoff'), outcome: v('outcome'), reminder24h: v('reminder24h'));
  }

  Map<String, bool> toMap() => {'slips': slips, 'status': status, 'liftoff': liftoff, 'outcome': outcome, 'reminder24h': reminder24h};

  AlertPrefs copyWith({bool? slips, bool? status, bool? liftoff, bool? outcome, bool? reminder24h}) => AlertPrefs(
        slips: slips ?? this.slips,
        status: status ?? this.status,
        liftoff: liftoff ?? this.liftoff,
        outcome: outcome ?? this.outcome,
        reminder24h: reminder24h ?? this.reminder24h,
      );
}

class FollowInfo {
  const FollowInfo({required this.launchId, required this.name, this.createdAt});
  final String launchId;
  final String name;
  final DateTime? createdAt;
}

class WatchedLaunch {
  const WatchedLaunch({required this.launchId, required this.name, this.net, this.vehicle, this.provider, this.imageUrl, this.watchedAt});
  final String launchId;
  final String name;
  final DateTime? net;
  final String? vehicle;
  final String? provider;
  final String? imageUrl;
  final DateTime? watchedAt;
}

class InboxMessage {
  const InboxMessage({required this.id, required this.title, required this.body, required this.launchId, required this.read, this.createdAt, this.kind});
  final String id;
  final String title;
  final String body;
  final String? launchId;
  final bool read;
  final DateTime? createdAt;
  final String? kind;
}

/// Something went wrong that the person can act on. [message] is ready to show.
class AccountException implements Exception {
  const AccountException(this.message, {this.code});
  final String message;
  final String? code;
  @override
  String toString() => message;
}

/// Turns Firebase Auth codes into sentences a person can act on.
String authErrorMessage(Object error) {
  if (error is AccountException) return error.message;
  if (error is! FirebaseAuthException) return 'Something went wrong. Please try again.';
  return switch (error.code) {
    'invalid-email' => 'That email address does not look right.',
    'user-disabled' => 'This account has been disabled. Contact support if you think this is a mistake.',
    'user-not-found' || 'wrong-password' || 'invalid-credential' || 'INVALID_LOGIN_CREDENTIALS' => 'Email or password is incorrect.',
    'email-already-in-use' => 'An account already uses this email. Try signing in instead.',
    'weak-password' => 'Choose a stronger password: at least 8 characters, with a mix of letters and numbers.',
    'too-many-requests' => 'Too many attempts. Wait a few minutes and try again.',
    'network-request-failed' => 'No connection. Check your network and try again.',
    'requires-recent-login' => 'For your security, confirm your password and try again.',
    'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' => 'Sign-in was cancelled.',
    'popup-blocked' => 'Your browser blocked the sign-in window. Allow pop-ups for this site and try again.',
    'account-exists-with-different-credential' => 'You already have an account with this email. Sign in with your original method first.',
    'operation-not-allowed' || 'configuration-not-found' => 'This sign-in method is not switched on yet. Please try another way.',
    'unauthorized-domain' => 'Sign-in is not allowed from this address yet.',
    _ => error.message ?? 'Something went wrong. Please try again.',
  };
}

/// Basic password policy shared by the form and tests.
String? passwordProblem(String password) {
  if (password.length < 8) return 'Use at least 8 characters';
  if (!RegExp(r'[A-Za-z]').hasMatch(password) || !RegExp(r'\d').hasMatch(password)) return 'Use both letters and numbers';
  return null;
}

/// 0 to 4. Shown as a meter while someone types a new password.
int passwordStrength(String password) {
  var score = 0;
  if (password.length >= 8) score++;
  if (password.length >= 12) score++;
  if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'\d').hasMatch(password) && RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
  return score;
}

/// Account, follows, preferences, and local conveniences, in one place.
///
/// Signed out, the app is fully browsable. Signing in adds follows, alerts,
/// the watched log, and sync across devices. Everything stored for a user lives
/// under users/{uid} and is removed when the account is deleted.
class AccountController extends ChangeNotifier {
  AccountController({FirebaseAuth? auth, FirebaseFirestore? firestore, NotificationService? notifications})
      : _authOverride = auth,
        _firestoreOverride = firestore,
        notifications = notifications ?? NotificationService();

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final NotificationService notifications;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  final _subscriptions = <StreamSubscription<dynamic>>[];
  StreamSubscription<User?>? _authSub;
  SharedPreferences? _prefs;

  User? user;
  bool ready = false;
  String? displayName;
  AlertPrefs alerts = const AlertPrefs();
  bool digest = false;
  String? calendarToken;
  String timeZone = 'UTC';
  City? homeCity;
  final Map<String, FollowInfo> follows = {};
  final Map<String, WatchedLaunch> watched = {};
  List<InboxMessage> inbox = const [];

  bool get signedIn => user != null;
  String? get email => user?.email;
  bool get emailVerified => user?.emailVerified ?? false;
  bool get usesPassword => user?.providerData.any((p) => p.providerId == 'password') ?? false;
  int get unread => inbox.where((m) => !m.read).length;
  bool following(String id) => follows.containsKey(id);
  bool hasWatched(String id) => watched.containsKey(id);

  DocumentReference<Map<String, dynamic>>? get _userRef => user == null ? null : _db.collection('users').doc(user!.uid);

  Future<void> start() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      homeCity = City.byId(_prefs?.getString('homeCity'));
    } catch (_) {}
    try {
      timeZone = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {}
    try {
      _authSub = _auth.authStateChanges().listen(_onUser, onError: (_) => _markReady());
    } catch (_) {
      _markReady();
    }
  }

  void _markReady() {
    ready = true;
    notifyListeners();
  }

  Future<void> _onUser(User? next) async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    follows.clear();
    watched.clear();
    inbox = const [];
    user = next;
    if (next == null) {
      displayName = null;
      alerts = const AlertPrefs();
      digest = false;
      calendarToken = null;
      _markReady();
      return;
    }
    displayName = next.displayName;
    await _ensureProfile(next);
    final ref = _userRef!;
    _subscriptions
      ..add(ref.snapshots().listen((doc) {
        final d = doc.data() ?? {};
        displayName = (d['displayName'] as String?) ?? next.displayName;
        alerts = AlertPrefs.fromMap(d['alerts']);
        digest = d['digest'] == true;
        calendarToken = d['calendarToken'] as String?;
        final city = City.byId(d['homeCity'] as String?);
        if (city != null) homeCity = city;
        notifyListeners();
      }, onError: (_) {}))
      ..add(ref.collection('follows').snapshots().listen((snap) {
        follows
          ..clear()
          ..addEntries(snap.docs.map((d) => MapEntry(d.id, FollowInfo(launchId: d.id, name: d.data()['name'] as String? ?? 'Launch', createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate()))));
        notifyListeners();
      }, onError: (_) {}))
      ..add(ref.collection('watched').snapshots().listen((snap) {
        watched
          ..clear()
          ..addEntries(snap.docs.map((d) {
            final m = d.data();
            return MapEntry(
              d.id,
              WatchedLaunch(
                launchId: d.id,
                name: m['name'] as String? ?? 'Launch',
                net: (m['net'] as Timestamp?)?.toDate(),
                vehicle: m['vehicle'] as String?,
                provider: m['provider'] as String?,
                imageUrl: m['imageUrl'] as String?,
                watchedAt: (m['watchedAt'] as Timestamp?)?.toDate(),
              ),
            );
          }));
        notifyListeners();
      }, onError: (_) {}))
      ..add(ref.collection('inbox').orderBy('createdAt', descending: true).limit(50).snapshots().listen((snap) {
        inbox = [
          for (final d in snap.docs)
            InboxMessage(
              id: d.id,
              title: d.data()['title'] as String? ?? '',
              body: d.data()['body'] as String? ?? '',
              launchId: (d.data()['launchId'] as String?)?.isEmpty ?? true ? null : d.data()['launchId'] as String,
              read: d.data()['read'] == true,
              createdAt: (d.data()['createdAt'] as Timestamp?)?.toDate(),
              kind: d.data()['kind'] as String?,
            ),
        ];
        notifyListeners();
      }, onError: (_) {}));
    if (follows.isNotEmpty || (await notifications.permissionGranted())) {
      unawaited(notifications.register(ref));
    }
    _markReady();
  }

  Future<void> _ensureProfile(User u) async {
    final ref = _db.collection('users').doc(u.uid);
    try {
      final snap = await ref.get();
      final data = <String, dynamic>{
        'email': u.email,
        'timezone': timeZone,
        'updatedAt': FieldValue.serverTimestamp(),
        if (homeCity != null) 'homeCity': homeCity!.id,
      };
      // Sign-up writes the display name at the same moment, so the document can
      // already exist without the defaults. Fill in whatever is missing.
      final existing = snap.data() ?? const <String, dynamic>{};
      if (!existing.containsKey('createdAt')) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      if (!existing.containsKey('alerts')) data['alerts'] = const AlertPrefs().toMap();
      if (!existing.containsKey('digest')) data['digest'] = false;
      if (!existing.containsKey('displayName') && u.displayName != null) data['displayName'] = u.displayName;
      await ref.set(data, SetOptions(merge: true));
    } catch (error) {
      debugPrint('Could not save profile: $error');
    }
  }

  // ---- Sign in and out ---------------------------------------------------

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> createAccount({required String name, required String email, required String password}) async {
    final problem = passwordProblem(password);
    if (problem != null) throw AccountException(problem);
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) {
      await cred.user?.updateDisplayName(trimmed);
      displayName = trimmed;
      await _db.collection('users').doc(cred.user!.uid).set({'displayName': trimmed}, SetOptions(merge: true));
    }
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {}
  }

  Future<void> signInWithGoogle() => _signInWithProvider(GoogleAuthProvider()..addScope('email'));

  Future<void> signInWithApple() => _signInWithProvider(AppleAuthProvider()..addScope('email')..addScope('name'));

  Future<void> _signInWithProvider(AuthProvider provider) async {
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  /// Always reports success, so the form does not reveal which emails have accounts.
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      if (e.code == 'invalid-email' || e.code == 'network-request-failed' || e.code == 'too-many-requests') rethrow;
    }
  }

  Future<void> resendVerification() async => user?.sendEmailVerification();

  /// Re-reads the user so a verified email shows up without signing out.
  Future<void> refreshUser() async {
    await user?.reload();
    user = _auth.currentUser;
    notifyListeners();
  }

  Future<void> signOut() async {
    await notifications.unregister(_userRef);
    await _auth.signOut();
  }

  // ---- Profile -------------------------------------------------------------

  Future<void> updateDisplayName(String name) async {
    final trimmed = name.trim();
    await user?.updateDisplayName(trimmed.isEmpty ? null : trimmed);
    await _userRef?.set({'displayName': trimmed.isEmpty ? FieldValue.delete() : trimmed}, SetOptions(merge: true));
    displayName = trimmed.isEmpty ? null : trimmed;
    notifyListeners();
  }

  Future<void> _reauthenticate(String? password) async {
    final u = user;
    if (u == null) throw const AccountException('You are signed out.');
    if (usesPassword) {
      if (password == null || password.isEmpty) throw const AccountException('Enter your current password.', code: 'password-required');
      await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: password));
      return;
    }
    final providerId = u.providerData.isEmpty ? null : u.providerData.first.providerId;
    final AuthProvider provider = providerId == 'apple.com' ? AppleAuthProvider() : GoogleAuthProvider();
    if (kIsWeb) {
      await u.reauthenticateWithPopup(provider);
    } else {
      await u.reauthenticateWithProvider(provider);
    }
  }

  Future<void> changePassword({required String current, required String next}) async {
    final problem = passwordProblem(next);
    if (problem != null) throw AccountException(problem);
    await _reauthenticate(current);
    await user!.updatePassword(next);
  }

  /// Sends a link to the new address. The email changes once it is clicked.
  Future<void> changeEmail({required String password, required String newEmail}) async {
    await _reauthenticate(password);
    await user!.verifyBeforeUpdateEmail(newEmail.trim());
  }

  /// Removes follows, devices, the watched log, the inbox, the profile, and the
  /// sign-in itself. A Cloud Function also sweeps anything left behind.
  Future<void> deleteAccount({String? password}) async {
    final ref = _userRef;
    if (ref == null) return;
    await _reauthenticate(password);
    await notifications.unregister(ref);
    for (final name in ['follows', 'devices', 'watched', 'inbox']) {
      final snap = await ref.collection(name).get();
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
    await ref.delete();
    await user!.delete();
  }

  // ---- Follows and alerts --------------------------------------------------

  /// Returns true when the launch is now followed.
  Future<bool> toggleFollow(LaunchRecord launch) async {
    final ref = _userRef;
    if (ref == null) throw const AccountException('Sign in to follow launches.');
    final doc = ref.collection('follows').doc(launch.id);
    if (follows.containsKey(launch.id)) {
      follows.remove(launch.id);
      notifyListeners();
      await doc.delete();
      return false;
    }
    follows[launch.id] = FollowInfo(launchId: launch.id, name: launch.name);
    notifyListeners();
    await doc.set({'launchId': launch.id, 'name': launch.name, 'createdAt': FieldValue.serverTimestamp(), ...alerts.toMap()});
    return true;
  }

  Future<void> unfollow(String launchId) async {
    follows.remove(launchId);
    notifyListeners();
    await _userRef?.collection('follows').doc(launchId).delete();
  }

  /// Changing a default also applies it to every launch already followed.
  Future<void> setAlerts(AlertPrefs next) async {
    alerts = next;
    notifyListeners();
    final ref = _userRef;
    if (ref == null) return;
    final batch = _db.batch()..set(ref, {'alerts': next.toMap()}, SetOptions(merge: true));
    for (final id in follows.keys) {
      batch.set(ref.collection('follows').doc(id), next.toMap(), SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> setDigest(bool value) async {
    digest = value;
    notifyListeners();
    await _userRef?.set({'digest': value}, SetOptions(merge: true));
    if (value) await enableNotifications();
  }

  Future<bool> enableNotifications() async {
    final ref = _userRef;
    if (ref == null) return false;
    return notifications.register(ref, requestPermission: true);
  }

  // ---- Calendar feed -------------------------------------------------------

  Future<String> ensureCalendarToken() async {
    if (calendarToken != null) return calendarToken!;
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';
    final random = Random.secure();
    final token = List.generate(32, (_) => chars[random.nextInt(chars.length)]).join();
    await _userRef?.set({'calendarToken': token}, SetOptions(merge: true));
    calendarToken = token;
    notifyListeners();
    return token;
  }

  // ---- Watched log ---------------------------------------------------------

  Future<void> toggleWatched(LaunchRecord launch) async {
    final ref = _userRef;
    if (ref == null) throw const AccountException('Sign in to keep a launch log.');
    final doc = ref.collection('watched').doc(launch.id);
    if (watched.containsKey(launch.id)) {
      watched.remove(launch.id);
      notifyListeners();
      await doc.delete();
      return;
    }
    watched[launch.id] = WatchedLaunch(launchId: launch.id, name: launch.name, net: launch.net, vehicle: launch.vehicle, provider: launch.provider, imageUrl: launch.imageUrl);
    notifyListeners();
    await doc.set({
      'launchId': launch.id,
      'name': launch.name,
      'net': launch.net == null ? null : Timestamp.fromDate(launch.net!),
      'vehicle': launch.vehicle,
      'provider': launch.provider,
      'imageUrl': launch.imageUrl,
      'watchedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---- Inbox ---------------------------------------------------------------

  Future<void> markRead(InboxMessage message) async {
    if (message.read) return;
    await _userRef?.collection('inbox').doc(message.id).update({'read': true});
  }

  Future<void> markAllRead() async {
    final ref = _userRef;
    if (ref == null) return;
    final batch = _db.batch();
    for (final m in inbox.where((m) => !m.read)) {
      batch.update(ref.collection('inbox').doc(m.id), {'read': true});
    }
    await batch.commit();
  }

  Future<void> clearInbox() async {
    final ref = _userRef;
    if (ref == null) return;
    final batch = _db.batch();
    for (final m in inbox) {
      batch.delete(ref.collection('inbox').doc(m.id));
    }
    await batch.commit();
  }

  // ---- Local conveniences --------------------------------------------------

  Future<void> setHomeCity(City? city) async {
    homeCity = city;
    notifyListeners();
    try {
      if (city == null) {
        await _prefs?.remove('homeCity');
      } else {
        await _prefs?.setString('homeCity', city.id);
      }
    } catch (_) {}
    await _userRef?.set({'homeCity': city?.id ?? FieldValue.delete()}, SetOptions(merge: true));
  }

  SharedPreferences? get prefs => _prefs;

  @override
  void dispose() {
    _authSub?.cancel();
    for (final s in _subscriptions) {
      s.cancel();
    }
    notifications.dispose();
    super.dispose();
  }
}
