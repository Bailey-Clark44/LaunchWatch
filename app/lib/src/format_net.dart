import 'package:intl/intl.dart';

const _clock = {'SEC', 'MIN', 'HR'};
const _fine = {'SEC', 'MIN', 'HR', 'AM', 'PM', 'DAY'};
const _quarter = {'Q1', 'Q2', 'Q3', 'Q4', 'H1', 'H2', 'FY'};

/// Precision says nothing finer than a week. These launches are not dated yet.
bool isCoarse(String? abbrev) => !_fine.contains(abbrev) && abbrev != 'WK';

bool precisionHasClock(String? abbrev) => _clock.contains(abbrev);

/// Countdowns only for a published clock time inside 48 hours, and only
/// while the launch is Go, on Hold, or in flight.
bool countdownAllowed(DateTime? net, String? abbrev, int? statusId, {DateTime? now}) {
  if (net == null || (abbrev != 'SEC' && abbrev != 'MIN')) return false;
  if (statusId != 1 && statusId != 5 && statusId != 6) return false;
  final until = net.difference(now ?? DateTime.now());
  return until.inHours < 48 && until > const Duration(hours: -6);
}

/// Formats a NET using the precision Launch Library 2 published.
/// Coarse periods are read in UTC so 2027 never becomes "Dec 31, 2026".
String formatNet(DateTime net, String? abbrev) {
  final local = net.toLocal();
  final utc = net.toUtc();
  final date = DateFormat.yMMMd().format(local);
  switch (abbrev) {
    case 'SEC':
    case 'MIN':
      return DateFormat.yMMMd().add_jm().format(local);
    case 'HR':
      return '$date, about ${DateFormat('h a').format(local)}';
    case 'AM':
      return '$date, morning';
    case 'PM':
      return '$date, afternoon';
    case 'DAY':
      return date;
    case 'WK':
      return 'Week of ${DateFormat.MMMd().format(local)}';
    case 'M':
      return DateFormat.yMMMM().format(utc);
    case 'FY':
      return 'FY ${utc.year}';
    case 'Q1':
    case 'Q2':
    case 'Q3':
    case 'Q4':
    case 'H1':
    case 'H2':
      return '$abbrev ${utc.year}';
    case 'Y':
      return '${utc.year}';
    case 'DEC':
      return 'The ${utc.year ~/ 10 * 10}s';
    default:
      return date;
  }
}

/// A compact two-line date for timeline rows: ("NOV", "13") or ("Q4", "2026").
(String, String) formatNetBadge(DateTime? net, String? abbrev) {
  if (net == null) return ('TBD', '');
  final local = net.toLocal();
  final utc = net.toUtc();
  if (_fine.contains(abbrev)) return (DateFormat('MMM').format(local).toUpperCase(), DateFormat('d').format(local));
  if (abbrev == 'WK') return ('WK OF', DateFormat('d MMM').format(local));
  if (abbrev == 'M') return (DateFormat('MMM').format(utc).toUpperCase(), '${utc.year}');
  if (_quarter.contains(abbrev)) return (abbrev == 'FY' ? 'FY' : abbrev!, '${utc.year}');
  if (abbrev == 'DEC') return ('DECADE', '${utc.year ~/ 10 * 10}s');
  return ('YEAR', '${utc.year}');
}

/// Clock time on the row, only when there is one.
String? formatRowClock(DateTime? net, String? abbrev) {
  if (net == null) return null;
  final local = net.toLocal();
  return switch (abbrev) {
    'SEC' || 'MIN' => DateFormat.jm().format(local),
    'HR' => '~${DateFormat('h a').format(local)}',
    'AM' => 'Morning',
    'PM' => 'Afternoon',
    _ => null,
  };
}

/// Clock time in UTC. Use only when the published precision is hour or better.
String formatUtcClock(DateTime net) {
  return '${DateFormat.yMMMd().add_Hm().format(net.toUtc())} UTC';
}

String precisionLabel(String? precision) {
  return switch (precision) {
    'SEC' || 'MIN' => 'Exact launch time',
    'HR' => 'Time to the hour',
    'AM' || 'PM' || 'DAY' => 'Date confirmed, time not yet set',
    'WK' => 'Week only',
    'M' => 'Month only',
    'Q1' || 'Q2' || 'Q3' || 'Q4' => 'Quarter only',
    'H1' || 'H2' => 'Half-year only',
    'FY' => 'Fiscal year only',
    'Y' => 'Year only',
    'DEC' => 'Decade only',
    _ => 'Precision not published',
  };
}

/// "T−02:14:09" before launch, "T+00:03:12" after.
String formatCountdown(Duration until) {
  final sign = until.isNegative ? '+' : '−';
  final d = until.abs();
  String two(int n) => n.toString().padLeft(2, '0');
  final hours = d.inHours;
  return 'T$sign${two(hours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}

String relativeAge(DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}
