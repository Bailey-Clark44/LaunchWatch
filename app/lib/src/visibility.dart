import 'dart:math';

/// Where someone watches from: a city chosen from a list, or their approximate
/// current location (see [City.here]).
class City {
  const City(this.id, this.name, this.region, this.latitude, this.longitude) : isCurrentLocation = false;

  const City._here(this.id, this.region, this.latitude, this.longitude)
      : name = 'your location',
        isCurrentLocation = true;

  /// The device's location, rounded to two decimal places (about 1 km) before
  /// it is kept anywhere. That is plenty for a visibility estimate measured in
  /// hundreds of kilometres, and it is not a street address.
  factory City.here(double latitude, double longitude) {
    final lat = _round(latitude.clamp(-90.0, 90.0));
    final lon = _round(((longitude + 180) % 360 + 360) % 360 - 180);
    return City._here('$herePrefix${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}', _describe(lat, lon), lat, lon);
  }

  static const herePrefix = 'here:';

  final String id;
  final String name;
  final String region;
  final double latitude;
  final double longitude;
  final bool isCurrentLocation;

  String get label => isCurrentLocation ? 'Your location, $region' : '$name, $region';

  static City? byId(String? id) {
    if (id == null) return null;
    if (id.startsWith(herePrefix)) {
      final parts = id.substring(herePrefix.length).split(',');
      if (parts.length != 2) return null;
      final lat = double.tryParse(parts[0]);
      final lon = double.tryParse(parts[1]);
      if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) return null;
      return City.here(lat, lon);
    }
    for (final c in cities) {
      if (c.id == id) return c;
    }
    return null;
  }

  static double _round(double v) => (v * 100).roundToDouble() / 100;

  /// "near Edinburgh" when a listed city is within 60 km, otherwise coordinates.
  static String _describe(double lat, double lon) {
    City? nearest;
    var best = double.infinity;
    for (final c in cities) {
      final d = distanceKm(lat, lon, c.latitude, c.longitude);
      if (d < best) {
        best = d;
        nearest = c;
      }
    }
    if (nearest != null && best <= 60) return 'near ${nearest.name}';
    String deg(double v, String pos, String neg) => '${v.abs().toStringAsFixed(1)}°${v >= 0 ? pos : neg}';
    return '${deg(lat, 'N', 'S')} ${deg(lon, 'E', 'W')}';
  }
}

/// Cities near launch sites first, then major cities worldwide.
const cities = <City>[
  City('orlando', 'Orlando', 'Florida, US', 28.538, -81.379),
  City('cocoa-beach', 'Cocoa Beach', 'Florida, US', 28.320, -80.608),
  City('titusville', 'Titusville', 'Florida, US', 28.612, -80.807),
  City('melbourne-fl', 'Melbourne', 'Florida, US', 28.084, -80.608),
  City('daytona', 'Daytona Beach', 'Florida, US', 29.211, -81.023),
  City('jacksonville', 'Jacksonville', 'Florida, US', 30.332, -81.656),
  City('tampa', 'Tampa', 'Florida, US', 27.951, -82.457),
  City('miami', 'Miami', 'Florida, US', 25.762, -80.192),
  City('savannah', 'Savannah', 'Georgia, US', 32.081, -81.091),
  City('atlanta', 'Atlanta', 'Georgia, US', 33.749, -84.388),
  City('charleston', 'Charleston', 'South Carolina, US', 32.776, -79.931),
  City('brownsville', 'Brownsville', 'Texas, US', 25.901, -97.497),
  City('houston', 'Houston', 'Texas, US', 29.760, -95.370),
  City('lompoc', 'Lompoc', 'California, US', 34.639, -120.458),
  City('santa-barbara', 'Santa Barbara', 'California, US', 34.420, -119.698),
  City('los-angeles', 'Los Angeles', 'California, US', 34.052, -118.244),
  City('san-diego', 'San Diego', 'California, US', 32.716, -117.161),
  City('phoenix', 'Phoenix', 'Arizona, US', 33.448, -112.074),
  City('las-vegas', 'Las Vegas', 'Nevada, US', 36.170, -115.140),
  City('san-francisco', 'San Francisco', 'California, US', 37.775, -122.419),
  City('wallops', 'Chincoteague', 'Virginia, US', 37.933, -75.379),
  City('washington', 'Washington', 'DC, US', 38.907, -77.037),
  City('new-york', 'New York', 'New York, US', 40.713, -74.006),
  City('kodiak', 'Kodiak', 'Alaska, US', 57.790, -152.407),
  City('honolulu', 'Honolulu', 'Hawaii, US', 21.307, -157.858),
  City('toronto', 'Toronto', 'Ontario, CA', 43.653, -79.383),
  City('mexico-city', 'Mexico City', 'MX', 19.433, -99.133),
  City('kourou', 'Kourou', 'French Guiana', 5.160, -52.650),
  City('sao-paulo', 'São Paulo', 'BR', -23.551, -46.633),
  City('london', 'London', 'UK', 51.507, -0.128),
  City('edinburgh', 'Edinburgh', 'Scotland, UK', 55.953, -3.188),
  City('dundee', 'Dundee', 'Scotland, UK', 56.462, -2.971),
  City('glasgow', 'Glasgow', 'Scotland, UK', 55.861, -4.250),
  City('aberdeen', 'Aberdeen', 'Scotland, UK', 57.150, -2.094),
  City('inverness', 'Inverness', 'Scotland, UK', 57.478, -4.225),
  City('lerwick', 'Lerwick', 'Shetland, UK', 60.155, -1.145),
  City('unst', 'Unst (SaxaVord)', 'Shetland, UK', 60.815, -0.820),
  City('thurso', 'Thurso', 'Scotland, UK', 58.593, -3.527),
  City('stornoway', 'Stornoway', 'Scotland, UK', 58.209, -6.389),
  City('newquay', 'Newquay', 'England, UK', 50.415, -5.073),
  City('dublin', 'Dublin', 'IE', 53.350, -6.260),
  City('paris', 'Paris', 'FR', 48.857, 2.352),
  City('berlin', 'Berlin', 'DE', 52.520, 13.405),
  City('andoya', 'Andenes', 'NO', 69.314, 16.119),
  City('kiruna', 'Kiruna', 'SE', 67.856, 20.225),
  City('madrid', 'Madrid', 'ES', 40.417, -3.704),
  City('rome', 'Rome', 'IT', 41.903, 12.496),
  City('moscow', 'Moscow', 'RU', 55.756, 37.617),
  City('plesetsk', 'Mirny', 'Arkhangelsk, RU', 62.764, 40.336),
  City('baikonur', 'Baikonur', 'KZ', 45.616, 63.317),
  City('tel-aviv', 'Tel Aviv', 'IL', 32.085, 34.782),
  City('dubai', 'Dubai', 'AE', 25.205, 55.271),
  City('sriharikota', 'Chennai', 'Tamil Nadu, IN', 13.083, 80.271),
  City('bengaluru', 'Bengaluru', 'Karnataka, IN', 12.972, 77.594),
  City('mumbai', 'Mumbai', 'IN', 19.076, 72.878),
  City('wenchang', 'Haikou', 'Hainan, CN', 20.044, 110.199),
  City('jiuquan', 'Jiuquan', 'Gansu, CN', 39.733, 98.494),
  City('xichang', 'Xichang', 'Sichuan, CN', 27.894, 102.264),
  City('taiyuan', 'Taiyuan', 'Shanxi, CN', 37.870, 112.549),
  City('beijing', 'Beijing', 'CN', 39.904, 116.407),
  City('shanghai', 'Shanghai', 'CN', 31.230, 121.474),
  City('hong-kong', 'Hong Kong', 'CN', 22.320, 114.169),
  City('seoul', 'Seoul', 'KR', 37.567, 126.978),
  City('goheung', 'Goheung', 'KR', 34.611, 127.285),
  City('tanegashima', 'Kagoshima', 'JP', 31.597, 130.557),
  City('tokyo', 'Tokyo', 'JP', 35.676, 139.650),
  City('singapore', 'Singapore', 'SG', 1.352, 103.820),
  City('mahia', 'Gisborne', 'NZ', -38.662, 178.018),
  City('auckland', 'Auckland', 'NZ', -36.848, 174.763),
  City('sydney', 'Sydney', 'AU', -33.869, 151.209),
  City('melbourne-au', 'Melbourne', 'AU', -37.814, 144.963),
  City('bowen', 'Bowen', 'Queensland, AU', -20.013, 148.247),
];

enum VisibilityTier { atSite, clear, possible, unlikely, none }

class VisibilityEstimate {
  const VisibilityEstimate({required this.tier, required this.distanceKm, required this.direction, required this.headline, required this.detail});

  final VisibilityTier tier;
  final double distanceKm;
  final String direction;
  final String headline;
  final String detail;
}

const _earthKm = 6371.0;

double _rad(double deg) => deg * pi / 180;

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) + cos(_rad(lat1)) * cos(_rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * _earthKm * asin(min(1, sqrt(a.toDouble())));
}

/// Initial bearing from the viewer to the pad, 0 = north.
double bearing(double lat1, double lon1, double lat2, double lon2) {
  final y = sin(_rad(lon2 - lon1)) * cos(_rad(lat2));
  final x = cos(_rad(lat1)) * sin(_rad(lat2)) - sin(_rad(lat1)) * cos(_rad(lat2)) * cos(_rad(lon2 - lon1));
  return (atan2(y, x) * 180 / pi + 360) % 360;
}

String compass(double degrees) {
  const names = ['north', 'northeast', 'east', 'southeast', 'south', 'southwest', 'west', 'northwest'];
  return names[((degrees + 22.5) % 360 ~/ 45)];
}

/// A rough, honest estimate. A rocket climbing to ~100 km clears the horizon
/// for viewers up to roughly 1,000 km away, best at night or twilight. Weather,
/// trajectory, and terrain all matter, so this never says "you will see it".
VisibilityEstimate estimateVisibility({
  required City city,
  required double padLatitude,
  required double padLongitude,
  required bool suborbital,
  DateTime? net,
}) {
  final km = distanceKm(city.latitude, city.longitude, padLatitude, padLongitude);
  final dir = compass(bearing(city.latitude, city.longitude, padLatitude, padLongitude));
  final dark = net == null ? null : _isDarkAtPad(net, padLongitude);
  final night = dark == true ? ' A night launch is far easier to spot.' : '';
  final reach = suborbital ? 250.0 : 1000.0;
  final rounded = km < 10 ? km.toStringAsFixed(1) : km.round().toString();

  if (km < 25) {
    return VisibilityEstimate(
      tier: VisibilityTier.atSite,
      distanceKm: km,
      direction: dir,
      headline: 'Right next door',
      detail: 'You are about $rounded km from the pad. Expect to see and hear it from any clear spot.',
    );
  }
  if (km < (suborbital ? 80 : 300)) {
    return VisibilityEstimate(
      tier: VisibilityTier.clear,
      distanceKm: km,
      direction: dir,
      headline: 'Likely visible from ${city.name}',
      detail: 'The pad is $rounded km to the $dir. Look $dir just after liftoff, with a clear view of the horizon.$night',
    );
  }
  if (km < reach) {
    return VisibilityEstimate(
      tier: VisibilityTier.possible,
      distanceKm: km,
      direction: dir,
      headline: 'Possibly visible, low in the $dir',
      detail: 'At $rounded km away, the rocket may appear low on the horizon to the $dir a minute or two after liftoff, if skies are clear.$night',
    );
  }
  if (km < reach * 1.8) {
    return VisibilityEstimate(
      tier: VisibilityTier.unlikely,
      distanceKm: km,
      direction: dir,
      headline: 'Unlikely from ${city.name}',
      detail: 'At $rounded km, the rocket stays below or very near your horizon. Twilight launches are the exception: the exhaust plume can glow high in the sky.',
    );
  }
  return VisibilityEstimate(
    tier: VisibilityTier.none,
    distanceKm: km,
    direction: dir,
    headline: 'Too far to see',
    detail: 'The pad is about ${km.round()} km away. The webcast is your best view.',
  );
}

/// Approximate local solar hour at the pad; dark between 19:00 and 05:30.
bool _isDarkAtPad(DateTime net, double longitude) {
  final utc = net.toUtc();
  final solarHour = (utc.hour + utc.minute / 60 + longitude / 15 + 24) % 24;
  return solarHour >= 19 || solarHour < 5.5;
}
