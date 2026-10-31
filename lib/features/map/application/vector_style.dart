import 'package:flutter/painting.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/language.dart';

// The vector map. OpenFreeMap (openfreemap.org) serves map tiles made from OpenStreetMap data for
// free: no key, no sign-up, no usage limits. The style says how to draw them; the phone does the
// drawing, so the map stays sharp at every zoom and can have a properly dark night look.

/// Where the styles live. A self-hosted copy can be used with --dart-define=MAP_STYLE_BASE=...
const kMapStyleBase = String.fromEnvironment(
  'MAP_STYLE_BASE',
  defaultValue: 'https://tiles.openfreemap.org/styles/',
);

const kDayStyle = 'liberty'; // light, clear, close to what people know from other map apps
const kNightStyle = 'fiord'; // dark slate blue, roads still easy to tell apart (black "dark" was too dim)

/// Credit the map must show: OpenFreeMap, the OpenMapTiles schema and OpenStreetMap's data.
const kVectorCredit = '© OpenFreeMap © OpenMapTiles © OpenStreetMap contributors';

typedef MapStyleKey = ({bool night, AppLanguage language});

/// Map labels follow the app's language where OpenStreetMap has a translated name ("name:zh" for
/// 吉隆坡); everything else keeps its local name.
String labelLanguage(AppLanguage l) => switch (l) {
      AppLanguage.ms => 'ms',
      AppLanguage.en => 'en',
      AppLanguage.zh => 'zh',
    };

/// The theme id keys the layer's cache of finished tiles, and every OpenFreeMap style reports the
/// same one ("style@8#"). Without an id of our own, the night map could show day tiles from that cache.
String themeIdFor(MapStyleKey key) =>
    'jomlah:${key.night ? kNightStyle : kDayStyle}:${labelLanguage(key.language)}';

/// A style ready to draw.
class MapStyle {
  MapStyle(this.style, MapStyleKey key)
      : theme = vt.Theme(id: themeIdFor(key), layers: style.theme.layers),
        background = style.theme.backgroundColor(15);

  final vt.Style style;
  final vt.Theme theme;

  /// Shown under the tiles while they load, so the map does not flash grey.
  final Color? background;
}

/// Reads the day or night style once per app run. The style and its icons are kept on the phone, so
/// later starts work even with a weak signal. When it cannot be read at all (no internet on the
/// very first start), the map shows the classic tiles instead; MapScreen tries again when the app
/// comes back to the front.
final vectorStyleProvider = FutureProvider.family<MapStyle, MapStyleKey>((ref, key) async {
  final style = await vt.StyleReader(
    uri: '$kMapStyleBase${key.night ? kNightStyle : kDayStyle}',
    language: labelLanguage(key.language),
  ).read();
  return MapStyle(style, key);
});
