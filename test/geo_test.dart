import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/core/geo.dart';

void main() {
  final origin = LatLng(3.1390, 101.6869);

  test('metersPerPixel matches the web-mercator formula', () {
    expect(metersPerPixel(0, 0), closeTo(156543.03392, 1e-3));
    expect(metersPerPixel(17, 0), closeTo(1.19433, 1e-4));
    expect(metersPerPixel(17, 60), closeTo(1.19433 / 2, 1e-4)); // cos 60 degrees = 0.5
  });

  test('lookAhead goes the requested distance in the requested direction', () {
    final north = lookAhead(origin, 0, 100);
    expect(haversineM(origin, north), closeTo(100, 0.5));
    expect(bearingDeg(origin, north), closeTo(0, 0.5));

    final east = lookAhead(origin, 90, 250);
    expect(haversineM(origin, east), closeTo(250, 1.0));
    expect(bearingDeg(origin, east), closeTo(90, 0.5));

    final here = lookAhead(origin, 123, 0);
    expect(haversineM(origin, here), closeTo(0, 1e-6));
  });
}
