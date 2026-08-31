import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ios.dart';
import '../../core/navigation.dart';
import '../../core/skin.dart';
import '../../player/accent.dart';
import '../../player/player_controller.dart';
import '../../widgets/artwork.dart';
import 'now_playing_page.dart';

/// Mini player e barra delle schede, nelle due varianti in prova.
///
/// Sono la parte che più tradisce la piattaforma: la `NavigationBar` di
/// Material, con la pillola dietro l'icona selezionata, è riconoscibile come
/// Android a colpo d'occhio. iOS non ha né pillola né ombre: solo vetro,
/// un filo di separazione e icone piene quando sono attive.
class BottomChrome extends ConsumerWidget {
  const BottomChrome({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skin = ref.watch(skinProvider);
    return switch (skin) {
      Skin.appleMusic =>
        _AppleChrome(currentIndex: currentIndex, onTap: onTap),
      Skin.liquidGlass =>
        _GlassChrome(currentIndex: currentIndex, onTap: onTap),
    };
  }
}

const _destinations = [
  (CupertinoIcons.house, CupertinoIcons.house_fill, 'Home'),
  (CupertinoIcons.search, CupertinoIcons.search, 'Cerca'),
  (CupertinoIcons.music_albums, CupertinoIcons.music_albums_fill, 'Libreria'),
];

// --------------------------------------------------------------- Apple Music

class _AppleChrome extends ConsumerWidget {
  const _AppleChrome({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    final bottom = MediaQuery.of(context).padding.bottom;

    return IOSBlur(
      sigma: 34,
      saturation: 1.8,
      tint: const Color(0xD9101012),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _AppleMiniPlayer(),
          Container(height: 0.5, color: IOS.separator),
          SizedBox(
            height: IOS.tabBarHeight,
            child: Row(
              children: [
                for (var i = 0; i < _destinations.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            i == currentIndex
                                ? _destinations[i].$2
                                : _destinations[i].$1,
                            size: 25,
                            color: i == currentIndex
                                ? accent
                                : IOS.labelSecondary,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _destinations[i].$3,
                            style: IOSText.tabLabel.copyWith(
                              color: i == currentIndex
                                  ? accent
                                  : IOS.labelSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: bottom),
        ],
      ),
    );
  }
}

/// Il mini player di Apple Music: copertina, titolo, play e avanti.
/// Nessuna barra di avanzamento, nessun sottotitolo. È più povero di quello
/// di Spotify, ed è esattamente per questo che sembra iOS.
class _AppleMiniPlayer extends ConsumerWidget {
  const _AppleMiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.current;
    if (track == null) return const SizedBox(width: double.infinity);

    return GestureDetector(
      onTap: () => pushFullScreen(context, const NowPlayingPage()),
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -200) {
          pushFullScreen(context, const NowPlayingPage());
        }
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Hero(
              tag: 'now-playing-art',
              child: Artwork(artKey: track.artKey, size: 40, radius: 5),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                track.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: IOSText.subhead.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              onPressed: player.playPause,
              child: Icon(
                player.isPlaying
                    ? CupertinoIcons.pause_fill
                    : CupertinoIcons.play_fill,
                size: 25,
                color: IOS.label,
              ),
            ),
            CupertinoButton(
              padding: const EdgeInsets.only(right: 16, left: 4),
              minimumSize: Size.zero,
              onPressed: player.next,
              child: const Icon(
                CupertinoIcons.forward_fill,
                size: 25,
                color: IOS.label,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------- Liquid Glass

class _GlassChrome extends ConsumerWidget {
  const _GlassChrome({required this.currentIndex, required this.onTap});

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(14, 0, 14, bottom > 0 ? bottom : 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _GlassMiniPlayer(),
          IOSBlur(
            sigma: 30,
            saturation: 1.9,
            tint: const Color(0x2BFFFFFF),
            borderRadius: BorderRadius.circular(28),
            specular: true,
            shadow: true,
            child: SizedBox(
              height: 58,
              child: Row(
                children: [
                  for (var i = 0; i < _destinations.length; i++)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              i == currentIndex
                                  ? _destinations[i].$2
                                  : _destinations[i].$1,
                              size: 23,
                              color: i == currentIndex
                                  ? IOS.label
                                  : IOS.labelSecondary,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _destinations[i].$3,
                              style: IOSText.tabLabel.copyWith(
                                color: i == currentIndex
                                    ? IOS.label
                                    : IOS.labelSecondary,
                                fontWeight: i == currentIndex
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassMiniPlayer extends ConsumerWidget {
  const _GlassMiniPlayer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final accent = ref.watch(accentProvider);
    final track = player.current;
    if (track == null) return const SizedBox(width: double.infinity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => pushFullScreen(context, const NowPlayingPage()),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) {
            pushFullScreen(context, const NowPlayingPage());
          }
        },
        behavior: HitTestBehavior.opaque,
        child: IOSBlur(
          sigma: 28,
          saturation: 1.9,
          tint: const Color(0x2BFFFFFF),
          borderRadius: BorderRadius.circular(22),
          specular: true,
          shadow: true,
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                const SizedBox(width: 9),
                Hero(
                  tag: 'now-playing-art',
                  child: Artwork(artKey: track.artKey, size: 44, radius: 14),
                ),
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
                        style: IOSText.subhead
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        track.artistName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: IOSText.caption1,
                      ),
                    ],
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  minimumSize: Size.zero,
                  onPressed: player.playPause,
                  child: Icon(
                    player.isPlaying
                        ? CupertinoIcons.pause_fill
                        : CupertinoIcons.play_fill,
                    size: 24,
                    color: accent,
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.only(right: 14, left: 2),
                  minimumSize: Size.zero,
                  onPressed: player.next,
                  child: const Icon(
                    CupertinoIcons.forward_fill,
                    size: 22,
                    color: IOS.label,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
