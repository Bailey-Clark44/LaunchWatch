import 'package:cloud_firestore/cloud_firestore.dart';

import 'format_net.dart';

class Webcast {
  const Webcast({required this.url, this.title});
  final String url;
  final String? title;
}

class SourceLink {
  const SourceLink({required this.url, this.title});
  final String url;
  final String? title;
}

class LaunchUpdate {
  const LaunchUpdate({required this.id, this.comment, this.createdOn, this.infoUrl});
  final int id;
  final String? comment;
  final DateTime? createdOn;
  final String? infoUrl;
}

/// One recorded NET, precision, or status, from the poller's slip history.
class NetChange {
  const NetChange({required this.net, required this.precision, required this.statusId, required this.recordedAt});
  final DateTime? net;
  final String? precision;
  final int? statusId;
  final DateTime? recordedAt;
}

const _crewedMissionTypes = {'Human Exploration', 'Tourism'};
final _crewedName = RegExp(
  r'\b(Crew-\d+|Crew Flight|Shenzhou \d+|Soyuz MS-\d+|Axiom|Ax-\d+|Polaris|Inspiration4|Fram2|Starliner-1|Gaganyaan-H\d*|Artemis I{2,}|Mengzhou-\d+)\b',
  caseSensitive: false,
);

class LaunchRecord {
  const LaunchRecord({
    required this.id,
    required this.name,
    required this.status,
    this.statusId,
    required this.net,
    required this.precisionAbbrev,
    required this.providerId,
    required this.provider,
    required this.vehicleId,
    required this.vehicle,
    required this.orbit,
    this.missionName,
    this.missionType,
    required this.pad,
    required this.location,
    required this.country,
    this.padLatitude,
    this.padLongitude,
    required this.description,
    this.webcasts = const [],
    this.sources = const [],
    this.updates = const [],
    this.history = const [],
    required this.windowStart,
    required this.windowEnd,
    required this.suborbital,
    this.crewed = false,
    required this.imageUrl,
    required this.list,
  });

  final String id;
  final String name;
  final String status;
  final int? statusId;
  final DateTime? net;
  final String? precisionAbbrev;
  final int? providerId;
  final String? provider;
  final int? vehicleId;
  final String? vehicle;
  final String? orbit;
  final String? missionName;
  final String? missionType;
  final String? pad;
  final String? location;
  final String? country;
  final double? padLatitude;
  final double? padLongitude;
  final String? description;
  final List<Webcast> webcasts;
  final List<SourceLink> sources;
  final List<LaunchUpdate> updates;
  final List<NetChange> history;
  final DateTime? windowStart;
  final DateTime? windowEnd;
  final bool suborbital;
  final bool crewed;
  final String? imageUrl;
  final String list;

  String? get webcast => webcasts.isEmpty ? null : webcasts.first.url;
  String get when => net == null ? 'Time unknown' : formatNet(net!, precisionAbbrev);
  bool get isLive => statusId == 6;
  bool get isDated => !isCoarse(precisionAbbrev);

  /// Short name without the vehicle prefix: "Falcon 9 Block 5 | Crew-12" → "Crew-12".
  String get shortName {
    final bar = name.indexOf('|');
    return bar < 0 ? name : name.substring(bar + 1).trim();
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;
  static double? _double(Object? value) => value is num ? value.toDouble() : null;
  static DateTime? _time(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static LaunchRecord fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => fromMap(doc.id, doc.data() ?? {});

  static LaunchRecord fromMap(String id, Map<String, dynamic> data) {
    Map? map(Object? v) => v is Map ? v : null;
    final status = map(data['status']);
    final precision = map(data['netPrecision']);
    final provider = map(data['provider']);
    final vehicle = map(data['vehicle']);
    final mission = map(data['mission']);
    final pad = map(data['pad']);
    List<Map> maps(Object? v) => v is List ? v.whereType<Map>().toList() : const [];

    final name = data['name'] as String? ?? 'Unnamed launch';
    final missionType = mission?['type'] as String?;
    final vehicleName = vehicle?['name'] as String?;
    final crewedFlag = data['crewed'];
    final crewed = crewedFlag is bool
        ? crewedFlag
        : _crewedMissionTypes.contains(missionType) || _crewedName.hasMatch('$name ${vehicleName ?? ''}');

    return LaunchRecord(
      id: id,
      name: name,
      status: status?['name'] as String? ?? 'Unknown',
      statusId: _int(status?['id']),
      net: _time(data['net']),
      precisionAbbrev: precision?['abbrev'] as String?,
      providerId: _int(provider?['id']),
      provider: provider?['name'] as String?,
      vehicleId: _int(vehicle?['id']),
      vehicle: vehicleName,
      orbit: mission?['orbit'] as String?,
      missionName: mission?['name'] as String?,
      missionType: missionType,
      pad: pad?['name'] as String?,
      location: pad?['locationName'] as String?,
      country: pad?['countryCode'] as String?,
      padLatitude: _double(pad?['latitude']),
      padLongitude: _double(pad?['longitude']),
      description: mission?['description'] as String?,
      webcasts: [
        for (final w in maps(data['webcasts']))
          if (w['url'] is String) Webcast(url: w['url'] as String, title: w['title'] as String?),
      ],
      sources: [
        for (final s in maps(data['infoUrls']))
          if (s['url'] is String) SourceLink(url: s['url'] as String, title: s['title'] as String?),
      ],
      updates: [
        for (final u in maps(data['updates']))
          if (u['id'] is num)
            LaunchUpdate(
              id: (u['id'] as num).toInt(),
              comment: u['comment'] as String?,
              createdOn: _time(u['createdOn']),
              infoUrl: u['infoUrl'] as String?,
            ),
      ],
      history: [
        for (final h in maps(data['netHistory']))
          NetChange(
            net: _time(h['net']),
            precision: h['precision'] as String?,
            statusId: _int(h['statusId']),
            recordedAt: _time(h['recordedAt']),
          ),
      ],
      windowStart: _time(data['windowStart']),
      windowEnd: _time(data['windowEnd']),
      suborbital: data['suborbital'] == true,
      crewed: crewed,
      imageUrl: data['imageUrl'] as String?,
      list: data['list'] as String? ?? '',
    );
  }
}

class LaunchRepository {
  LaunchRepository(this._firestore);

  final FirebaseFirestore _firestore;
  Stream<List<LaunchRecord>>? _shared;
  List<LaunchRecord>? _latest;

  /// One shared Firestore listener for the whole catalog. Every tab reads
  /// from it, and a late subscriber gets the latest list straight away.
  Stream<List<LaunchRecord>> everything() async* {
    _shared ??= _firestore.collection('launches').snapshots().map((snap) {
      final launches = snap.docs.map(LaunchRecord.fromDoc).toList();
      launches.sort((a, b) => (a.net ?? DateTime.utc(0)).compareTo(b.net ?? DateTime.utc(0)));
      return _latest = launches;
    }).asBroadcastStream();
    if (_latest != null) yield _latest!;
    yield* _shared!;
  }

  List<LaunchRecord>? get latest => _latest;

  Stream<LaunchRecord?> one(String id) {
    return _firestore.collection('launches').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return LaunchRecord.fromDoc(doc);
    });
  }

  Stream<DateTime?> catalogUpdatedAt() {
    return _firestore.doc('meta/catalog').snapshots().map((doc) {
      final value = doc.data()?['updatedAt'];
      return value is Timestamp ? value.toDate() : null;
    });
  }

  Stream<HistoricalLaunchCount?> historicalCount(String type, String entityKey) {
    if (int.tryParse(entityKey) == null) return Stream.value(null);
    return _firestore.collection('catalogStats').doc('${type}_$entityKey').snapshots().map((doc) {
      final data = doc.data();
      final count = data?['pastLaunches'];
      final checkedAt = data?['checkedAt'];
      if (!doc.exists || count is! int) return null;
      return HistoricalLaunchCount(
        pastLaunches: count,
        checkedAt: checkedAt is Timestamp ? checkedAt.toDate() : null,
        successfulLaunches: data?['successfulLaunches'] is int ? data!['successfulLaunches'] as int : null,
        failedLaunches: data?['failedLaunches'] is int ? data!['failedLaunches'] as int : null,
        maidenFlight: data?['maidenFlight'] is String ? data!['maidenFlight'] as String : null,
        active: data?['active'] is bool ? data!['active'] as bool : null,
      );
    });
  }
}

class HistoricalLaunchCount {
  const HistoricalLaunchCount({
    required this.pastLaunches,
    required this.checkedAt,
    this.successfulLaunches,
    this.failedLaunches,
    this.maidenFlight,
    this.active,
  });

  final int pastLaunches;
  final DateTime? checkedAt;
  final int? successfulLaunches;
  final int? failedLaunches;
  final String? maidenFlight;
  final bool? active;

  /// Success rate over completed flights, or null when there are too few to say.
  double? get successRate {
    final ok = successfulLaunches;
    final bad = failedLaunches;
    if (ok == null || bad == null || ok + bad < 3) return null;
    return ok / (ok + bad);
  }
}
