import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/ios.dart';
import '../../core/navigation.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../player/accent.dart';
import '../../player/player_controller.dart';
import '../../widgets/artwork.dart';
import '../album/album_page.dart';
import '../settings/settings_page.dart';
import 'skin_switcher.dart';

/// Home in stile Musica di Apple.
///
/// Tre cose la rendono iOS e non "Material dipinto di nero": il titolo grande
/// che si rimpicciolisce scorrendo, le liste raggruppate dentro un blocco
/// arrotondato con i separatori rientrati fino al testo, e le didascalie
/// piccole sotto le copertine invece delle schede con bordo.
class HomeApple extends ConsumerWidget {
  const HomeApple({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    final albums = ref.watch(recentAlbumsProvider);
    final tracks = ref.watch(recentTracksProvider);

    return CupertinoTheme(
      data: CupertinoThemeData(
        brightness: Brightness.dark,
        primaryColor: accent,
        scaffoldBackgroundColor: IOS.background,
        barBackgroundColor: const Color(0xC7101014),
        textTheme: CupertinoTextThemeData(
          primaryColor: IOS.label,
          textStyle: IOSText.body,
          navTitleTextStyle: IOSText.headline,
          navLargeTitleTextStyle: IOSText.largeTitle,
          actionTextStyle: IOSText.body.copyWith(color: accent),
        ),
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Ascolta ora'),
            backgroundColor: const Color(0xC7101014),
            border: const Border(
              bottom: BorderSide(color: IOS.separator, width: 0.0),
            ),
            stretch: true,
            automaticallyImplyLeading: false,
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: () => pushPage(context, const SettingsPage()),
              child: Icon(CupertinoIcons.gear, color: accent, size: 24),
            ),
          ),
          const SliverToBoxAdapter(child: SkinSwitcher()),
          SliverToBoxAdapter(child: _PlayBar(accent: accent)),
          SliverToBoxAdapter(
            child: albums.when(
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : _Shelf(albums: items),
              loading: () => const _ShelfPlaceholder(),
              error: (e, _) => _InlineError(message: '$e'),
            ),
          ),
          SliverToBoxAdapter(
            child: tracks.when(
              data: (items) => items.isEmpty
                  ? const SizedBox.shrink()
                  : _TrackGroup(tracks: items, accent: accent),
              loading: () => const SizedBox(height: 120),
              error: (e, _) => _InlineError(message: '$e'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 170)),
        ],
      ),
    );
  }
}

/// I due pulsanti che Apple mette in cima agli album: un blocco unico diviso
/// da un filo verticale, non due bottoni separati.
class _PlayBar extends ConsumerWidget {
  const _PlayBar({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider);
    final stats = ref.watch(statsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(IOS.margin, 6, IOS.margin, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: IOS.surface,
              borderRadius: BorderRadius.circular(IOS.radiusCard),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _PlayBarButton(
                    icon: CupertinoIcons.play_fill,
                    label: 'Riproduci',
                    accent: accent,
                    onPressed: () async {
                      final list = await ref
                          .read(apiClientProvider)
                          .tracks(sort: 'added', limit: 200);
                      await player.playAll(list.items, label: 'La tua libreria');
                    },
                  ),
                ),
                Container(width: 0.5, height: 26, color: IOS.separator),
                Expanded(
                  child: _PlayBarButton(
                    icon: CupertinoIcons.shuffle,
                    label: 'Casuale',
                    accent: accent,
                    onPressed: player.shuffleLibrary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          stats.maybeWhen(
            data: (s) => Text(
              '${plural(s.tracks, 'brano', 'brani')} · '
              '${plural(s.albums, 'album', 'album')} · '
              '${formatTotal(Duration(milliseconds: s.totalDurationMs))}',
              style: IOSText.footnote,
            ),
            orElse: () => const SizedBox(height: 18),
          ),
        ],
      ),
    );
  }
}

class _PlayBarButton extends StatelessWidget {
  const _PlayBarButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(label, style: IOSText.headline.copyWith(color: accent)),
        ],
      ),
    );
  }
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.albums});

  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Aggiunti di recente'),
        SizedBox(
          height: 214,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: IOS.margin),
            physics: const BouncingScrollPhysics(),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final album = albums[i];
              return GestureDetector(
                onTap: () => pushPage(context, AlbumPage(albumId: album.id)),
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 158,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Artwork(
                        artKey: album.artKey,
                        size: 158,
                        radius: 8,
                        imageSize: 'full',
                      ),
                      const SizedBox(height: 7),
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IOSText.subhead,
                      ),
                      Text(
                        album.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IOSText.subhead
                            .copyWith(color: IOS.labelSecondary),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ShelfPlaceholder extends StatelessWidget {
  const _ShelfPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox(height: 250);
}

/// Lista raggruppata: un unico blocco arrotondato, righe alte 56, separatori
/// che partono dove parte il testo. È la cella standard di iOS.
class _TrackGroup extends ConsumerWidget {
  const _TrackGroup({required this.tracks, required this.accent});

  final List<Track> tracks;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final currentId = player.current?.id;
    const artSize = 44.0;
    const indent = IOS.margin + artSize + 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Brani recenti'),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: IOS.margin),
          decoration: BoxDecoration(
            color: IOS.surface,
            borderRadius: BorderRadius.circular(IOS.radiusCell),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < tracks.length; i++) ...[
                _TrackRow(
                  track: tracks[i],
                  playing: tracks[i].id == currentId,
                  accent: accent,
                  onTap: () => player.playAll(
                    tracks,
                    index: i,
                    label: 'Brani recenti',
                  ),
                ),
                if (i != tracks.length - 1)
                  const IOSSeparator(indent: indent - IOS.margin),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    required this.track,
    required this.playing,
    required this.accent,
    required this.onTap,
  });

  final Track track;
  final bool playing;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 60,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Artwork(artKey: track.artKey, size: 44, radius: 5),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IOSText.body.copyWith(
                      color: playing ? accent : IOS.label,
                    ),
                  ),
                  Text(
                    track.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IOSText.footnote,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(formatDuration(track.duration), style: IOSText.footnote),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(IOS.margin, 24, IOS.margin, 10),
      child: Text(title, style: IOSText.title2),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(IOS.margin, 30, IOS.margin, 30),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: IOSText.footnote,
      ),
    );
  }
}
