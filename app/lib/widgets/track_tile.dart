import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../player/accent.dart';
import '../player/player_controller.dart';
import 'artwork.dart';
import 'playing_bars.dart';

class TrackTile extends ConsumerWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.onTap,
    this.number,
    this.showArtwork = true,
    this.showAlbum = true,
  });

  final Track track;
  final VoidCallback onTap;

  /// Numero di traccia, mostrato al posto della copertina dentro un album.
  final int? number;
  final bool showArtwork;
  final bool showAlbum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final accent = ref.watch(accentProvider);
    final isCurrent = player.current?.id == track.id;

    final subtitle = showAlbum
        ? track.subtitle
        : (track.artistName.isEmpty ? '' : track.artistName);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Vinyl.gutter,
          vertical: 8,
        ),
        child: Row(
          children: [
            SizedBox(
              width: showArtwork ? 48 : 30,
              height: 48,
              child: Center(
                child: isCurrent
                    ? PlayingBars(color: accent, playing: player.isPlaying)
                    : showArtwork
                        ? Artwork(artKey: track.artKey, size: 48, radius: 7)
                        : Text(
                            '${number ?? ''}',
                            style: const TextStyle(
                              color: Vinyl.textDim,
                              fontSize: 14,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? accent : Vinyl.text,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Vinyl.textDim,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatDuration(track.duration),
              style: const TextStyle(
                color: Vinyl.textDim,
                fontSize: 12.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
