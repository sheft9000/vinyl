import Foundation

/// Indirizzo del server e token, le uniche due cose che l'app deve sapere.
struct ServerSettings {
    var baseURL: String
    var token: String

    static let storageKey = "serverSettings"

    var isConfigured: Bool { !baseURL.isEmpty && !token.isEmpty }

    /// Tollera quello che si scrive davvero nel campo: "192.168.1.10",
    /// "192.168.1.10:8080/", "http://casa.example.com".
    var normalized: String {
        var value = baseURL.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return "" }
        if !value.hasPrefix("http://") && !value.hasPrefix("https://") {
            value = "http://" + value
        }
        while value.hasSuffix("/") { value.removeLast() }
        if let url = URL(string: value), url.port == nil, url.path.isEmpty {
            value += ":8080"
        }
        return value
    }

    static func load() -> ServerSettings {
        let defaults = UserDefaults.standard
        return ServerSettings(
            baseURL: defaults.string(forKey: "serverBaseURL") ?? "",
            token: defaults.string(forKey: "serverToken") ?? ""
        )
    }

    func save() {
        let defaults = UserDefaults.standard
        defaults.set(baseURL, forKey: "serverBaseURL")
        defaults.set(token, forKey: "serverToken")
    }
}

enum APIError: LocalizedError {
    case notConfigured
    case unauthorized
    case unreachable(String)
    case badStatus(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Server non ancora configurato."
        case .unauthorized:
            return "Token rifiutato: controllalo nelle impostazioni."
        case .unreachable(let host):
            return "Server irraggiungibile a \(host)."
        case .badStatus(let code):
            return "Il server ha risposto \(code)."
        }
    }
}

/// Client HTTP. Nessuna dipendenza esterna: URLSession basta e avanza.
struct APIClient {
    var settings: ServerSettings

    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func url(_ path: String, query: [URLQueryItem] = []) -> URL? {
        var components = URLComponents(string: settings.normalized + "/api/v1" + path)
        if !query.isEmpty { components?.queryItems = query }
        return components?.url
    }

    /// La copertina la scarica `AsyncImage`, che non sa aggiungere header:
    /// per lei il token va in query string. Il server accetta entrambi.
    func artworkURL(_ artKey: String?, size: String = "thumb") -> URL? {
        guard let artKey, !artKey.isEmpty, settings.isConfigured else { return nil }
        return url("/artwork/\(artKey)", query: [
            URLQueryItem(name: "size", value: size),
            URLQueryItem(name: "token", value: settings.token),
        ])
    }

    /// Anche l'audio passa il token in query: lo apre AVPlayer per conto suo,
    /// e non sempre propaga gli header attraverso redirect e richieste Range.
    func streamURL(trackID: Int) -> URL? {
        url("/tracks/\(trackID)/stream", query: [
            URLQueryItem(name: "token", value: settings.token)
        ])
    }

    func get<T: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> T {
        guard settings.isConfigured, let endpoint = url(path, query: query) else {
            throw APIError.notConfigured
        }
        var request = URLRequest(url: endpoint)
        request.setValue("Bearer \(settings.token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 || status == 403 { throw APIError.unauthorized }
            guard (200..<300).contains(status) else { throw APIError.badStatus(status) }
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            _ = error
            throw APIError.unreachable(settings.normalized)
        }
    }
}

/// Lo stato della libreria condiviso da tutte le schermate.
@MainActor
final class LibraryStore: ObservableObject {
    @Published var settings: ServerSettings
    @Published private(set) var recentAlbums: [Album] = []
    @Published private(set) var recentTracks: [Track] = []
    @Published private(set) var albums: [Album] = []
    @Published private(set) var artists: [Artist] = []
    @Published private(set) var stats: LibraryStats?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    let usesSampleData: Bool

    init() {
        usesSampleData = PreviewConfig.usesSampleData
        settings = usesSampleData
            ? ServerSettings(baseURL: "127.0.0.1:8080", token: "campione")
            : ServerSettings.load()
        if usesSampleData { loadSample() }
    }

    var client: APIClient { APIClient(settings: settings) }

    private func loadSample() {
        recentAlbums = SampleLibrary.albums
        albums = SampleLibrary.albums
        artists = SampleLibrary.artists
        recentTracks = SampleLibrary.tracks
        stats = SampleLibrary.stats
    }

    func refresh() async {
        guard !usesSampleData else { return }
        guard settings.isConfigured else {
            errorMessage = APIError.notConfigured.errorDescription
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            async let recentAlbumsPage: Page<Album> = client.get(
                "/albums", query: [.init(name: "sort", value: "recent"),
                                   .init(name: "limit", value: "20")])
            async let recentTracksPage: Page<Track> = client.get(
                "/tracks", query: [.init(name: "sort", value: "added"),
                                   .init(name: "limit", value: "30")])
            async let allAlbumsPage: Page<Album> = client.get(
                "/albums", query: [.init(name: "sort", value: "artist"),
                                   .init(name: "limit", value: "500")])
            async let artistsPage: Page<Artist> = client.get(
                "/artists", query: [.init(name: "limit", value: "500")])
            async let statsValue: LibraryStats = client.get("/stats")

            recentAlbums = try await recentAlbumsPage.items
            recentTracks = try await recentTracksPage.items
            albums = try await allAlbumsPage.items
            artists = try await artistsPage.items
            stats = try await statsValue
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? error.localizedDescription
        }
        isLoading = false
    }

    func tracks(inAlbum albumID: Int) async -> [Track] {
        if usesSampleData {
            return SampleLibrary.tracks.filter { $0.artKey == "album-\(albumID)" }
        }
        do {
            let page: Page<Track> = try await client.get("/albums/\(albumID)/tracks")
            return page.items
        } catch {
            return []
        }
    }

    func search(_ query: String) async -> (artists: [Artist], albums: [Album], tracks: [Track]) {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            return ([], [], [])
        }
        if usesSampleData {
            let needle = query.lowercased()
            return (
                artists.filter { $0.name.lowercased().contains(needle) },
                albums.filter { $0.title.lowercased().contains(needle) },
                recentTracks.filter { $0.title.lowercased().contains(needle) }
            )
        }
        struct Results: Decodable {
            let artists: [Artist]
            let albums: [Album]
            let tracks: [Track]
        }
        do {
            let results: Results = try await client.get(
                "/search", query: [.init(name: "q", value: query)])
            return (results.artists, results.albums, results.tracks)
        } catch {
            return ([], [], [])
        }
    }
}
