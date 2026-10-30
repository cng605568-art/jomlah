import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../map/application/providers.dart';
import '../application/places_provider.dart';
import '../application/search_providers.dart';
import '../domain/place.dart';
import '../../../core/app_theme.dart';

class SearchBox extends ConsumerStatefulWidget {
  const SearchBox({super.key, required this.onPick, this.trailing});
  final void Function(Place place) onPick;

  /// Shown at the right end of the search pill while it is empty (the settings button).
  final Widget? trailing;

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
    final showChips = !_focus.hasFocus && _text.text.isEmpty;

    final pill = Material(
      color: AppColors.overlay,
      elevation: 8,
      shadowColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Nak ke mana?',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.search_rounded, color: AppColors.sky),
              ),
              suffixIcon: _text.text.isNotEmpty
                  ? IconButton(icon: const Icon(Icons.close_rounded), onPressed: _reset)
                  : (widget.trailing == null
                      ? null
                      : Padding(padding: const EdgeInsets.only(right: 7), child: widget.trailing)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pill,
        if (showChips)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _PlaceChip(
                  icon: Icons.home_rounded,
                  label: 'Rumah',
                  onTap: () => _shortcut(places.home, 'Rumah'),
                ),
                _PlaceChip(
                  icon: Icons.work_rounded,
                  label: 'Pejabat',
                  onTap: () => _shortcut(places.work, 'Pejabat'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small pill under the search bar: one tap to go home or to work.
class _PlaceChip extends StatelessWidget {
  const _PlaceChip({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.overlay,
        elevation: 4,
        shadowColor: Colors.black45,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(19),
          side: const BorderSide(color: AppColors.outline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: AppColors.sky),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
        ),
      );
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
