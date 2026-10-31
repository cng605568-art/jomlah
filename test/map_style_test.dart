import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jomlah/core/l10n/language.dart';
import 'package:jomlah/core/prefs.dart';
import 'package:jomlah/features/map/application/map_style_provider.dart';
import 'package:jomlah/features/map/application/vector_style.dart';

// The new vector map: which style is used, its cache id, label language, and the Settings choice.

/// A style document like OpenFreeMap's: no name, so every style reads with the same theme id.
vt.Theme _theme(String background) => const vt.ThemeReader().read({
      'version': 8,
      'layers': [
        {
          'id': 'background',
          'type': 'background',
          'paint': {'background-color': background},
        },
      ],
    });

void main() {
  test('day and night, in every language, each get their own tile cache', () {
    final keys = [
      for (final night in [false, true])
        for (final l in AppLanguage.values) (night: night, language: l),
    ];
    expect(keys.map(themeIdFor).toSet().length, keys.length);
    expect(themeIdFor((night: false, language: AppLanguage.ms)), 'jomlah:liberty:ms');
    expect(themeIdFor((night: true, language: AppLanguage.zh)), 'jomlah:fiord:zh');
  });

  test('a read style gets our id but keeps its layers and background colour', () {
    final day = _theme('#f8f4f0');
    final night = _theme('#45516e');
    expect(day.id, night.id); // the reason for our own ids: both read as "style@8#"

    final s = MapStyle(
      vt.Style(theme: night, providers: const vt.TileProviders({})),
      (night: true, language: AppLanguage.en),
    );
    expect(s.theme.id, 'jomlah:fiord:en');
    expect(s.theme.layers, same(night.layers));
    expect(s.background!.toARGB32(), 0xFF45516E);
  });

  test('map labels follow the app language', () {
    expect(labelLanguage(AppLanguage.ms), 'ms');
    expect(labelLanguage(AppLanguage.en), 'en');
    expect(labelLanguage(AppLanguage.zh), 'zh');
  });

  test('the credit names everyone the licences ask for', () {
    expect(kVectorCredit, contains('OpenFreeMap'));
    expect(kVectorCredit, contains('OpenMapTiles'));
    expect(kVectorCredit, contains('OpenStreetMap'));
  });

  test('the new map is the default; choosing Klasik is remembered', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    ProviderContainer open() {
      final c = ProviderContainer(overrides: [sharedPrefsProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      return c;
    }

    final first = open();
    expect(first.read(mapLookProvider), MapLook.vector);
    first.read(mapLookProvider.notifier).set(MapLook.classic);
    expect(prefs.getString('map.look'), 'classic');
    expect(open().read(mapLookProvider), MapLook.classic);
  });
}
