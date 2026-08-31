import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palette_generator/palette_generator.dart';

import '../core/theme.dart';
import '../data/api_client.dart';
import '../data/models.dart';
import '../data/providers.dart';
import 'player_controller.dart';

/// Estrae il colore dominante dalla copertina in ascolto e lo usa come accento
/// di tutta l'interfaccia.
///
/// I colori delle copertine sono pensati per la stampa, non per un tema scuro:
/// quasi sempre sono troppo cupi o troppo slavati per essere leggibili su
/// nero. Per questo il colore estratto viene sempre riportato dentro una
/// finestra di saturazione e luminosita' prima di essere usato.
class AccentNotifier extends StateNotifier<Color> {
  AccentNotifier(this._api) : super(Vinyl.defaultAccent);

  final ApiClient _api;
  final Map<String, Color> _cache = {};
  String? _wanted;

  Future<void> updateFor(String? artKey) async {
    _wanted = artKey;

    if (artKey == null || artKey.isEmpty) {
      state = Vinyl.defaultAccent;
      return;
    }

    final cached = _cache[artKey];
    if (cached != null) {
      state = cached;
      return;
    }

    final url = _api.artworkUrl(artKey, size: 'thumb');
    if (url == null) return;

    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url, headers: _api.imageHeaders),
        size: const Size(100, 100),
        maximumColorCount: 12,
      );
      final color = _readable(_pick(palette));
      _cache[artKey] = color;
      // Nel frattempo il brano potrebbe essere gia' cambiato.
      if (_wanted == artKey) state = color;
    } catch (_) {
      if (_wanted == artKey) state = Vinyl.defaultAccent;
    }
  }

  Color _pick(PaletteGenerator palette) =>
      palette.vibrantColor?.color ??
      palette.lightVibrantColor?.color ??
      palette.dominantColor?.color ??
      palette.mutedColor?.color ??
      Vinyl.defaultAccent;

  Color _readable(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withSaturation(hsl.saturation.clamp(0.45, 0.92))
        .withLightness(hsl.lightness.clamp(0.48, 0.68))
        .toColor();
  }
}

final accentProvider = StateNotifierProvider<AccentNotifier, Color>((ref) {
  final notifier = AccentNotifier(ref.watch(apiClientProvider));
  ref.listen<Track?>(
    currentTrackProvider,
    (_, track) => notifier.updateFor(track?.artKey),
    fireImmediately: true,
  );
  return notifier;
});
