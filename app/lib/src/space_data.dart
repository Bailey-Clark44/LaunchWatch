import 'package:cloud_firestore/cloud_firestore.dart';

import 'format_net.dart';
import 'launch_repository.dart' show Webcast, SourceLink, LaunchUpdate;

DateTime? _time(Object? v) => v is Timestamp ? v.toDate() : (v is String ? DateTime.tryParse(v) : null);
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
int? _int(Object? v) => v is num ? v.toInt() : null;
double? _double(Object? v) => v is num ? v.toDouble() : null;
List<Map<String, dynamic>> _maps(Object? v) => v is List ? v.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() : const [];
List<String> _strings(Object? v) => v is List ? v.whereType<String>().toList() : const [];

/// Parses ISO 8601 durations such as `P314DT9H1M30S` or `PT7H11M`.
Duration? parseIsoDuration(String? text) {
  if (text == null) return null;
  final m = RegExp(r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$').firstMatch(text);
  if (m == null) return null;
  int g(int i) => int.tryParse(m.group(i) ?? '') ?? 0;
  final seconds = double.tryParse(m.group(6) ?? '') ?? 0;
  return Duration(days: g(1) * 365 + g(2) * 30 + g(3), hours: g(4), minutes: g(5), seconds: seconds.round());
}

/// "314 days 9 h", "7 h 11 min", "45 min".
String formatSpan(Duration d) {
  if (d.inDays >= 365) {
    final years = d.inDays / 365.25;
    return '${years.toStringAsFixed(years >= 10 ? 0 : 1)} years';
  }
  if (d.inDays >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'}${d.inHours % 24 > 0 ? ' ${d.inHours % 24} h' : ''}';
  if (d.inHours >= 1) return '${d.inHours} h${d.inMinutes % 60 > 0 ? ' ${d.inMinutes % 60} min' : ''}';
  return '${d.inMinutes} min';
}

class SpaceEvent {
  const SpaceEvent({
    required this.id,
    required this.name,
    required this.list,
    this.type,
    this.description,
    this.date,
    this.precision,
    this.location,
    this.webcastLive = false,
    this.imageUrl,
    this.thumbUrl,
    this.webcasts = const [],
    this.sources = const [],
    this.updates = const [],
    this.agencies = const [],
    this.launchIds = const [],
    this.stationIds = const [],
    this.expeditionIds = const [],
    this.astronautIds = const [],
  });

  final String id;
  final String name;
  final String list;
  final String? type;
  final String? description;
  final DateTime? date;
  final String? precision;
  final String? location;
  final bool webcastLive;
  final String? imageUrl;
  final String? thumbUrl;
  final List<Webcast> webcasts;
  final List<SourceLink> sources;
  final List<LaunchUpdate> updates;
  final List<String> agencies;
  final List<String> launchIds;
  final List<String> stationIds;
  final List<String> expeditionIds;
  final List<String> astronautIds;

  String get when => date == null ? 'Date to be announced' : formatNet(date!, precision);
  bool get isDated => !isCoarse(precision);

  static SpaceEvent fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SpaceEvent(
      id: doc.id,
      name: _str(d['name']) ?? 'Event',
      list: _str(d['list']) ?? 'upcoming',
      type: _str(d['type']),
      description: _str(d['description']),
      date: _time(d['date']),
      precision: _str((d['precision'] as Map?)?['abbrev']),
      location: _str(d['location']),
      webcastLive: d['webcastLive'] == true,
      imageUrl: _str(d['imageUrl']),
      thumbUrl: _str(d['thumbUrl']),
      webcasts: [for (final w in _maps(d['webcasts'])) if (_str(w['url']) != null) Webcast(url: w['url'] as String, title: _str(w['title']))],
      sources: [for (final s in _maps(d['infoUrls'])) if (_str(s['url']) != null) SourceLink(url: s['url'] as String, title: _str(s['title']))],
      updates: [
        for (final u in _maps(d['updates']))
          if (_int(u['id']) != null) LaunchUpdate(id: _int(u['id'])!, comment: _str(u['comment']), createdOn: _time(u['createdOn']), infoUrl: _str(u['infoUrl'])),
      ],
      agencies: _strings(d['agencies']),
      launchIds: _strings(d['launchIds']),
      stationIds: _strings(d['stationIds']),
      expeditionIds: _strings(d['expeditionIds']),
      astronautIds: _strings(d['astronautIds']),
    );
  }
}

class CrewMember {
  const CrewMember({required this.id, required this.name, this.role, this.thumbUrl, this.agency, this.nationality});
  final String id;
  final String name;
  final String? role;
  final String? thumbUrl;
  final String? agency;
  final String? nationality;

  static List<CrewMember> list(Object? raw) => [
        for (final c in _maps(raw))
          if (_str(c['id']) != null && _str(c['name']) != null)
            CrewMember(id: c['id'] as String, name: c['name'] as String, role: _str(c['role']), thumbUrl: _str(c['thumbUrl']), agency: _str(c['agency']), nationality: _str(c['nationality'])),
      ];
}

class DockingPort {
  const DockingPort({required this.port, this.spacecraft, this.since, this.launchId, this.thumbUrl});
  final String port;
  final String? spacecraft;
  final DateTime? since;
  final String? launchId;
  final String? thumbUrl;
}

class Station {
  const Station({
    required this.id,
    required this.name,
    this.status,
    this.active = false,
    this.type,
    this.founded,
    this.deorbited,
    this.description,
    this.orbit,
    this.owners = const [],
    this.imageUrl,
    this.thumbUrl,
    this.height,
    this.width,
    this.mass,
    this.volume,
    this.onboardCrew,
    this.dockedVehicles,
    this.activeExpeditionIds = const [],
    this.ports = const [],
  });

  final String id;
  final String name;
  final String? status;
  final bool active;
  final String? type;
  final String? founded;
  final String? deorbited;
  final String? description;
  final String? orbit;
  final List<String> owners;
  final String? imageUrl;
  final String? thumbUrl;
  final double? height;
  final double? width;
  final double? mass;
  final double? volume;
  final int? onboardCrew;
  final int? dockedVehicles;
  final List<String> activeExpeditionIds;
  final List<DockingPort> ports;

  List<DockingPort> get occupied => ports.where((p) => p.spacecraft != null).toList();

  DateTime? get foundedDate => founded == null ? null : DateTime.tryParse(founded!);

  static Station fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Station(
      id: doc.id,
      name: _str(d['name']) ?? 'Station',
      status: _str(d['status']),
      active: d['active'] == true,
      type: _str(d['type']),
      founded: _str(d['founded']),
      deorbited: _str(d['deorbited']),
      description: _str(d['description']),
      orbit: _str(d['orbit']),
      owners: [for (final o in _maps(d['owners'])) ?(_str(o['abbrev']) ?? _str(o['name']))],
      imageUrl: _str(d['imageUrl']),
      thumbUrl: _str(d['thumbUrl']),
      height: _double(d['height']),
      width: _double(d['width']),
      mass: _double(d['mass']),
      volume: _double(d['volume']),
      onboardCrew: _int(d['onboardCrew']),
      dockedVehicles: _int(d['dockedVehicles']),
      activeExpeditionIds: _strings(d['activeExpeditionIds']),
      ports: [
        for (final p in _maps(d['ports']))
          if (_str(p['port']) != null) DockingPort(port: p['port'] as String, spacecraft: _str(p['spacecraft']), since: _time(p['since']), launchId: _str(p['launchId']), thumbUrl: _str(p['thumbUrl'])),
      ],
    );
  }
}

class Expedition {
  const Expedition({required this.id, required this.name, this.start, this.end, this.active = false, this.stationId, this.stationName, this.crew = const [], this.patches = const [], this.spacewalkCount = 0});
  final String id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final bool active;
  final String? stationId;
  final String? stationName;
  final List<CrewMember> crew;
  final List<String> patches;
  final int spacewalkCount;

  static Expedition fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Expedition(
      id: doc.id,
      name: _str(d['name']) ?? 'Expedition',
      start: _time(d['start']),
      end: _time(d['end']),
      active: d['active'] == true,
      stationId: _str(d['stationId']),
      stationName: _str(d['stationName']),
      crew: CrewMember.list(d['crew']),
      patches: _strings(d['patches']),
      spacewalkCount: _int(d['spacewalkCount']) ?? 0,
    );
  }
}

class Astronaut {
  const Astronaut({
    required this.id,
    required this.name,
    this.status,
    this.type,
    this.agencyName,
    this.agencyAbbrev,
    this.nationality,
    this.countryCode,
    this.imageUrl,
    this.thumbUrl,
    this.inSpace = false,
    this.timeInSpace,
    this.evaTime,
    this.age,
    this.dateOfBirth,
    this.dateOfDeath,
    this.bio,
    this.wiki,
    this.firstFlight,
    this.lastFlight,
    this.flightsCount,
    this.landingsCount,
    this.spacewalksCount,
  });

  final String id;
  final String name;
  final String? status;
  final String? type;
  final String? agencyName;
  final String? agencyAbbrev;
  final String? nationality;
  final String? countryCode;
  final String? imageUrl;
  final String? thumbUrl;
  final bool inSpace;
  final Duration? timeInSpace;
  final Duration? evaTime;
  final int? age;
  final String? dateOfBirth;
  final String? dateOfDeath;
  final String? bio;
  final String? wiki;
  final DateTime? firstFlight;
  final DateTime? lastFlight;
  final int? flightsCount;
  final int? landingsCount;
  final int? spacewalksCount;

  /// Unicode flag from an ISO alpha-2 code, e.g. "US" → 🇺🇸.
  String? get flag {
    final c = countryCode;
    if (c == null || c.length != 2) return null;
    return String.fromCharCodes(c.toUpperCase().codeUnits.map((u) => 0x1F1E6 + u - 65));
  }

  static Astronaut fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final agency = d['agency'] as Map?;
    final nat = d['nationality'] as Map?;
    return Astronaut(
      id: doc.id,
      name: _str(d['name']) ?? 'Astronaut',
      status: _str(d['status']),
      type: _str(d['type']),
      agencyName: _str(agency?['name']),
      agencyAbbrev: _str(agency?['abbrev']),
      nationality: _str(nat?['name']),
      countryCode: _str(nat?['code']),
      imageUrl: _str(d['imageUrl']),
      thumbUrl: _str(d['thumbUrl']),
      inSpace: d['inSpace'] == true,
      timeInSpace: parseIsoDuration(_str(d['timeInSpace'])),
      evaTime: parseIsoDuration(_str(d['evaTime'])),
      age: _int(d['age']),
      dateOfBirth: _str(d['dateOfBirth']),
      dateOfDeath: _str(d['dateOfDeath']),
      bio: _str(d['bio']),
      wiki: _str(d['wiki']),
      firstFlight: _time(d['firstFlight']),
      lastFlight: _time(d['lastFlight']),
      flightsCount: _int(d['flightsCount']),
      landingsCount: _int(d['landingsCount']),
      spacewalksCount: _int(d['spacewalksCount']),
    );
  }
}

class Spacewalk {
  const Spacewalk({required this.id, required this.name, this.start, this.end, this.duration, this.location, this.crew = const [], this.stationId, this.stationName, this.expeditionName, this.eventId, this.webcasts = const [], this.imageUrl});
  final String id;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final Duration? duration;
  final String? location;
  final List<CrewMember> crew;
  final String? stationId;
  final String? stationName;
  final String? expeditionName;
  final String? eventId;
  final List<Webcast> webcasts;
  final String? imageUrl;

  static Spacewalk fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Spacewalk(
      id: doc.id,
      name: _str(d['name']) ?? 'Spacewalk',
      start: _time(d['start']),
      end: _time(d['end']),
      duration: parseIsoDuration(_str(d['duration'])),
      location: _str(d['location']),
      crew: CrewMember.list(d['crew']),
      stationId: _str(d['stationId']),
      stationName: _str(d['stationName']),
      expeditionName: _str(d['expeditionName']),
      eventId: _str(d['eventId']),
      webcasts: [for (final w in _maps(d['webcasts'])) if (_str(w['url']) != null) Webcast(url: w['url'] as String, title: _str(w['title']))],
      imageUrl: _str(d['thumbUrl']) ?? _str(d['imageUrl']),
    );
  }
}

class Program {
  const Program({required this.id, required this.name, this.description, this.type, this.start, this.end, this.infoUrl, this.wikiUrl, this.agencies = const [], this.patches = const [], this.imageUrl});
  final String id;
  final String name;
  final String? description;
  final String? type;
  final DateTime? start;
  final DateTime? end;
  final String? infoUrl;
  final String? wikiUrl;
  final List<String> agencies;
  final List<String> patches;
  final String? imageUrl;

  bool get ongoing => end == null || end!.isAfter(DateTime.now());

  static Program fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Program(
      id: doc.id,
      name: _str(d['name']) ?? 'Program',
      description: _str(d['description']),
      type: _str(d['type']),
      start: _time(d['start']),
      end: _time(d['end']),
      infoUrl: _str(d['infoUrl']),
      wikiUrl: _str(d['wikiUrl']),
      agencies: _strings(d['agencies']),
      patches: _strings(d['patches']),
      imageUrl: _str(d['imageUrl']),
    );
  }
}

class Docking {
  const Docking({required this.id, this.docking, this.departure, this.port, this.stationId, this.stationName, required this.spacecraft, this.launchId, this.thumbUrl});
  final String id;
  final DateTime? docking;
  final DateTime? departure;
  final String? port;
  final String? stationId;
  final String? stationName;
  final String spacecraft;
  final String? launchId;
  final String? thumbUrl;

  bool get upcoming => docking != null && docking!.isAfter(DateTime.now());

  static Docking fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Docking(
      id: doc.id,
      docking: _time(d['docking']),
      departure: _time(d['departure']),
      port: _str(d['port']),
      stationId: _str(d['stationId']),
      stationName: _str(d['stationName']),
      spacecraft: _str(d['spacecraft']) ?? 'Spacecraft',
      launchId: _str(d['launchId']),
      thumbUrl: _str(d['thumbUrl']),
    );
  }
}

class Article {
  const Article({required this.id, required this.title, required this.url, this.imageUrl, this.site, this.summary, this.publishedAt, this.featured = false, this.launchIds = const [], this.eventIds = const []});
  final String id;
  final String title;
  final String url;
  final String? imageUrl;
  final String? site;
  final String? summary;
  final DateTime? publishedAt;
  final bool featured;
  final List<String> launchIds;
  final List<String> eventIds;

  static Article fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Article(
      id: doc.id,
      title: _str(d['title']) ?? '',
      url: _str(d['url']) ?? '',
      imageUrl: _str(d['imageUrl']),
      site: _str(d['site']),
      summary: _str(d['summary']),
      publishedAt: _time(d['publishedAt']),
      featured: d['featured'] == true,
      launchIds: _strings(d['launchIds']),
      eventIds: _strings(d['eventIds']),
    );
  }
}

/// A Firestore collection as a shared, replaying stream: one listener however
/// many screens read it, and late subscribers get the latest list at once.
class _Shared<T> {
  _Shared(this._query, this._map, [this._sort]);

  final Query<Map<String, dynamic>> _query;
  final T Function(DocumentSnapshot<Map<String, dynamic>>) _map;
  final int Function(T, T)? _sort;
  Stream<List<T>>? _stream;
  List<T>? latest;

  Stream<List<T>> watch() async* {
    _stream ??= _query.snapshots().map((s) {
      final items = s.docs.map(_map).toList();
      if (_sort != null) items.sort(_sort);
      return latest = items;
    }).asBroadcastStream();
    if (latest != null) yield latest!;
    yield* _stream!;
  }
}

int _byDate(DateTime? a, DateTime? b, {bool descending = false}) {
  final x = a ?? DateTime.utc(9999);
  final y = b ?? DateTime.utc(9999);
  return descending ? y.compareTo(x) : x.compareTo(y);
}

/// Everything beyond launches: events, stations, crews, people, news.
class SpaceRepository {
  SpaceRepository(FirebaseFirestore db)
      : _events = _Shared(db.collection('events'), SpaceEvent.fromDoc, (a, b) => _byDate(a.date, b.date)),
        _stations = _Shared(db.collection('stations'), Station.fromDoc, (a, b) => (b.active ? 1 : 0) - (a.active ? 1 : 0) != 0 ? (b.active ? 1 : 0) - (a.active ? 1 : 0) : _byDate(b.foundedDate, a.foundedDate)),
        _expeditions = _Shared(db.collection('expeditions'), Expedition.fromDoc, (a, b) => _byDate(a.start, b.start, descending: true)),
        _inSpace = _Shared(db.collection('astronauts').where('inSpace', isEqualTo: true), Astronaut.fromDoc, (a, b) => a.name.compareTo(b.name)),
        _spacewalks = _Shared(db.collection('spacewalks'), Spacewalk.fromDoc, (a, b) => _byDate(a.start, b.start, descending: true)),
        _programs = _Shared(db.collection('programs'), Program.fromDoc, (a, b) => _byDate(a.start, b.start, descending: true)),
        _dockings = _Shared(db.collection('dockings'), Docking.fromDoc, (a, b) => _byDate(a.docking, b.docking, descending: true)),
        _news = _Shared(db.collection('news').orderBy('publishedAt', descending: true).limit(120), Article.fromDoc),
        _db = db;

  final FirebaseFirestore _db;
  final _Shared<SpaceEvent> _events;
  final _Shared<Station> _stations;
  final _Shared<Expedition> _expeditions;
  final _Shared<Astronaut> _inSpace;
  final _Shared<Spacewalk> _spacewalks;
  final _Shared<Program> _programs;
  final _Shared<Docking> _dockings;
  final _Shared<Article> _news;

  Stream<List<SpaceEvent>> events() => _events.watch();
  Stream<List<Station>> stations() => _stations.watch();
  Stream<List<Expedition>> expeditions() => _expeditions.watch();
  Stream<List<Astronaut>> peopleInSpace() => _inSpace.watch();
  Stream<List<Spacewalk>> spacewalks() => _spacewalks.watch();
  Stream<List<Program>> programs() => _programs.watch();
  Stream<List<Docking>> dockings() => _dockings.watch();
  Stream<List<Article>> news() => _news.watch();

  Stream<SpaceEvent?> event(String id) => _db.collection('events').doc(id).snapshots().map((d) => d.exists ? SpaceEvent.fromDoc(d) : null);
  Stream<Station?> station(String id) => _db.collection('stations').doc(id).snapshots().map((d) => d.exists ? Station.fromDoc(d) : null);
  Stream<Astronaut?> astronaut(String id) => _db.collection('astronauts').doc(id).snapshots().map((d) => d.exists ? Astronaut.fromDoc(d) : null);

  /// Articles that Spaceflight News tagged with this launch or event.
  Stream<List<Article>> newsFor({String? launchId, String? eventId}) {
    final field = launchId != null ? 'launchIds' : 'eventIds';
    final value = launchId ?? eventId;
    return _db.collection('news').where(field, arrayContains: value).limit(10).snapshots().map((s) {
      final list = s.docs.map(Article.fromDoc).toList()..sort((a, b) => _byDate(a.publishedAt, b.publishedAt, descending: true));
      return list;
    });
  }
}

/// Days of continuous human presence in orbit, counted from Expedition 1
/// arriving at the ISS on 2 November 2000.
Duration continuousPresence({DateTime? now}) => (now ?? DateTime.now()).toUtc().difference(DateTime.utc(2000, 11, 2, 9, 21));
