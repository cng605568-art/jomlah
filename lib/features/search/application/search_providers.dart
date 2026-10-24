import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../data/photon_client.dart';
import '../domain/place.dart';

final photonClientProvider = Provider<PhotonClient>((ref) => PhotonClient());

class SearchState {
  const SearchState({
    this.query = '',
    this.results = const [],
    this.loading = false,
    this.error,
  });
  final String query;
  final List<Place> results;
  final bool loading;
  final String? error;
}

class SearchNotifier extends Notifier<SearchState> {
  Timer? _debounce;
  int _seq = 0; // lets us ignore answers to questions the user has already moved on from

  @override
  SearchState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const SearchState();
  }

  void onQueryChanged(String raw, {LatLng? near}) {
    final q = raw.trim();
    _debounce?.cancel();
    final mySeq = ++_seq;
    if (q.length < 3) {
      state = SearchState(query: q);
      return;
    }
    state = SearchState(query: q, results: state.results, loading: true);
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await ref.read(photonClientProvider).search(q, near: near);
        if (mySeq != _seq) return;
        state = SearchState(query: q, results: results);
      } catch (e) {
        if (mySeq != _seq) return;
        state = SearchState(query: q, error: e is SearchException ? e.message : 'Carian gagal.');
      }
    });
  }

  void clear() {
    _debounce?.cancel();
    _seq++;
    state = const SearchState();
  }
}

final searchProvider =
    NotifierProvider<SearchNotifier, SearchState>(SearchNotifier.new);
