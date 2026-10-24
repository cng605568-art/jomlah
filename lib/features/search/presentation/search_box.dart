import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../map/application/providers.dart';
import '../application/search_providers.dart';
import '../domain/place.dart';

class SearchBox extends ConsumerStatefulWidget {
  const SearchBox({super.key, required this.onPick});
  final void Function(Place place) onPick;

  @override
  ConsumerState<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends ConsumerState<SearchBox> {
  final _text = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  LatLng? _near() {
    final pos = ref.read(locationProvider).valueOrNull;
    return pos == null ? null : LatLng(pos.latitude, pos.longitude);
  }

  void _reset() {
    _text.clear();
    ref.read(searchProvider.notifier).clear();
    setState(() {});
  }

  void _choose(Place p) {
    _focus.unfocus();
    _reset();
    widget.onPick(p);
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(searchProvider);
    final searching = s.query.length >= 3;

    return Material(
      color: const Color(0xF2171C36),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _text,
            focusNode: _focus,
            textInputAction: TextInputAction.search,
            onChanged: (v) {
              ref.read(searchProvider.notifier).onQueryChanged(v, near: _near());
              setState(() {}); // shows or hides the clear button
            },
            decoration: InputDecoration(
              hintText: 'Nak ke mana? (atau tekan lama pada peta)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _text.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: _reset),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (searching && s.loading && s.results.isEmpty) const LinearProgressIndicator(),
          if (searching && s.error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(s.error!)),
          if (searching && !s.loading && s.error == null && s.results.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Tiada hasil. Cuba nama lain.'),
            ),
          if (searching && s.results.isNotEmpty)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final p in s.results)
                    ListTile(
                      leading: const Icon(Icons.place_outlined),
                      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: p.subtitle.isEmpty
                          ? null
                          : Text(p.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => _choose(p),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
