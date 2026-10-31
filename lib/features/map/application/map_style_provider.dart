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

