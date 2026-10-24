import 'package:flutter_test/flutter_test.dart';
import 'package:jomlah/features/routing/data/polyline.dart';

void main() {
  test('decodes the classic Google sample (precision 5)', () {
    final pts = decodePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@', precision: 5);
    expect(pts.length, 3);
    expect(pts[0].latitude, closeTo(38.5, 1e-9));
    expect(pts[0].longitude, closeTo(-120.2, 1e-9));
    expect(pts[2].latitude, closeTo(43.252, 1e-9));
    expect(pts[2].longitude, closeTo(-126.453, 1e-9));
  });
}
