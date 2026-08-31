// Modelli della libreria. Rispecchiano uno a uno le risposte dell'API:
// se cambia il server, si rompe la compilazione qui e non a runtime.

int _int(dynamic v, [int fallback = 0]) =>
    v is int ? v : (v is num ? v.toInt() : (int.tryParse('$v') ?? fallback));

int? _intOrNull(dynamic v) => v == null ? null : _int(v);

String _str(dynamic v, [String fallback = '']) => v == null ? fallback : '$v';

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.albumCount = 0,
    this.trackCount = 0,
    this.artKey,
  });

  final int id;
  final String name;
  final int albumCount;
  final int trackCount;
  final String? artKey;

  factory Artist.fromJson(Map<String, dynamic> json) => Artist(
        id: _int(json['id']),
        name: _str(json['name'], 'Sconosciuto'),
        albumCount: _int(json['album_count']),
        trackCount: _int(json['track_count']),
        artKey: json['art_key'] as String?,
      );
}

class Album {
  const Album({
    required this.id,
    required this.title,
    required this.artistId,
    this.artistName = '',
    this.year,
    this.artKey,
    this.trackCount = 0,
    this.durationMs = 0,
  });

  final int id;
  final String title;
  final int artistId;
  final String artistName;
  final int? year;
  final String? artKey;
  final int trackCount;
  final int durationMs;

  factory Album.fromJson(Map<String, dynamic> json) => Album(
        id: _int(json['id']),
        title: _str(json['title'], 'Senza titolo'),
        artistId: _int(json['artist_id']),
        artistName: _str(json['artist_name']),
        year: _intOrNull(json['year']),
        artKey: json['art_key'] as String?,
        trackCount: _int(json['track_count']),
        durationMs: _int(json['duration_ms']),
      );
}

class Track {
  const Track({
    required this.id,
    required this.title,
    this.artistId,
    this.artistName = '',
    this.albumId,
    this.albumTitle = '',
    this.trackNo,
    this.discNo,
    this.year,
    this.genre,
    this.durationMs = 0,
    this.ext = '',
    this.artKey,
  });

  final int id;
  final String title;
  final int? artistId;
  final String artistName;
  final int? albumId;
  final String albumTitle;
  final int? trackNo;
  final int? discNo;
  final int? year;
  final String? genre;
  final int durationMs;
  final String ext;
  final String? artKey;

  Duration get duration => Duration(milliseconds: durationMs);

  /// Riga secondaria mostrata sotto al titolo, ovunque nell'app.
  String get subtitle =>
      [artistName, albumTitle].where((s) => s.isNotEmpty).join(' — ');

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        id: _int(json['id']),
        title: _str(json['title'], 'Senza titolo'),
        artistId: _intOrNull(json['artist_id']),
        artistName: _str(json['artist_name']),
        albumId: _intOrNull(json['album_id']),
        albumTitle: _str(json['album_title']),
        trackNo: _intOrNull(json['track_no']),
        discNo: _intOrNull(json['disc_no']),
        year: _intOrNull(json['year']),
        genre: json['genre'] as String?,
        durationMs: _int(json['duration_ms']),
        ext: _str(json['ext']),
        artKey: json['art_key'] as String?,
      );
}

class Genre {
  const Genre({required this.name, required this.trackCount});

  final String name;
  final int trackCount;

  factory Genre.fromJson(Map<String, dynamic> json) => Genre(
        name: _str(json['name'], 'Senza genere'),
        trackCount: _int(json['track_count']),
      );
}

class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.offset,
    required this.limit,
  });

  final List<T> items;
  final int total;
  final int offset;
  final int limit;

  bool get hasMore => offset + items.length < total;

  factory PageResult.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parse,
  ) =>
      PageResult(
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => parse(e as Map<String, dynamic>))
            .toList(),
        total: _int(json['total']),
        offset: _int(json['offset']),
        limit: _int(json['limit'], 100),
      );
}

class SearchResults {
  const SearchResults({
    required this.artists,
    required this.albums,
    required this.tracks,
  });

  final List<Artist> artists;
  final List<Album> albums;
  final List<Track> tracks;

  bool get isEmpty => artists.isEmpty && albums.isEmpty && tracks.isEmpty;

  static List<T> _list<T>(dynamic v, T Function(Map<String, dynamic>) parse) =>
      (v as List<dynamic>? ?? const [])
          .map((e) => parse(e as Map<String, dynamic>))
          .toList();

  factory SearchResults.fromJson(Map<String, dynamic> json) => SearchResults(
        artists: _list(json['artists'], Artist.fromJson),
        albums: _list(json['albums'], Album.fromJson),
        tracks: _list(json['tracks'], Track.fromJson),
      );
}

class LibraryStats {
  const LibraryStats({
    required this.artists,
    required this.albums,
    required this.tracks,
    required this.totalDurationMs,
  });

  final int artists;
  final int albums;
  final int tracks;
  final int totalDurationMs;

  factory LibraryStats.fromJson(Map<String, dynamic> json) => LibraryStats(
        artists: _int(json['artists']),
        albums: _int(json['albums']),
        tracks: _int(json['tracks']),
        totalDurationMs: _int(json['total_duration_ms']),
      );
}
