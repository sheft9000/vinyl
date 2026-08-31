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

/// Home in stile "Liquid Glass".
///
/// L'idea opposta alla precedente: niente barre piene, niente blocchi opachi.
/// Il colore dell'album in ascolto tinge il fondo, e ogni contenitore è una
/// lastra di vetro che lascia passare quel colore. I controlli galleggiano
/// sopra il contenuto invece di delimitarlo.
class HomeGlass extends ConsumerWidget {
  const HomeGlass({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentProvider);
    final albums = ref.watch(recentAlbumsProvider);
    final tracks = ref.watch(recentTracksProvider);
    final top = MediaQuery.of(context).padding.top;

    return Stack(
      children: [
        _Aurora(accent: accent),
        CustomScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(child: SizedBox(height: top + 14)),
            SliverToBoxAdapter(child: _FloatingHeader(accent: accent)),
            const SliverToBoxAdapter(child: SkinSwitcher()),
            SliverToBoxAdapter(child: _GlassActions(accent: accent)),
            SliverToBoxAdapter(
              child: albums.when(
                data: (items) =>
                    items.isEmpty ? const SizedBox.shrink() : _Shelf(albums: items),
                loading: () => const SizedBox(height: 250),
                error: (e, _) => _InlineError(message: '$e'),
              ),
            ),
            SliverToBoxAdapter(
              child: tracks.when(
                data: (items) => items.isEmpty
                    ? const SizedBox.shrink()
                    : _GlassTrackPanel(tracks: items, accent: accent),
                loading: () => const SizedBox(height: 120),
                error: (e, _) => _InlineError(message: '$e'),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 190)),
          ],
        ),
      ],
    );
  }
}

/// Due macchie di colore sfocate, prese dalla copertina in ascolto.
/// È la sorgente luminosa di tutta la schermata: senza qualcosa di colorato
/// sotto, il vetro non ha niente da rifrangere e sembra solo grigio.
class _Aurora extends StatelessWidget {
  const _Aurora({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        color: IOS.background,
        child: Stack(
          children: [
            Positioned(
              top: -190,
              left: -150,
              child: _Blob(color: accent, size: 620, opacity: 0.85),
            ),
            Positioned(
              top: 40,
              right: -210,
              child: _Blob(color: _shifted(accent, 46), size: 560, opacity: 0.62),
            ),
            Positioned(
              bottom: -120,
              left: -90,
              child: _Blob(color: _shifted(accent, -52), size: 520, opacity: 0.40),
            ),
          ],
        ),
      ),
    );
  }
}

Color _shifted(Color base, double degrees) {
  final hsl = HSLColor.fromColor(base);
  return hsl.withHue((hsl.hue + degrees) % 360).toColor();
}

class _Blob extends StatelessWidget {
  const _Blob({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  const _FloatingHeader({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(IOS.margin, 0, IOS.margin, 12),
      child: Row(
        children: [
          Expanded(child: Text('Ascolta ora', style: IOSText.largeTitle)),
          IOSBlur(
            sigma: 20,
            tint: const Color(0x33FFFFFF),
            saturation: 1.5,
            borderRadius: BorderRadius.circular(21),
            specular: true,
            child: SizedBox(
              width: 42,
              height: 42,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => pushPage(context, const SettingsPage()),
                child: const Icon(
                  CupertinoIcons.gear,
                  color: IOS.label,
                  size: 21,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassActions extends ConsumerWidget {
  const _GlassActions({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.read(playerProvider);
    final stats = ref.watch(statsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(IOS.margin, 2, IOS.margin, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _GlassButton(
                  icon: CupertinoIcons.play_fill,
                  label: 'Riproduci',
                  filled: true,
                  accent: accent,
                  onPressed: () async {
                    final list = await ref
                        .read(apiClientProvider)
                        .tracks(sort: 'added', limit: 200);
                    await player.playAll(list.items, label: 'La tua libreria');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GlassButton(
                  icon: CupertinoIcons.shuffle,
                  label: 'Casuale',
                  filled: false,
                  accent: accent,
                  onPressed: player.shuffleLibrary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          stats.maybeWhen(
            data: (s) => Text(
              '${plural(s.tracks, 'brano', 'brani')} · '
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

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.label,
    required this.filled,
    required this.accent,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final Color accent;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IOSBlur(
      sigma: 24,
      saturation: 1.8,
      tint: filled
          ? accent.withValues(alpha: 0.55)
          : const Color(0x24FFFFFF),
      borderRadius: BorderRadius.circular(16),
      specular: true,
      shadow: true,
      child: SizedBox(
        height: 52,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: IOS.label),
              const SizedBox(width: 8),
              Text(label, style: IOSText.headline),
            ],
          ),
        ),
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
        const Padding(
          padding: EdgeInsets.fromLTRB(IOS.margin, 22, IOS.margin, 12),
          child: Text('Aggiunti di recente', style: IOSText.title3),
        ),
        SizedBox(
          height: 196,
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: 168,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Artwork(
                          artKey: album.artKey,
                          size: 196,
                          radius: 0,
                          imageSize: 'full',
                        ),
                        // La targhetta di vetro sopra la copertina: il testo
                        // resta leggibile su qualunque immagine, senza dover
                        // scurire tutta la copertina.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: IOSBlur(
                            sigma: 18,
                            saturation: 1.6,
                            tint: const Color(0x66000000),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    album.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: IOSText.subhead.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    album.artistName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: IOSText.caption1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _GlassTrackPanel extends ConsumerWidget {
  const _GlassTrackPanel({required this.tracks, required this.accent});

  final List<Track> tracks;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final currentId = player.current?.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(IOS.margin, 22, IOS.margin, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Brani recenti', style: IOSText.title3),
          ),
          IOSBlur(
            sigma: 26,
            saturation: 1.7,
            tint: const Color(0x1FFFFFFF),
            borderRadius: BorderRadius.circular(20),
            specular: true,
            child: DecoratedBox(
              decoration: const BoxDecoration(),
              child: Column(
                children: [
                  for (var i = 0; i < tracks.length; i++) ...[
                    _GlassRow(
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
                      Padding(
                        padding: const EdgeInsets.only(left: 68),
                        child: Container(
                          height: 0.5,
                          color: const Color(0x1FFFFFFF),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassRow extends StatelessWidget {
  const _GlassRow({
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
        height: 62,
        child: Row(
          children: [
            const SizedBox(width: 12),
            Artwork(artKey: track.artKey, size: 44, radius: 9),
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
                      fontWeight: FontWeight.w500,
                      color: playing ? accent : IOS.label,
                    ),
                  ),
                  Text(
                    track.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: IOSText.caption1,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(formatDuration(track.duration), style: IOSText.caption1),
            const SizedBox(width: 14),
          ],
        ),
      ),
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
