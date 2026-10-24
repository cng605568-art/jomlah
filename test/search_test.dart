import 'package:flutter_test/flutter_test.dart';
import 'package:jomlah/features/search/data/photon_client.dart';

const _sample = '''
{"features":[
 {"type":"Feature","geometry":{"type":"Point","coordinates":[101.7116,3.1579]},
  "properties":{"name":"Petronas Twin Towers","street":"Jalan Ampang","city":"Kuala Lumpur",
                "state":"Kuala Lumpur","countrycode":"MY"}},
 {"type":"Feature","geometry":{"type":"Point","coordinates":[103.85,1.29]},
  "properties":{"name":"Marina Bay","countrycode":"SG"}},
 {"type":"Feature","geometry":{"type":"Point","coordinates":[101.69,3.17]},
  "properties":{"street":"Jalan Duta","housenumber":"12","city":"Kuala Lumpur","countrycode":"MY"}}
]}
''';

void main() {
  test('keeps Malaysian results only and builds readable titles', () {
    final places = parsePhotonResponse(_sample);
    expect(places.length, 2);

    expect(places[0].name, 'Petronas Twin Towers');
    expect(places[0].subtitle, 'Jalan Ampang, Kuala Lumpur');
    expect(places[0].position.latitude, closeTo(3.1579, 1e-9));
    expect(places[0].position.longitude, closeTo(101.7116, 1e-9));

    expect(places[1].name, 'Jalan Duta 12');
    expect(places[1].subtitle, 'Kuala Lumpur');
  });
}
