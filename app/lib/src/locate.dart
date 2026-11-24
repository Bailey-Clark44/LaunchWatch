import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'visibility.dart';

/// Why the location could not be read, as a sentence for the person.
class LocationProblem implements Exception {
  const LocationProblem(this.message, {this.canOpenSettings = false});

  final String message;

  /// True when only the system settings can fix it (permission denied for good).
  final bool canOpenSettings;

  @override
  String toString() => message;
}

/// Reads the device's approximate location once and returns it as a [City].
///
/// Asks for permission the first time. Low accuracy is all a visibility
/// estimate needs, so phones can answer from Wi-Fi or cell towers without
/// waiting for a GPS fix, and Android only ever grants approximate location.
Future<City> locateMe() async {
  if (!kIsWeb && !await Geolocator.isLocationServiceEnabled()) {
    throw const LocationProblem('Location is turned off on this device. Turn it on in Settings, or pick a city instead.', canOpenSettings: true);
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied) {
    throw const LocationProblem('LaunchWatch was not allowed to see your location. Pick a city instead, or try again and choose Allow.');
  }
  if (permission == LocationPermission.deniedForever) {
    throw LocationProblem(
      kIsWeb
          ? 'Location is blocked for this site. Allow it from the icon beside the address bar, or pick a city instead.'
          : 'Location is turned off for LaunchWatch. Allow it in Settings, or pick a city instead.',
      canOpenSettings: !kIsWeb,
    );
  }

  try {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)),
    );
    return City.here(position.latitude, position.longitude);
  } on TimeoutException {
    final last = kIsWeb ? null : await Geolocator.getLastKnownPosition();
    if (last != null) return City.here(last.latitude, last.longitude);
    throw const LocationProblem('Finding your location took too long. Try again outdoors or near a window, or pick a city instead.');
  } on LocationServiceDisabledException {
    throw const LocationProblem('Location is turned off on this device. Turn it on in Settings, or pick a city instead.', canOpenSettings: true);
  } on PermissionDeniedException {
    throw const LocationProblem('LaunchWatch was not allowed to see your location. Pick a city instead.');
  } catch (_) {
    throw const LocationProblem('Your location could not be read just now. Pick a city instead, or try again.');
  }
}

/// Opens the app's page in system settings, where location can be allowed.
Future<void> openLocationSettings() async {
  if (kIsWeb) return;
  if (!await Geolocator.isLocationServiceEnabled()) {
    await Geolocator.openLocationSettings();
  } else {
    await Geolocator.openAppSettings();
  }
}
