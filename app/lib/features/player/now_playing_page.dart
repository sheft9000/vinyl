import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/format.dart';
import '../../core/glass.dart';
import '../../core/theme.dart';
import '../../player/accent.dart';
import '../../player/player_controller.dart';
import '../../widgets/artwork.dart';

class NowPlayingPage extends ConsumerStatefulWidget {
  const NowPlayingPage({super.key});

  @override
  ConsumerState<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends ConsumerState<NowPlayingPage> {
  double _dragOffset = 0;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);
    final accent = ref.watch(accentProvider);
    final track = player.current;

    if (track == null) {
      // La coda si e' svuotata mentre eravamo qui sopra.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).maybePop();
      });
      return const SizedBox.shrink();
    }

    final media = MediaQuery.of(context);
    final artSize = (media.size.width - 88).clamp(180.0, 340.0);

    return Transform.translate(
      offset: Offset(0, _dragOffset),
      child: Scaffold(
        backgroundColor: Vinyl.bg,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.lerp(accent, Vinyl.bg, 0.35)!,
                Color.lerp(accent, Vinyl.bg, 0.82)!,
                Vinyl.bg,
              ],
              stops: const [0, 0.5, 1],
            ),
          ),
          child: SafeArea(
            child: GestureDetector(
              // Trascinare verso il basso chiude, come su iOS.
              onVerticalDragUpdate: (d) => setState(
                () => _dragOffset = (_dragOffset + d.delta.dy).clamp(0.0, 600.0),
              ),
              onVerticalDragEnd: (d) {
                if (_dragOffset > 120 || (d.primaryVelocity ?? 0) > 700) {
                  Navigator.of(context).maybePop();
                } else {
                  setState(() => _dragOffset = 0);
                }
              },
              child: Column(
                children: [
                  _Header(label: player.queueLabel),
                  const Spacer(flex: 2),
                  Hero(
                    tag: 'now-playing-art',
                    child: Artwork(
                      artKey: track.artKey,
                      size: artSize,
                      radius: 16,
                      imageSize: 'full',
                      lift: 1.6,
                    ),
                  ),
                  const Spacer(flex: 2),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: Vinyl.gutter + 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          track.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Vinyl.textDim,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const _Scrubber(),
                        const SizedBox(height: 8),
                        _Controls(accent: accent),
                        const SizedBox(height: 10),
                        _BottomRow(accent: accent),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
            color: Vinyl.text,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'IN RIPRODUZIONE',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                    color: Vinyl.textDim.withValues(alpha: 0.9),
                  ),
                ),
                if (label.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _Scrubber extends ConsumerStatefulWidget {
  const _Scrubber();

  @override
  ConsumerState<_Scrubber> createState() => _ScrubberState();
}

class _ScrubberState extends ConsumerState<_Scrubber> {
  /// Mentre trascini comanda il dito, non lo stream: altrimenti la manopola
  /// tornerebbe indietro a ogni aggiornamento della posizione.
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final player = ref.watch(playerProvider);

    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (context, snapshot) {
        final duration = player.player.duration ?? Duration.zero;
        final position = snapshot.data ?? Duration.zero;
        final maxMs = duration.inMilliseconds.toDouble();
        final currentMs =
            _dragValue ?? position.inMilliseconds.toDouble().clamp(0, maxMs);

        return Column(
          children: [
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackShape: const RoundedRectSliderTrackShape(),
              ),
              child: Slider(
                min: 0,
                max: maxMs <= 0 ? 1 : maxMs,
                value: maxMs <= 0 ? 0 : currentMs.clamp(0, maxMs),
                onChanged: maxMs <= 0
                    ? null
                    : (v) => setState(() => _dragValue = v),
                onChangeEnd: (v) {
                  player.seek(Duration(milliseconds: v.round()));
                  setState(() => _dragValue = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDuration(
                        Duration(milliseconds: currentMs.round())),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Vinyl.textDim,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    formatDuration(duration),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Vinyl.textDim,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          iconSize: 22,
          icon: const Icon(Icons.shuffle_rounded),
          color: player.shuffleEnabled ? accent : Vinyl.textDim,
          onPressed: player.toggleShuffle,
        ),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_previous_rounded),
          color: Vinyl.text,
          onPressed: player.previous,
        ),
        _PlayButton(accent: accent),
        IconButton(
          iconSize: 40,
          icon: const Icon(Icons.skip_next_rounded),
          color: Vinyl.text,
          onPressed: player.next,
        ),
        IconButton(
          iconSize: 22,
          icon: Icon(
            player.repeatOne
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
          ),
          color: player.loopMode == LoopMode.off ? Vinyl.textDim : accent,
          onPressed: player.cycleRepeat,
        ),
      ],
    );
  }
}

class _PlayButton extends ConsumerWidget {
  const _PlayButton({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);

    return StreamBuilder<PlayerState>(
      stream: player.player.playerStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final buffering = state?.processingState == ProcessingState.loading ||
            state?.processingState == ProcessingState.buffering;

        return GestureDetector(
          onTap: player.playPause,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.45),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: buffering
                ? const Padding(
                    padding: EdgeInsets.all(22),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.black87,
                    ),
                  )
                : Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 40,
                    color: Colors.black,
                  ),
          ),
        );
      },
    );
  }
}

class _BottomRow extends ConsumerWidget {
  const _BottomRow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (_) => const QueueSheet(),
          ),
          icon: const Icon(Icons.queue_music_rounded, size: 20),
          label: const Text('Coda'),
          style: TextButton.styleFrom(foregroundColor: Vinyl.textDim),
        ),
      ],
    );
  }
}

class QueueSheet extends ConsumerWidget {
  const QueueSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final accent = ref.watch(accentProvider);
    final tracks = player.queue;
    final currentId = player.current?.id;

    return GlassSurface(
      blur: 34,
      tint: 0.82,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(Vinyl.radiusSheet),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(Vinyl.gutter, 16, Vinyl.gutter, 6),
              child: Row(
                children: [
                  Text(
                    'In coda',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const Spacer(),
                  Text(
                    '${tracks.length} brani',
                    style: const TextStyle(
                        color: Vinyl.textDim, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: tracks.length,
                itemBuilder: (context, i) {
                  final track = tracks[i];
                  final isCurrent = track.id == currentId;
                  return ListTile(
                    dense: true,
                    leading: Artwork(
                        artKey: track.artKey, size: 40, radius: 6),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isCurrent ? accent : Vinyl.text,
                      ),
                    ),
                    subtitle: Text(
                      track.artistName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Text(
                      formatDuration(track.duration),
                      style: const TextStyle(
                          fontSize: 12, color: Vinyl.textDim),
                    ),
                    onTap: () => player.jumpTo(i),
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
