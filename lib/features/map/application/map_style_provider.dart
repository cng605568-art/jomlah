import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/prefs.dart';

/// Shown in Settings as Auto / Hidup / Mati (see AppStrings).
enum NightMode { auto, always, never }

class NightModeNotifier extends Notifier<NightMode> {
  static const _key = 'map.night';

  @override
  NightMode build() {
    final id = ref.read(sharedPrefsProvider).getString(_key);
    return NightMode.values.firstWhere((m) => m.name == id, orElse: () => NightMode.auto);
  }

  void set(NightMode m) {
    state = m;
    ref.read(sharedPrefsProvider).setString(_key, m.name);
  }
}

final nightModeProvider =
    NotifierProvider<NightModeNotifier, NightMode>(NightModeNotifier.new);

/// Shown in Settings as "Ikut arah" / "Utara ke atas" (see AppStrings).
enum MapOrientation { headingUp, northUp }

/// Heading-up turns the map so the road ahead is always at the top while you drive.
class MapOrientationNotifier extends Notifier<MapOrientation> {
  static const _key = 'map.orientation';

  @override
  MapOrientation build() {
    final id = ref.read(sharedPrefsProvider).getString(_key);
    return MapOrientation.values.firstWhere((m) => m.name == id, orElse: () => MapOrientation.headingUp);
  }

  void set(MapOrientation m) {
    state = m;
    ref.read(sharedPrefsProvider).setString(_key, m.name);
  }
}

final mapOrientationProvider =
    NotifierProvider<MapOrientationNotifier, MapOrientation>(MapOrientationNotifier.new);

/// Shown in Settings as "Baharu" / "Klasik" (see AppStrings). The new look is OpenFreeMap's vector map
/// (sharp at any zoom, a real dark map at night, labels that stay upright when the map turns).
/// Classic is the plain OpenStreetMap picture tiles, kept in case the new map misbehaves on a phone.
enum MapLook { vector, classic }

class MapLookNotifier extends Notifier<MapLook> {
  static const _key = 'map.look';

  @override
  MapLook build() {
    final id = ref.read(sharedPrefsProvider).getString(_key);
    return MapLook.values.firstWhere((m) => m.name == id, orElse: () => MapLook.vector);
  }

  void set(MapLook m) {
    state = m;
    ref.read(sharedPrefsProvider).setString(_key, m.name);
  }
}

final mapLookProvider = NotifierProvider<MapLookNotifier, MapLook>(MapLookNotifier.new);
