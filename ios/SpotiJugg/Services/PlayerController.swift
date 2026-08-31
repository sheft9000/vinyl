import AVFoundation
import Combine
import MediaPlayer
import UIKit

/// Tutta la riproduzione passa di qui. Le schermate non toccano mai
/// direttamente `AVQueuePlayer`: chiedono di suonare una lista e osservano
/// cosa sta succedendo.
@MainActor
final class PlayerController: ObservableObject {
    static let shared = PlayerController()

    @Published private(set) var queue: [Track] = []
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var isPlaying = false
    @Published private(set) var position: TimeInterval = 0
    @Published var queueLabel: String = ""

    private let player = AVQueuePlayer()
    private var timeObserver: Any?
    private var endObserver: AnyCancellable?

    // La copertina va tenuta da parte, non solo consegnata una volta. Ogni
    // pausa o spostamento riscrive per intero la scheda "In riproduzione", e
    // senza una copia qui la copertina sparirebbe al primo tocco su pausa.
    private var artworkCorrente: MPMediaItemArtwork?
    private var artworkDelBrano: Int?
    private var scaricamentoArtwork: Task<Void, Never>?

    var current: Track? {
        guard queue.indices.contains(currentIndex) else { return nil }
        return queue[currentIndex]
    }

    var duration: TimeInterval {
        current.map { $0.duration } ?? 0
    }

    private init() {
        configureSession()
        observeTime()
        observeTrackEnd()
        configureRemoteCommands()
    }

    /// Senza questo l'audio si ferma quando lo schermo si spegne, e i comandi
    /// della schermata di blocco non compaiono affatto.
    private func configureSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("sessione audio non configurata: \(error)")
        }
    }

    private func observeTime() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: interval, queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                self?.position = time.seconds.isFinite ? time.seconds : 0
            }
        }
    }

    private func observeTrackEnd() {
        endObserver = NotificationCenter.default
            .publisher(for: AVPlayerItem.didPlayToEndTimeNotification)
            .sink { [weak self] _ in
                Task { @MainActor in self?.advance() }
            }
    }

    /// Quali tasti iOS disegna nel Centro di Controllo e sulla schermata di
    /// blocco non lo decide l'app: lo decide il sistema guardando quali comandi
    /// risultano attivi. E qui sta l'inganno: **nascono tutti attivi**, anche
    /// quelli che non abbiamo mai gestito. Finché i due comandi da quindici
    /// secondi restano accesi, iOS ha il diritto di mostrare le frecce
    /// circolari al posto di quelle di cambio brano. Vanno spenti a mano, uno
    /// per uno: non basta ignorarli.
    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.play() }
            return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        // Il tasto centrale delle cuffie e la pressione sugli AirPods.
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.toggle() }
            return .success
        }
        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }

        // Questi sono i responsabili delle frecce circolari da 15 secondi.
        center.skipForwardCommand.isEnabled = false
        center.skipBackwardCommand.isEnabled = false
        // Avanzamento e riavvolgimento tenendo premuto: roba da lettore di
        // podcast, non da lettore musicale.
        center.seekForwardCommand.isEnabled = false
        center.seekBackwardCommand.isEnabled = false
    }

    // MARK: - Comandi

    func play(_ tracks: [Track], startingAt index: Int = 0, label: String = "",
              client: APIClient) {
        guard !tracks.isEmpty else { return }
        queue = tracks
        queueLabel = label
        currentIndex = min(max(index, 0), tracks.count - 1)
        startCurrent(client: client)
    }

    private var client: APIClient?

    private func startCurrent(client: APIClient) {
        self.client = client
        guard let track = current, let url = client.streamURL(trackID: track.id) else { return }
        player.removeAllItems()
        player.insert(AVPlayerItem(url: url), after: nil)
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
        caricaArtwork(per: track)
    }

    /// Scarica la copertina e la consegna al Centro di Controllo.
    ///
    /// Va fatto a parte e non dentro `updateNowPlayingInfo`: quella viene
    /// richiamata a ogni pausa e a ogni spostamento, e rifare una richiesta di
    /// rete ogni volta sarebbe uno spreco. Qui si scarica una volta per brano.
    private func caricaArtwork(per track: Track) {
        scaricamentoArtwork?.cancel()
        artworkCorrente = nil
        artworkDelBrano = nil

        guard let url = client?.artworkURL(track.artKey, size: "full") else { return }

        scaricamentoArtwork = Task { [weak self] in
            guard let (dati, _) = try? await URLSession.shared.data(from: url),
                  let immagine = UIImage(data: dati) else { return }
            await MainActor.run {
                guard let self else { return }
                // Nel frattempo il brano puo' essere cambiato: senza questo
                // controllo si vedrebbe la copertina di quello precedente.
                guard self.current?.id == track.id else { return }
                self.artworkCorrente = MPMediaItemArtwork(boundsSize: immagine.size) { _ in immagine }
                self.artworkDelBrano = track.id
                self.updateNowPlayingInfo()
            }
        }
    }

    func toggle() { isPlaying ? pause() : play() }

    func play() {
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func next() { advance() }

    /// Come su iOS: entro i primi secondi torna indietro, dopo ricomincia.
    func previous() {
        if position > 4 {
            seek(to: 0)
        } else if currentIndex > 0 {
            currentIndex -= 1
            if let client { startCurrent(client: client) }
        } else {
            seek(to: 0)
        }
    }

    func seek(to seconds: TimeInterval) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
        position = seconds
        updateNowPlayingInfo()
    }

    func jump(to index: Int) {
        guard queue.indices.contains(index), let client else { return }
        currentIndex = index
        startCurrent(client: client)
    }

    private func advance() {
        guard currentIndex + 1 < queue.count, let client else {
            pause()
            return
        }
        currentIndex += 1
        startCurrent(client: client)
    }

    /// Ciò che compare sulla schermata di blocco e nel Centro di Controllo.
    private func updateNowPlayingInfo() {
        guard let track = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistName,
            MPMediaItemPropertyAlbumTitle: track.albumTitle,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: position,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        // Dichiararsi musica e non podcast: con il tipo sbagliato iOS rimette
        // da solo i salti da quindici secondi, per quanto li si spenga.
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        if let artwork = artworkCorrente, artworkDelBrano == track.id {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Coda finta per le schermate fotografate dalla CI.
    func loadSampleQueue() {
        queue = SampleLibrary.tracks
        currentIndex = 3
        queueLabel = "Aggiunti di recente"
        isPlaying = true
        position = 64
        updateNowPlayingInfo()
    }
}
