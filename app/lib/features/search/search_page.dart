import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../player/player_controller.dart';
import '../../widgets/album_card.dart';
import '../../widgets/artwork.dart';
import '../../widgets/async_view.dart';
import '../../widgets/track_tile.dart';
import '../album/album_page.dart';
import '../artist/artist_page.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Una richiesta per lettera digitata sarebbe uno spreco e farebbe
  /// arrivare le risposte fuori ordine: aspettiamo che tu smetta di scrivere.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (mounted) ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);
    final player = ref.read(playerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  Vinyl.gutter, 14, Vinyl.gutter, 10),
              child: TextField(
                controller: _controller,
                onChanged: _onChanged,
                autocorrect: false,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Artisti, album, brani',
                  prefixIcon:
                      const Icon(Icons.search_rounded, color: Vinyl.textDim),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Vinyl.textDim),
                          onPressed: () {
                            _controller.clear();
                            _debounce?.cancel();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: query.trim().isEmpty
                  ? const EmptyPanel(
                      icon: Icons.search_rounded,
                      message:
                          'Cerca nella tua libreria.\nAccenti e maiuscole non contano.',
                    )
                  : AsyncView(
                      value: results,
                      onRetry: () => ref.invalidate(searchResultsProvider),
                      builder: (data) {
                        if (data.isEmpty) {
                          return EmptyPanel(
                            icon: Icons.search_off_rounded,
                            message: 'Nessun risultato per "$query".',
                          );
                        }
                        return ListView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 160),
                          children: [
                            if (data.artists.isNotEmpty) ...[
                              const SectionTitle('Artisti'),
                              SizedBox(
                                height: 168,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: Vinyl.gutter),
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: data.artists.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 16),
                                  itemBuilder: (context, i) => ArtistCircle(
                                    artist: data.artists[i],
                                    onTap: () => pushPage(
                                      context,
                                      ArtistPage(
                                          artistId: data.artists[i].id),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (data.albums.isNotEmpty) ...[
                              const SectionTitle('Album'),
                              ...data.albums.map(
                                (album) => ListTile(
                                  leading: Artwork(
                                      artKey: album.artKey,
                                      size: 48,
                                      radius: 7),
                                  title: Text(album.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: Text(album.artistName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  onTap: () => pushPage(
                                      context, AlbumPage(albumId: album.id)),
                                ),
                              ),
                            ],
                            if (data.tracks.isNotEmpty) ...[
                              const SectionTitle('Brani'),
                              ...List.generate(
                                data.tracks.length,
                                (i) => TrackTile(
                                  track: data.tracks[i],
                                  onTap: () => player.playAll(
                                    data.tracks,
                                    index: i,
                                    label: 'Risultati per "$query"',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
