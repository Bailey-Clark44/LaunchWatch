import 'package:flutter_test/flutter_test.dart';
import 'package:launchwatch/src/theme.dart';

void main() {
  test('status words stay readable', () {
    expect(statusLabel('Go for Launch'), 'Go');
    expect(statusLabel('To Be Determined'), 'Unconfirmed');
    expect(statusLabel('Launch Failure'), 'Failure');
    expect(statusLabel('On Hold'), 'Hold');
    expect(statusTone('Launch Failure').label, 'Failure');
  });
}
