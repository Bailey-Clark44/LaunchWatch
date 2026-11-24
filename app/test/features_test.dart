import 'package:flutter_test/flutter_test.dart';
import 'package:launchwatch/src/format_net.dart';
import 'package:launchwatch/src/glossary.dart';
import 'package:launchwatch/src/launch_repository.dart';
import 'package:launchwatch/src/since_last.dart';
import 'package:launchwatch/src/visibility.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('a year-only date never shows as Dec 31', () {
    final net = DateTime.utc(2026, 12, 31);
    expect(formatNet(net, 'Y'), '2026');
    expect(formatNetBadge(net, 'Y'), ('YEAR', '2026'));
    expect(formatNetBadge(DateTime.utc(2026, 12, 31), 'Q4'), ('Q4', '2026'));
    expect(isCoarse('Y'), isTrue);
    expect(isCoarse('DAY'), isFalse);
  });

  test('countdowns only for exact times inside 48 hours while Go, Hold, or in flight', () {
    final now = DateTime.utc(2026, 11, 12, 12);
    final soon = now.add(const Duration(hours: 5));
    expect(countdownAllowed(soon, 'MIN', 1, now: now), isTrue);
    expect(countdownAllowed(soon, 'HR', 1, now: now), isFalse);
    expect(countdownAllowed(soon, 'MIN', 2, now: now), isFalse);
    expect(countdownAllowed(now.add(const Duration(days: 3)), 'MIN', 1, now: now), isFalse);
    expect(formatCountdown(const Duration(hours: 2, minutes: 14, seconds: 9)), 'T−02:14:09');
  });

  test('crew is recognised from mission type when LL2 has no flag', () {
    final launch = LaunchRecord.fromMap('x', {
      'name': 'Long March 2F/G | Shenzhou 24',
      'crewed': null,
      'mission': {'type': 'Human Exploration'},
    });
    expect(launch.crewed, isTrue);
    expect(launch.shortName, 'Shenzhou 24');
  });

  test('visibility tiers follow distance', () {
    final orlando = City.byId('orlando')!;
    final london = City.byId('london')!;
    // Cape Canaveral SLC-40.
    final near = estimateVisibility(city: orlando, padLatitude: 28.562, padLongitude: -80.577, suborbital: false);
    expect(near.tier, VisibilityTier.clear);
    expect(near.direction, 'east');
    final far = estimateVisibility(city: london, padLatitude: 28.562, padLongitude: -80.577, suborbital: false);
    expect(far.tier, VisibilityTier.none);
  });

  test('glossary finds terms by alias', () {
    expect(lookupTerm('LEO')?.term, 'Low Earth Orbit');
    expect(lookupTerm('Low Earth Orbit'), isNotNull);
    expect(lookupTerm('banana'), isNull);
  });

  test('since-last-look reports slips and outcomes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    LaunchRecord l(String id, DateTime net, int status, {String list = 'upcoming'}) => LaunchRecord.fromMap(id, {
          'name': id,
          'net': net.toIso8601String(),
          'netPrecision': {'abbrev': 'MIN'},
          'status': {'id': status, 'name': 'x'},
          'list': list,
        });
    final t0 = DateTime.utc(2026, 11, 10);
    final first = await compareWithLastLook([l('a', DateTime.utc(2026, 11, 20), 1), l('b', DateTime.utc(2026, 11, 11), 1)], prefs: prefs, now: t0);
    expect(first, isNull);
    final later = await compareWithLastLook(
      [l('a', DateTime.utc(2026, 11, 22), 1), l('b', DateTime.utc(2026, 11, 11), 3, list: 'recent')],
      prefs: prefs,
      now: t0.add(const Duration(days: 2)),
    );
    expect(later!.slipped.map((x) => x.id), ['a']);
    expect(later.succeeded.map((x) => x.id), ['b']);
    expect(later.summary(), '1 slipped · 1 succeeded');
  });
}
