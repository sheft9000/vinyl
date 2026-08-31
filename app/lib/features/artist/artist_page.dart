import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../player/accent.dart';
import '../../player/player_controller.dart';
import '../../widgets/album_card.dart';
import '../../widgets/artwork.dart';
import '../../widgets/async_view.dart';
import '../../widgets/track_tile.dart';
import '../album/album_page.dart';

class ArtistPage extends ConsumerWidget {
  const ArtistPage({super.key, required this.artistId});

  final int artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(artistDetailProvider(artistId));
    final accent = ref.watch(accentProvider);

    return Scaffold(
      backgroundColor: Vinyl.bg,
      body: AsyncView(
        value: detail,
        onRetry: () => ref.invalidate(artistDetailProvider(artistId)),
        builder: (data) {
          final artist = data.artist;
          final player = ref.read(playerProvider);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 300,
                backgroundColor: Vinyl.bg,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              accent.withValues(alpha: 0.5),
                              Vinyl.bg,
                            ],
                          ),
                        ),
                      ),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Artwork(
                            artKey: artist.artKey,
                            size: 168,
                            radius: 84,
                            imageSize: 'full',
                            lift: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Vinyl.gutter, 16, Vinyl.gutter, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artist.name,
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 6),
                      Text(
                        '${plural(artist.albumCount, 'album', 'album')} · '
                        '${plural(artist.trackCount, 'brano', 'brani')}',
                        style: const TextStyle(
                            color: Vinyl.textDim, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: data.topTracks.isEmpty
                            ? null
                            : () => player.playAll(
                                  data.topTracks,
                                  label: artist.name,
                                  shuffle: true,
                                ),
                        icon: const Icon(Icons.shuffle_rounded, size: 20),
                        label: const Text('Shuffle'),
                      ),
                    ],
                  ),
                ),
              ),
              if (data.albums.isNotEmpty) ...[
                const SliverToBoxAdapter(child: SectionTitle('Album')),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 216,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: Vinyl.gutter),
                      physics: const BouncingScrollPhysics(),
                      itemCount: data.albums.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 16),
                      itemBuilder: (context, i) => AlbumCard(
                        album: data.albums[i],
                        onTap: () => pushPage(
                            context, AlbumPage(albumId: data.albums[i].id)),
                      ),
                    ),
                  ),
                ),
              ],
              const SliverToBoxAdapter(child: SectionTitle('Brani')),
              SliverList.builder(
                itemCount: data.topTracks.length,
                itemBuilder: (context, i) => TrackTile(
                  track: data.topTracks[i],
                  onTap: () => player.playAll(
                    data.topTracks,
                    index: i,
                    label: artist.name,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 160)),
            ],
          );
        },
      ),
    );
  }
}
