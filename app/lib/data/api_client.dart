import 'package:dio/dio.dart';

import 'models.dart';
import 'settings.dart';

/// Errore parlante: qualunque cosa vada storta, l'utente deve leggere una frase
/// che gli dica cosa fare, non uno stack trace.
class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  /// Dio valida il baseUrl gia' nel costruttore e rifiuta un indirizzo
  /// relativo. Al primo avvio il server non e' ancora configurato, quindi
  /// serve un segnaposto: `.invalid` e' un dominio riservato che non risolve
  /// mai, e comunque nessuna richiesta parte finche' [ServerSettings] non e'
  /// completo.
  static String _baseUrlFor(ServerSettings settings) {
    final base = settings.normalizedBaseUrl;
    return base.isEmpty ? 'http://non-configurato.invalid/api/v1' : '$base/api/v1';
  }

  ApiClient(this.settings)
      : _dio = Dio(
          BaseOptions(
            baseUrl: _baseUrlFor(settings),
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Authorization': 'Bearer ${settings.token}'},
            responseType: ResponseType.json,
          ),
        );

  final ServerSettings settings;
  final Dio _dio;

  /// Header per le immagini: `cached_network_image` sa mandarli, quindi il
  /// token non finisce mai nell'URL di una copertina.
  Map<String, String> get imageHeaders => {
        'Authorization': 'Bearer ${settings.token}',
      };

  /// L'audio invece passa il token in query string: il player di sistema
  /// (AVPlayer su iOS, ExoPlayer su Android) apre l'URL da solo e non sempre
  /// propaga gli header attraverso i redirect e le richieste Range.
  Uri streamUri(int trackId) => Uri.parse(
        '${settings.normalizedBaseUrl}/api/v1/tracks/$trackId/stream'
        '?token=${Uri.encodeComponent(settings.token)}',
      );

  String? artworkUrl(String? artKey, {String size = 'thumb'}) {
    if (artKey == null || artKey.isEmpty) return null;
    return '${settings.normalizedBaseUrl}/api/v1/artwork/$artKey?size=$size';
  }

  /// Copertina per la schermata di blocco e il Centro di Controllo: la scarica
  /// il sistema operativo, che non conosce i nostri header, quindi qui il
  /// token deve stare nell'URL.
  Uri? systemArtworkUri(String? artKey, {String size = 'full'}) {
    if (artKey == null || artKey.isEmpty) return null;
    return Uri.parse(
      '${settings.normalizedBaseUrl}/api/v1/artwork/$artKey'
      '?size=$size&token=${Uri.encodeComponent(settings.token)}',
    );
  }

  void _requireConfigured() {
    if (!settings.isConfigured) {
      throw ApiException(
        'Server non ancora configurato: apri le impostazioni e inserisci '
        "l'indirizzo e il token.",
      );
    }
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    _requireConfigured();
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: query);
      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      return {'items': data};
    } on DioException catch (e) {
      throw ApiException(_describe(e));
    }
  }

  Future<List<dynamic>> _getList(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    _requireConfigured();
    try {
      final res = await _dio.get<dynamic>(path, queryParameters: query);
      return (res.data as List<dynamic>?) ?? const [];
    } on DioException catch (e) {
      throw ApiException(_describe(e));
    }
  }

  String _describe(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return 'Server irraggiungibile a ${settings.normalizedBaseUrl}.\n'
            'Controlla che sia acceso e che il telefono sia sulla stessa rete.';
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'Il server non ha risposto in tempo.';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401) return 'Token rifiutato: controllalo nelle impostazioni.';
        if (code == 403) return 'Questo token non ha i permessi necessari.';
        if (code == 404) return 'Non trovato sul server.';
        return 'Il server ha risposto $code.';
      default:
        return 'Errore di rete: ${e.message ?? e.type.name}';
    }
  }

  // ------------------------------------------------------------------ libreria

  Future<PageResult<Album>> albums({
    String sort = 'title',
    int? artistId,
    int offset = 0,
    int limit = 100,
  }) async {
    final json = await _get('/albums', query: {
      'sort': sort,
      'artist_id': ?artistId,
      'offset': offset,
      'limit': limit,
    });
    return PageResult.fromJson(json, Album.fromJson);
  }

  Future<Album> album(int id) async =>
      Album.fromJson(await _get('/albums/$id'));

  Future<List<Track>> albumTracks(int id) async {
    final json = await _get('/albums/$id/tracks');
    return PageResult.fromJson(json, Track.fromJson).items;
  }

  Future<PageResult<Artist>> artists({int offset = 0, int limit = 200}) async {
    final json = await _get('/artists', query: {
      'offset': offset,
      'limit': limit,
    });
    return PageResult.fromJson(json, Artist.fromJson);
  }

  Future<Artist> artist(int id) async =>
      Artist.fromJson(await _get('/artists/$id'));

  Future<List<Album>> artistAlbums(int id) async {
    final json = await _get('/artists/$id/albums');
    return PageResult.fromJson(json, Album.fromJson).items;
  }

  Future<PageResult<Track>> tracks({
    String sort = 'added',
    int? artistId,
    String? genre,
    int offset = 0,
    int limit = 100,
  }) async {
    final json = await _get('/tracks', query: {
      'sort': sort,
      'artist_id': ?artistId,
      'genre': ?genre,
      'offset': offset,
      'limit': limit,
    });
    return PageResult.fromJson(json, Track.fromJson);
  }

  Future<List<Track>> randomTracks({int limit = 200}) async {
    final list = await _getList('/tracks/random', query: {'limit': limit});
    return list
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Genre>> genres() async {
    final list = await _getList('/genres');
    return list
        .map((e) => Genre.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SearchResults> search(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) {
      return const SearchResults(artists: [], albums: [], tracks: []);
    }
    final json = await _get('/search', query: {'q': query, 'limit': limit});
    return SearchResults.fromJson(json);
  }

  Future<LibraryStats> stats() async =>
      LibraryStats.fromJson(await _get('/stats'));

  /// Usata dalla schermata impostazioni per dire subito se la configurazione va.
  Future<LibraryStats> testConnection() => stats();
}
