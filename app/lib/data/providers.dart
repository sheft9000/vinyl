import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'models.dart';
import 'settings.dart';

/// Il client si ricostruisce da solo quando cambiano indirizzo o token:
/// tutto cio' che dipende da lui si aggiorna di conseguenza.
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(ref.watch(settingsProvider)),
);

final statsProvider = FutureProvider.autoDispose<LibraryStats>(
  (ref) => ref.watch(apiClientProvider).stats(),
);

final recentAlbumsProvider = FutureProvider.autoDispose<List<Album>>(
  (ref) async =>
      (await ref.watch(apiClientProvider).albums(sort: 'recent', limit: 20))
          .items,
);

final recentTracksProvider = FutureProvider.autoDispose<List<Track>>(
  (ref) async =>
      (await ref.watch(apiClientProvider).tracks(sort: 'added', limit: 30))
          .items,
);

final allAlbumsProvider = FutureProvider.autoDispose<List<Album>>(
  (ref) async =>
      (await ref.watch(apiClientProvider).albums(sort: 'artist', limit: 500))
          .items,
);

final allArtistsProvider = FutureProvider.autoDispose<List<Artist>>(
  (ref) async => (await ref.watch(apiClientProvider).artists(limit: 500)).items,
);

final genresProvider = FutureProvider.autoDispose<List<Genre>>(
  (ref) => ref.watch(apiClientProvider).genres(),
);

/// Un album con i suoi brani: le due chiamate partono insieme.
class AlbumDetail {
  const AlbumDetail(this.album, this.tracks);
  final Album album;
  final List<Track> tracks;
}

final albumDetailProvider =
    FutureProvider.autoDispose.family<AlbumDetail, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final results =
      await Future.wait([api.album(id), api.albumTracks(id)]);
  return AlbumDetail(results[0] as Album, results[1] as List<Track>);
});

class ArtistDetail {
  const ArtistDetail(this.artist, this.albums, this.topTracks);
  final Artist artist;
  final List<Album> albums;
  final List<Track> topTracks;
}

final artistDetailProvider =
    FutureProvider.autoDispose.family<ArtistDetail, int>((ref, id) async {
  final api = ref.watch(apiClientProvider);
  final results = await Future.wait([
    api.artist(id),
    api.artistAlbums(id),
    api.tracks(artistId: id, sort: 'title', limit: 100),
  ]);
  return ArtistDetail(
    results[0] as Artist,
    results[1] as List<Album>,
    (results[2] as PageResult<Track>).items,
  );
});

final genreTracksProvider =
    FutureProvider.autoDispose.family<List<Track>, String>((ref, genre) async =>
        (await ref
                .watch(apiClientProvider)
                .tracks(genre: genre, sort: 'title', limit: 500))
            .items);

/// La query e' aggiornata dalla pagina di ricerca dopo una pausa di battitura,
/// cosi' non partono richieste a ogni lettera.
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider =
    FutureProvider.autoDispose<SearchResults>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return const SearchResults(artists: [], albums: [], tracks: []);
  }
  return ref.watch(apiClientProvider).search(query);
});
