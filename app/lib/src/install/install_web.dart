import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'install_mode.dart';

export 'install_mode.dart';

/// Reads `window.lwInstall`, which web/index.html sets up before Flutter starts.
class InstallSupport {
  static JSObject? get _bridge => globalContext['lwInstall'] as JSObject?;

  static InstallMode get mode {
    final bridge = _bridge;
    if (bridge == null) return InstallMode.none;
    final standalone = bridge.callMethod<JSBoolean?>('standalone'.toJS)?.toDart ?? false;
    if (standalone) return InstallMode.installed;
    if (bridge['prompt'] != null) return InstallMode.prompt;
    if (_isAppleMobileSafari) return InstallMode.iosShare;
    return InstallMode.none;
  }

  static bool get _isAppleMobileSafari {
    final agent = web.window.navigator.userAgent;
    final appleTouch = RegExp(r'iPhone|iPad|iPod').hasMatch(agent) ||
        (agent.contains('Macintosh') && web.window.navigator.maxTouchPoints > 1);
    // Other iOS browsers can install too since iOS 16.4, but through their own
    // menus; Safari's Share sheet is the one route that always works.
    final otherBrowser = RegExp(r'CriOS|FxiOS|EdgiOS|OPiOS').hasMatch(agent);
    return appleTouch && !otherBrowser;
  }

  static final Stream<void> changes = _changes();

  static Stream<void> _changes() {
    final controller = StreamController<void>.broadcast();
    final listener = ((web.Event _) => controller.add(null)).toJS;
    web.window.addEventListener('lw-install-change', listener);
    web.window.matchMedia('(display-mode: standalone)').addEventListener('change', listener);
    return controller.stream;
  }

  /// Returns 'accepted', 'dismissed' or 'unavailable'.
  static Future<String> ask() async {
    final bridge = _bridge;
    if (bridge == null) return 'unavailable';
    final result = bridge.callMethod<JSPromise<JSString>>('ask'.toJS);
    return (await result.toDart).toDart;
  }
}
