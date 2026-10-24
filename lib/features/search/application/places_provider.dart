import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/prefs.dart';
import '../domain/place.dart';

class PlacesState {
  const PlacesState({this.home, this.work, this.recents = const []});
  final Place? home;
  final Place? work;
  final List<Place> recents;
}

/// Saved Home, Work and recent destinations. Stored on the phone only.
class PlacesNotifier extends Notifier<PlacesState> {
  static const _homeKey = 'places.home';
  static const _workKey = 'places.work';
  static const _recentsKey = 'places.recents';

  @override
  PlacesState build() {
    final prefs = ref.read(sharedPrefsProvider);

    Place? decode(String? raw) {
      if (raw == null) return null;
      try {
        return Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null; // ignore anything unreadable
      }
    }

    return PlacesState(
      home: decode(prefs.getString(_homeKey)),
      work: decode(prefs.getString(_workKey)),
      recents: [
        for (final raw in prefs.getStringList(_recentsKey) ?? const <String>[])
          if (decode(raw) != null) decode(raw)!,
      ],
    );
  }

  void setHome(Place p) => _set(PlacesState(home: p, work: state.work, recents: state.recents));
  void setWork(Place p) => _set(PlacesState(home: state.home, work: p, recents: state.recents));
  void clearHome() => _set(PlacesState(work: state.work, recents: state.recents));
  void clearWork() => _set(PlacesState(home: state.home, recents: state.recents));
  void addRecent(Place p) =>
      _set(PlacesState(home: state.home, work: state.work, recents: pushRecent(state.recents, p)));

  void _set(PlacesState next) {
    state = next;
    final prefs = ref.read(sharedPrefsProvider);
    void put(String key, Place? p) {
      if (p == null) {
        prefs.remove(key);
      } else {
        prefs.setString(key, jsonEncode(p.toJson()));
      }
    }

    put(_homeKey, next.home);
    put(_workKey, next.work);
    prefs.setStringList(_recentsKey, [for (final p in next.recents) jsonEncode(p.toJson())]);
  }
}

final placesProvider =
    NotifierProvider<PlacesNotifier, PlacesState>(PlacesNotifier.new);
