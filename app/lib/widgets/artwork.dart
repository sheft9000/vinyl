import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../data/providers.dart';

/// Copertina. Il segnaposto non e' un rettangolo grigio ma una superficie con
/// lo stesso rilievo delle altre: una libreria con qualche album senza
/// immagine non deve sembrare rotta.
class Artwork extends ConsumerWidget {
  const Artwork({
    super.key,
    required this.artKey,
    this.size = 56,
    this.radius = 8,
    this.imageSize = 'thumb',
    this.lift = 0,
  });

  final String? artKey;
  final double size;
  final double radius;
  final String imageSize;
  final double lift;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.watch(apiClientProvider);
    final url = api.artworkUrl(artKey, size: imageSize);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: lift > 0 ? Vinyl.lift(lift) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: url == null
            ? _Placeholder(size: size)
            : CachedNetworkImage(
                imageUrl: url,
                httpHeaders: api.imageHeaders,
                width: size,
                height: size,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 220),
                placeholder: (_, _) => _Placeholder(size: size),
                errorWidget: (_, _, _) => _Placeholder(size: size),
              ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF25252F), Color(0xFF14141A)],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          size: size * 0.36,
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}
