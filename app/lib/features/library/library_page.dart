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

class LibraryPage extends ConsumerWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(Vinyl.gutter, 12, Vinyl.gutter, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Libreria',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.label,
                labelPadding: const EdgeInsets.symmetric(horizontal: 14),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                labelColor: Vinyl.text,
                unselectedLabelColor: Vinyl.textDim,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'Album'),
                  Tab(text: 'Artisti'),
                  Tab(text: 'Generi'),
                ],
              ),
              const Expanded(
                child: TabBarView(
                  children: [_AlbumsTab(), _ArtistsTab(), _GenresTab()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albums = ref.watch(allAlbumsProvider);
    return AsyncView(
      value: albums,
      onRetry: () => ref.invalidate(allAlbumsProvider),
      builder: (items) => items.isEmpty
          ? const EmptyPanel(message: 'Nessun album nella libreria.')
          : GridView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  Vinyl.gutter, 16, Vinyl.gutter, 170),
              gridDelegate:
                  const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 190,
                mainAxisSpacing: 22,
                crossAxisSpacing: 16,
                childAspectRatio: 0.74,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => AlbumCard(
                album: items[i],
                width: double.infinity,
                onTap: () => pushPage(context, AlbumPage(albumId: items[i].id)),
              ),
            ),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artists = ref.watch(allArtistsProvider);
    return AsyncView(
      value: artists,
      onRetry: () => ref.invalidate(allArtistsProvider),
      builder: (items) => items.isEmpty
          ? const EmptyPanel(message: 'Nessun artista nella libreria.')
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 170),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final artist = items[i];
                return ListTile(
                  leading: Artwork(
                    artKey: artist.artKey,
                    size: 48,
                    radius: 24,
                  ),
                  title: Text(artist.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${artist.albumCount} album · ${artist.trackCount} brani',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded,
                      color: Vinyl.textDim),
                  onTap: () =>
                      pushPage(context, ArtistPage(artistId: artist.id)),
                );
              },
            ),
    );
  }
}

class _GenresTab extends ConsumerWidget {
  const _GenresTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genres = ref.watch(genresProvider);
    return AsyncView(
      value: genres,
      onRetry: () => ref.invalidate(genresProvider),
      builder: (items) => items.isEmpty
          ? const EmptyPanel(
              icon: Icons.label_outline_rounded,
              message: 'Nessun genere nei tag della tua libreria.',
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 170),
              itemCount: items.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(items[i].name),
                subtitle: Text('${items[i].trackCount} brani',
                    style: const TextStyle(fontSize: 12.5)),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: Vinyl.textDim),
                onTap: () =>
                    pushPage(context, GenrePage(genre: items[i].name)),
              ),
            ),
    );
  }
}

class GenrePage extends ConsumerWidget {
  const GenrePage({super.key, required this.genre});

  final String genre;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tracks = ref.watch(genreTracksProvider(genre));
    final player = ref.read(playerProvider);

    return Scaffold(
      backgroundColor: Vinyl.bg,
      appBar: AppBar(title: Text(genre)),
      body: AsyncView(
        value: tracks,
        onRetry: () => ref.invalidate(genreTracksProvider(genre)),
        builder: (items) => ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 170),
          itemCount: items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(Vinyl.gutter, 4, 0, 12),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: items.isEmpty
                          ? null
                          : () => player.playAll(items,
                              label: genre, shuffle: true),
                      icon: const Icon(Icons.shuffle_rounded, size: 20),
                      label: const Text('Shuffle'),
                    ),
                  ],
                ),
              );
            }
            final index = i - 1;
            return TrackTile(
              track: items[index],
              onTap: () =>
                  player.playAll(items, index: index, label: genre),
            );
          },
        ),
      ),
    );
  }
}
