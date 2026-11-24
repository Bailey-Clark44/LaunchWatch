import 'package:flutter_test/flutter_test.dart';
import 'package:launchwatch/src/people_page.dart';
import 'package:launchwatch/src/space_data.dart';

void main() {
  test('ISO durations parse and read naturally', () {
    expect(parseIsoDuration('P314DT9H1M30S'), const Duration(days: 314, hours: 9, minutes: 1, seconds: 30));
    expect(parseIsoDuration('PT7H11M'), const Duration(hours: 7, minutes: 11));
    expect(parseIsoDuration('P0D'), Duration.zero);
    expect(parseIsoDuration('nonsense'), isNull);
    expect(formatSpan(const Duration(hours: 7, minutes: 11)), '7 h 11 min');
    expect(formatSpan(const Duration(days: 314, hours: 9)), '314 days 9 h');
    expect(formatSpan(const Duration(days: 900)), '2.5 years');
  });

  test('flags come from two-letter country codes', () {
    expect(const Astronaut(id: '1', name: 'A', countryCode: 'US').flag, '🇺🇸');
    expect(const Astronaut(id: '1', name: 'A', countryCode: null).flag, isNull);
  });

  test('people are grouped by the station their expedition is on', () {
    const people = [Astronaut(id: '1', name: 'Ann'), Astronaut(id: '2', name: 'Bo'), Astronaut(id: '3', name: 'Cy')];
    const expeditions = [
      Expedition(id: 'e', name: 'Expedition 75', stationId: '4', stationName: 'ISS', active: true, crew: [CrewMember(id: '1', name: 'Ann', role: 'Commander'), CrewMember(id: '2', name: 'Bo')]),
    ];
    final groups = groupByLocation(people, expeditions);
    expect(groups.first.place, 'ISS');
    expect(groups.first.people.map((p) => p.name), ['Ann', 'Bo']);
    expect(groups.first.roles['1'], 'Commander');
    expect(groups.last.place, 'Other spacecraft');
    expect(groups.last.people.single.name, 'Cy');
  });

  test('continuous presence counts from 2 November 2000', () {
    expect(continuousPresence(now: DateTime.utc(2026, 11, 12)).inDays, 9505);
  });
}
