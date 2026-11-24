import 'package:flutter_test/flutter_test.dart';
import 'package:launchwatch/src/catalog.dart';
import 'package:launchwatch/src/launch_repository.dart';

void main() {
  test('vehicles and organisations group the same catalog', () {
    final launches = [
      _launch(vehicle: 'Falcon 9', vehicleId: 1, provider: 'SpaceX', providerId: 121, list: 'upcoming'),
      _launch(vehicle: 'Falcon 9', vehicleId: 1, provider: 'SpaceX', providerId: 121, list: 'recent'),
      _launch(vehicle: 'Electron', vehicleId: 2, provider: 'Rocket Lab', providerId: 147, list: 'upcoming'),
    ];

    final vehicles = groupVehicles(launches);
    expect(vehicles.map((group) => group.name), ['Electron', 'Falcon 9']);
    expect(vehicles.last.upcoming, 1);

    final organisations = groupOrganisations(launches);
    expect(organisations.map((group) => group.name), ['Rocket Lab', 'SpaceX']);
    expect(organisations.last.recent, 1);
  });
}

LaunchRecord _launch({
  required String vehicle,
  required int vehicleId,
  required String provider,
  required int providerId,
  required String list,
}) {
  return LaunchRecord(
    id: '$vehicle-$list',
    name: '$vehicle flight',
    status: 'Go for Launch',
    net: DateTime.utc(2026, 11, 13),
    precisionAbbrev: 'DAY',
    providerId: providerId,
    provider: provider,
    vehicleId: vehicleId,
    vehicle: vehicle,
    orbit: null,
    pad: null,
    location: null,
    country: null,
    description: null,
    windowStart: null,
    windowEnd: null,
    suborbital: false,
    imageUrl: null,
    list: list,
  );
}
