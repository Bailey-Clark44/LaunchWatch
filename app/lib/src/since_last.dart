import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'launch_repository.dart';

/// What changed in the catalog since this device last looked.
class SinceLastLook {
  const SinceLastLook({required this.slipped, required this.movedUp, required this.succeeded, required this.failed, required this.since, required this.newlyListed});

  final List<LaunchRecord> slipped;
  final List<LaunchRecord> movedUp;
  final List<LaunchRecord> succeeded;
  final List<LaunchRecord> failed;
  final int newlyListed;
  final DateTime since;

  bool get isEmpty => slipped.isEmpty && movedUp.isEmpty && succeeded.isEmpty && failed.isEmpty;

  String summary() {
    final parts = <String>[
      if (slipped.isNotEmpty) '${slipped.length} slipped',
      if (movedUp.isNotEmpty) '${movedUp.length} moved earlier',
      if (succeeded.isNotEmpty) '${succeeded.length} succeeded',
      if (failed.isNotEmpty) '${failed.length} failed',
    ];
    return parts.join(' · ');
  }
}

const _key = 'lastLook.v1';
const _minGap = Duration(hours: 2);

/// Compares the current catalog with the snapshot saved on the previous visit,
/// then saves the new snapshot. Visits closer together than two hours keep the
/// older baseline so a quick reopen still shows the same news.
Future<SinceLastLook?> compareWithLastLook(List<LaunchRecord> launches, {SharedPreferences? prefs, DateTime? now}) async {
  final store = prefs ?? await SharedPreferences.getInstance();
  final at = now ?? DateTime.now();
  Map<String, dynamic>? previous;
  try {
    final raw = store.getString(_key);
    if (raw != null) previous = jsonDecode(raw) as Map<String, dynamic>;
  } catch (_) {}

  final snapshot = {
    'at': at.toIso8601String(),
    'launches': {
      for (final l in launches) l.id: [l.net?.millisecondsSinceEpoch, l.statusId],
    },
  };

  SinceLastLook? result;
  if (previous != null) {
    final since = DateTime.tryParse(previous['at'] as String? ?? '') ?? at;
    final old = (previous['launches'] as Map?)?.cast<String, dynamic>() ?? {};
    final slipped = <LaunchRecord>[];
    final movedUp = <LaunchRecord>[];
    final succeeded = <LaunchRecord>[];
    final failed = <LaunchRecord>[];
    var newlyListed = 0;
    for (final l in launches) {
      final before = old[l.id];
      if (before is! List || before.length < 2) {
        if (l.list == 'upcoming') newlyListed++;
        continue;
      }
      final oldNet = before[0] as int?;
      final oldStatus = before[1] as int?;
      if (l.statusId != oldStatus && (l.statusId == 3 || l.statusId == 9)) {
        succeeded.add(l);
      } else if (l.statusId != oldStatus && (l.statusId == 4 || l.statusId == 7)) {
        failed.add(l);
      } else if (oldNet != null && l.net != null && l.list == 'upcoming') {
        final moved = l.net!.millisecondsSinceEpoch - oldNet;
        // Ignore noise inside an hour and the yearly placeholders shuffling.
        if (l.isDated && moved.abs() >= const Duration(hours: 1).inMilliseconds) {
          (moved > 0 ? slipped : movedUp).add(l);
        }
      }
    }
    result = SinceLastLook(slipped: slipped, movedUp: movedUp, succeeded: succeeded, failed: failed, since: since, newlyListed: newlyListed);
    if (at.difference(since) < _minGap) return result;
  }
  try {
    await store.setString(_key, jsonEncode(snapshot));
  } catch (_) {}
  return result;
}
