import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/features/routing/domain/route_plan.dart';

void main() {
  final shape = [
    LatLng(3.00, 101.00),
    LatLng(3.01, 101.01),
    LatLng(3.02, 101.02),
    LatLng(3.03, 101.03),
  ];

  test('drops the part of the route already driven', () {
    final rest = remainingShape(shape, 1);
    expect(rest.length, 2);
    expect(rest.first.latitude, 3.02);
    expect(rest.last.latitude, 3.03);
  });

  test('starts the line at the car when given', () {
    final car = LatLng(3.015, 101.012);
    final rest = remainingShape(shape, 1, from: car);
    expect(rest.length, 3);
    expect(rest.first.latitude, 3.015);
    expect(rest[1].latitude, 3.02);
  });

  test('never runs off either end of the route', () {
    expect(remainingShape(shape, 99).length, 1);
    expect(remainingShape(shape, 99).first.latitude, 3.03);
    expect(remainingShape(shape, -5).length, 4);
    expect(remainingShape(const [], 0), isEmpty);
  });
}
