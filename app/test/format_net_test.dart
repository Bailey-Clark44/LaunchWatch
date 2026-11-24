import 'package:flutter_test/flutter_test.dart';
import 'package:launchwatch/src/format_net.dart';

void main() {
  test('day precision does not invent a clock time', () {
    final net = DateTime.utc(2026, 11, 13);
    expect(formatNet(net, 'DAY'), isNot(contains(':')));
    expect(formatNet(net, 'DAY'), contains('2026'));
  });

  test('minute precision includes a time', () {
    expect(formatNet(DateTime.utc(2026, 11, 13, 18, 30), 'MIN'), contains(':'));
  });

  test('hour precision stays approximate', () {
    expect(formatNet(DateTime.utc(2026, 11, 20, 15), 'HR'), contains('about'));
    expect(formatNet(DateTime.utc(2026, 11, 20, 15), 'HR'), isNot(contains(':00')));
  });

  test('a year stays a year', () {
    expect(formatNet(DateTime.utc(2027, 1, 1), 'Y'), '2027');
  });
}
