import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/prefs.dart';

enum NightMode {
  auto('Auto'),
  always('Hidup'),
  never('Mati');

  const NightMode(this.label);
  final String label;
}

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

enum MapOrientation {
  headingUp('Ikut arah'),
  northUp('Utara ke atas');

  const MapOrientation(this.label);
  final String label;
}

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
