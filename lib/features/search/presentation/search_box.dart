import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../map/application/providers.dart';
import '../application/places_provider.dart';
import '../application/search_providers.dart';
import '../domain/place.dart';
import '../../../core/app_theme.dart';

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
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {})); // show Home/Work/recents while focused
  }

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
    ref.read(placesProvider.notifier).addRecent(p);
    widget.onPick(p);
  }

  void _shortcut(Place? p, String label) {
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cari tempat, tekan ⋮ di sebelahnya, pilih "Jadikan $label".')),
      );
      return;
    }
    _choose(p);
  }

  void _save(String where, Place p) {
    final places = ref.read(placesProvider.notifier);
    if (where == 'home') {
      places.setHome(p);
    } else {
      places.setWork(p);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${where == 'home' ? 'Rumah' : 'Pejabat'} disimpan.')),
    );
  }

  Widget _placeTile(Place p, {required IconData icon}) => ListTile(
        leading: Icon(icon),
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: p.subtitle.isEmpty
            ? null
            : Text(p.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: PopupMenuButton<String>(
          tooltip: 'Lagi',
          onSelected: (v) => _save(v, p),
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'home', child: Text('Jadikan Rumah')),
            PopupMenuItem(value: 'work', child: Text('Jadikan Pejabat')),
          ],
        ),
        onTap: () => _choose(p),
      );

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(searchProvider);
    final places = ref.watch(placesProvider);
    final placesCtl = ref.read(placesProvider.notifier);
    final searching = s.query.length >= 3;
    final showShortcuts = _focus.hasFocus && !searching;

    return Material(
      color: AppColors.overlay,
      elevation: 6,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.outline),
      ),
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
              prefixIcon: const Icon(Icons.search, color: AppColors.sky),
              suffixIcon: _text.text.isEmpty
                  ? null
                  : IconButton(icon: const Icon(Icons.close), onPressed: _reset),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (showShortcuts) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _ShortcutCard(
                      icon: Icons.home_outlined,
                      label: 'Rumah',
                      place: places.home,
                      onTap: () => _shortcut(places.home, 'Rumah'),
                      onClear: placesCtl.clearHome,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ShortcutCard(
                      icon: Icons.work_outline,
                      label: 'Pejabat',
                      place: places.work,
                      onTap: () => _shortcut(places.work, 'Pejabat'),
                      onClear: placesCtl.clearWork,
                    ),
                  ),
                ],
              ),
            ),
            if (places.recents.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.3),
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final p in places.recents) _placeTile(p, icon: Icons.history),
                  ],
                ),
              ),
          ],
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
                  for (final p in s.results) _placeTile(p, icon: Icons.place_outlined),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Home / Work button. Tap to go there, long-press to remove it.
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.icon,
    required this.label,
    required this.place,
    required this.onTap,
    required this.onClear,
  });

  final IconData icon;
  final String label;
  final Place? place;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: place == null ? null : onClear,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.raised,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.sky),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      place?.name ?? 'Belum ditetapkan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
