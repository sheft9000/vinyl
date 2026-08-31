import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/navigation.dart';
import '../../core/theme.dart';
import '../../data/providers.dart';
import '../../player/accent.dart';
import '../../player/player_controller.dart';
import '../../widgets/artwork.dart';
import '../../widgets/async_view.dart';
import '../../widgets/track_tile.dart';
import '../artist/artist_page.dart';

class AlbumPage extends ConsumerWidget {
  const AlbumPage({super.key, required this.albumId});

  final int albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(albumDetailProvider(albumId));
    final accent = ref.watch(accentProvider);

    return Scaffold(
      backgroundColor: Vinyl.bg,
      body: AsyncView(
        value: detail,
        onRetry: () => ref.invalidate(albumDetailProvider(albumId)),
        builder: (data) {
          final album = data.album;
          final tracks = data.tracks;
          final player = ref.read(playerProvider);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 380,
                backgroundColor: Vinyl.bg,
                surfaceTintColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.parallax,
                  background: _AlbumHeader(
                    artKey: album.artKey,
                    accent: accent,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Vinyl.gutter, 18, Vinyl.gutter, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () => pushPage(
                          context,
                          ArtistPage(artistId: album.artistId),
                        ),
                        child: Text(
                          album.artistName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (album.year != null) '${album.year}',
                          plural(album.trackCount, 'brano', 'brani'),
                          formatTotal(
                              Duration(milliseconds: album.durationMs)),
                        ].join(' · '),
                        style: const TextStyle(
                            color: Vinyl.textDim, fontSize: 13),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          FilledButton.icon(
                            onPressed: () => player.playAll(
                              tracks,
                              label: album.title,
                            ),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Riproduci'),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () => player.playAll(
                              tracks,
                              label: album.title,
                              shuffle: true,
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Vinyl.text,
                              side: const BorderSide(
                                  color: Vinyl.strokeStrong),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            icon: const Icon(Icons.shuffle_rounded, size: 19),
                            label: const Text('Shuffle'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (context, i) => TrackTile(
                  track: tracks[i],
                  number: tracks[i].trackNo ?? i + 1,
                  showArtwork: false,
                  showAlbum: false,
                  onTap: () =>
                      player.playAll(tracks, index: i, label: album.title),
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

class _AlbumHeader extends StatelessWidget {
  const _AlbumHeader({required this.artKey, required this.accent});

  final String? artKey;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                accent.withValues(alpha: 0.55),
                accent.withValues(alpha: 0.15),
                Vinyl.bg,
              ],
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Artwork(
              artKey: artKey,
              size: 230,
              radius: 14,
              imageSize: 'full',
              lift: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
