import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:jomlah/features/search/domain/place.dart';

Place _p(String name, double lat, double lng) =>
    Place(name: name, subtitle: 'KL', position: LatLng(lat, lng));

void main() {
  test('Place survives a JSON round trip', () {
    final back = Place.fromJson(_p('Pavilion', 3.149, 101.713).toJson());
    expect(back.name, 'Pavilion');
    expect(back.subtitle, 'KL');
    expect(back.position.latitude, closeTo(3.149, 1e-9));
    expect(back.position.longitude, closeTo(101.713, 1e-9));
  });

  test('pushRecent puts the newest first and moves repeats to the top', () {
    var list = <Place>[];
    list = pushRecent(list, _p('A', 3.10, 101.60));
    list = pushRecent(list, _p('B', 3.20, 101.70));
    list = pushRecent(list, _p('A', 3.10001, 101.60001)); // same place, a few metres off
    expect(list.map((p) => p.name).toList(), ['A', 'B']);
  });

  test('same name far apart counts as different places', () {
    var list = <Place>[];
    list = pushRecent(list, _p('McDonalds', 3.10, 101.60));
    list = pushRecent(list, _p('McDonalds', 3.30, 101.80));
    expect(list.length, 2);
  });

  test('pushRecent keeps at most 8', () {
    var list = <Place>[];
    for (var i = 0; i < 12; i++) {
      list = pushRecent(list, _p('P$i', 3.0 + i * 0.01, 101.0 + i * 0.01));
    }
    expect(list.length, 8);
    expect(list.first.name, 'P11');
  });
}
