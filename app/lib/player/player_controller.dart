import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../data/api_client.dart';
import '../data/models.dart';
import '../data/providers.dart';

/// Tutta la riproduzione passa di qui. Le schermate non toccano mai
/// direttamente `AudioPlayer`: chiedono a questo controller di suonare una
/// lista, e ascoltano cosa sta succedendo.
class PlayerController extends ChangeNotifier {
  PlayerController(this._api) {
    _subs.add(_player.currentIndexStream.listen((_) => notifyListeners()));
    _subs.add(_player.playerStateStream.listen((_) => notifyListeners()));
    _subs.add(_player.shuffleModeEnabledStream.listen((_) => notifyListeners()));
    _subs.add(_player.loopModeStream.listen((_) => notifyListeners()));
    _subs.add(_player.sequenceStateStream.listen((_) => notifyListeners()));
  }

  final ApiClient _api;
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  List<Track> _queue = const [];
  String _queueLabel = '';
  Object? _lastError;

  AudioPlayer get player => _player;
  List<Track> get queue => _queue;
  String get queueLabel => _queueLabel;
  Object? get lastError => _lastError;

  bool get hasQueue => _queue.isNotEmpty;
  bool get isPlaying => _player.playing;
  bool get shuffleEnabled => _player.shuffleModeEnabled;
  bool get repeatOne => _player.loopMode == LoopMode.one;

  int? get currentIndex => _player.currentIndex;

  Track? get current {
    final i = _player.currentIndex;
    if (i == null || i < 0 || i >= _queue.length) return null;
    return _queue[i];
  }

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  /// L'ordine in cui i brani verranno effettivamente suonati, che con lo
  /// shuffle attivo non e' quello della lista.
  List<Track> get effectiveQueue {
    final order = _player.shuffleIndices;
    if (!_player.shuffleModeEnabled) return _queue;
    return [
      for (final i in order)
        if (i >= 0 && i < _queue.length) _queue[i]
    ];
  }

  AudioSource _sourceFor(Track track) => AudioSource.uri(
        _api.streamUri(track.id),
        tag: MediaItem(
          id: track.id.toString(),
          title: track.title,
          artist: track.artistName.isEmpty ? null : track.artistName,
          album: track.albumTitle.isEmpty ? null : track.albumTitle,
          duration: track.durationMs > 0 ? track.duration : null,
          artUri: _api.systemArtworkUri(track.artKey),
        ),
      );

  Future<void> playAll(
    List<Track> tracks, {
    int index = 0,
    String label = '',
    bool shuffle = false,
  }) async {
    if (tracks.isEmpty) return;
    _queue = List.unmodifiable(tracks);
    _queueLabel = label;
    _lastError = null;
    notifyListeners();

    try {
      await _player.setShuffleModeEnabled(shuffle);
      await _player.setAudioSources(
        tracks.map(_sourceFor).toList(),
        initialIndex: index.clamp(0, tracks.length - 1),
        initialPosition: Duration.zero,
      );
      if (shuffle) await _player.shuffle();
      await _player.play();
    } catch (e) {
      _lastError = e;
      notifyListeners();
    }
  }

  /// Shuffle di tutta la libreria: la coda mescolata la prepara il server,
  /// cosi' non serve scaricare l'elenco completo dei brani sul telefono.
  Future<void> shuffleLibrary() async {
    try {
      final tracks = await _api.randomTracks(limit: 200);
      await playAll(tracks, label: 'Shuffle della libreria');
    } catch (e) {
      _lastError = e;
      notifyListeners();
    }
  }

  Future<void> playPause() =>
      _player.playing ? _player.pause() : _player.play();

  Future<void> next() => _player.seekToNext();

  /// Come su Spotify: entro i primi secondi torna indietro, dopo ricomincia.
  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 4)) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  Future<void> seek(Duration position) => _player.seek(position);

  Future<void> jumpTo(int index) async {
    if (index < 0 || index >= _queue.length) return;
    await _player.seek(Duration.zero, index: index);
    await _player.play();
  }

  Future<void> toggleShuffle() async {
    final enable = !_player.shuffleModeEnabled;
    if (enable) await _player.shuffle();
    await _player.setShuffleModeEnabled(enable);
  }

  Future<void> cycleRepeat() async {
    final next = switch (_player.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _player.setLoopMode(next);
  }

  LoopMode get loopMode => _player.loopMode;

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }
}

final playerProvider = ChangeNotifierProvider<PlayerController>((ref) {
  final controller = PlayerController(ref.watch(apiClientProvider));
  ref.onDispose(controller.dispose);
  return controller;
});

final currentTrackProvider =
    Provider<Track?>((ref) => ref.watch(playerProvider).current);
