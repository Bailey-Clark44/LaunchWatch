import 'launch_repository.dart';

class VehicleGroup {
  const VehicleGroup({required this.key, required this.name, required this.imageUrl, required this.launches});

  final String key;
  final String name;
  final String? imageUrl;
  final List<LaunchRecord> launches;

  int get upcoming => launches.where((launch) => launch.list == 'upcoming').length;
  int get recent => launches.where((launch) => launch.list == 'recent').length;
  int get inCatalog => launches.where((launch) => launch.list == 'upcoming' || launch.list == 'recent').length;
  List<OrganisationGroup> get operators => groupOrganisations(launches);
  LaunchRecord? get latestFlight {
    final flights = launches.where((launch) => launch.list == 'recent' && launch.net != null).toList()
      ..sort((a, b) => b.net!.compareTo(a.net!));
    return flights.isEmpty ? null : flights.first;
  }
}

class OrganisationGroup {
  const OrganisationGroup({required this.key, required this.name, required this.launches});

  final String key;
  final String name;
  final List<LaunchRecord> launches;

  int get upcoming => launches.where((launch) => launch.list == 'upcoming').length;
  int get recent => launches.where((launch) => launch.list == 'recent').length;
  int get inCatalog => launches.where((launch) => launch.list == 'upcoming' || launch.list == 'recent').length;
  List<VehicleGroup> get vehicles => groupVehicles(launches);
  LaunchRecord? get latestFlight {
    final flights = launches.where((launch) => launch.list == 'recent' && launch.net != null).toList()
      ..sort((a, b) => b.net!.compareTo(a.net!));
    return flights.isEmpty ? null : flights.first;
  }
}

List<VehicleGroup> groupVehicles(List<LaunchRecord> launches) {
  final groups = <String, List<LaunchRecord>>{};
  final names = <String, String>{};
  final images = <String, String?>{};
  for (final launch in launches) {
    if (launch.list != 'upcoming' && launch.list != 'recent') continue;
    final name = launch.vehicle;
    if (name == null || name.isEmpty) continue;
    final key = launch.vehicleId?.toString() ?? name;
    groups.putIfAbsent(key, () => []).add(launch);
    names[key] = name;
    images[key] ??= launch.imageUrl;
  }
  final result = [
    for (final entry in groups.entries)
      VehicleGroup(key: entry.key, name: names[entry.key]!, imageUrl: images[entry.key], launches: entry.value),
  ];
  result.sort((a, b) => b.upcoming.compareTo(a.upcoming) == 0 ? a.name.compareTo(b.name) : b.upcoming.compareTo(a.upcoming));
  return result;
}

List<OrganisationGroup> groupOrganisations(List<LaunchRecord> launches) {
  final groups = <String, List<LaunchRecord>>{};
  final names = <String, String>{};
  for (final launch in launches) {
    if (launch.list != 'upcoming' && launch.list != 'recent') continue;
    final name = launch.provider;
    if (name == null || name.isEmpty) continue;
    final key = launch.providerId?.toString() ?? name;
    groups.putIfAbsent(key, () => []).add(launch);
    names[key] = name;
  }
  final result = [
    for (final entry in groups.entries) OrganisationGroup(key: entry.key, name: names[entry.key]!, launches: entry.value),
  ];
  result.sort((a, b) => b.upcoming.compareTo(a.upcoming) == 0 ? a.name.compareTo(b.name) : b.upcoming.compareTo(a.upcoming));
  return result;
}
