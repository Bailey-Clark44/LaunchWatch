import 'package:flutter_test/flutter_test.dart';
import 'package:launchwatch/src/visibility.dart';

void main() {
  test('current location is rounded to about 1 km before it is kept', () {
    final here = City.here(56.462018, -2.970721); // Dundee city centre
    expect(here.latitude, 56.46);
    expect(here.longitude, -2.97);
    expect(here.id, 'here:56.46,-2.97');
    expect(here.isCurrentLocation, isTrue);
  });

  test('current location survives a save and reload by id', () {
    final here = City.here(28.39, -80.61);
    final restored = City.byId(here.id)!;
    expect(restored.latitude, here.latitude);
    expect(restored.longitude, here.longitude);
    expect(restored.isCurrentLocation, isTrue);
  });

  test('current location is described by a nearby listed city, else coordinates', () {
    expect(City.here(28.40, -80.65).region, 'near Cocoa Beach');
    expect(City.here(28.40, -80.65).label, 'Your location, near Cocoa Beach');
    expect(City.here(-45.0, 170.5).region, '45.0°S 170.5°E');
    expect(City.here(56.462018, -2.970721).region, 'near Dundee');
  });

  test('current location reads naturally in visibility text', () {
    final here = City.here(28.53, -81.38);
    final estimate = estimateVisibility(city: here, padLatitude: 28.5618, padLongitude: -80.5772, suborbital: false, net: null);
    expect(estimate.headline, contains('your location'));
  });

  test('malformed or out-of-range location ids are ignored', () {
    expect(City.byId('here:'), isNull);
    expect(City.byId('here:abc,def'), isNull);
    expect(City.byId('here:95.00,10.00'), isNull);
    expect(City.byId('orlando')!.isCurrentLocation, isFalse);
  });
}
