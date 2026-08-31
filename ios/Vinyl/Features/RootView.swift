import SwiftUI

enum RootTab: Hashable { case home, search, library }

extension View {
    /// Il mini player va inserito *dentro* ogni scheda, non attorno alla
    /// TabView: un inset applicato alla TabView spinge fuori schermo la barra
    /// delle schede, che su iOS 26 galleggia sopra il contenuto.
    func withMiniPlayer(onTap: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            MiniPlayerBar(onTap: onTap)
        }
    }
}

enum Theme {
    /// Il rosso dell'app Musica di iOS. Cambiare questa riga cambia l'accento
    /// di tutta l'app: SwiftUI lo propaga da solo a controlli, link e tab bar.
    static let accent = Color(red: 0.98, green: 0.16, blue: 0.29)
}

struct RootView: View {
    @EnvironmentObject private var library: LibraryStore
    @StateObject private var player = PlayerController.shared

    @State private var tab: RootTab = PreviewConfig.initialTab
    @State private var showPlayer = false

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .withMiniPlayer { showPlayer = true }
                .tabItem { Label("Ascolta ora", systemImage: "play.circle.fill") }
                .tag(RootTab.home)

            SearchView()
                .withMiniPlayer { showPlayer = true }
                .tabItem { Label("Cerca", systemImage: "magnifyingglass") }
                .tag(RootTab.search)

            LibraryView()
                .withMiniPlayer { showPlayer = true }
                .tabItem { Label("Libreria", systemImage: "square.stack") }
                .tag(RootTab.library)
        }
        .tint(Theme.accent)
        .environmentObject(player)
        .fullScreenCover(isPresented: $showPlayer) {
            NowPlayingView().environmentObject(player)
        }
        .task {
            if library.usesSampleData {
                player.loadSampleQueue()
                if PreviewConfig.opensPlayer { showPlayer = true }
            } else {
                await library.refresh()
            }
        }
    }
}

// MARK: - Ascolta ora

struct HomeView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController

    var body: some View {
        NavigationStack {
            List {
                Section {
                    AlbumShelf(albums: library.recentAlbums)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    Text("Aggiunti di recente")
                }

                Section {
                    ForEach(Array(library.recentTracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            player.play(library.recentTracks, startingAt: index,
                                        label: "Brani recenti", client: library.client)
                        } label: {
                            TrackRow(track: track,
                                     isCurrent: player.current?.id == track.id)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Brani recenti")
                }
            }
            .headerProminence(.increased)
            .listStyle(.insetGrouped)
            .navigationTitle("Ascolta ora")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .refreshable { await library.refresh() }
            .overlay {
                if library.recentAlbums.isEmpty, let message = library.errorMessage {
                    ContentUnavailableView("Nessuna libreria", systemImage: "wifi.slash",
                                           description: Text(message))
                }
            }
        }
    }
}

struct AlbumShelf: View {
    let albums: [Album]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(alignment: .top, spacing: 14) {
                ForEach(albums) { album in
                    NavigationLink {
                        AlbumView(album: album)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            ArtworkView(artKey: album.artKey, size: "full")
                                .frame(width: 156, height: 156)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            Text(album.title)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(album.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(width: 156, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct TrackRow: View {
    let track: Track
    var isCurrent: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(artKey: track.artKey)
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(track.title)
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? Theme.accent : .primary)
                Text(track.subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(track.duration.asClock)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Cerca

struct SearchView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController

    @State private var query = ""
    @State private var albums: [Album] = []
    @State private var tracks: [Track] = []

    var body: some View {
        NavigationStack {
            List {
                if !albums.isEmpty {
                    Section("Album") {
                        ForEach(albums) { album in
                            NavigationLink {
                                AlbumView(album: album)
                            } label: {
                                HStack(spacing: 12) {
                                    ArtworkView(artKey: album.artKey)
                                        .frame(width: 48, height: 48)
                                        .clipShape(RoundedRectangle(cornerRadius: 5,
                                                                    style: .continuous))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(album.title).lineLimit(1)
                                        Text(album.artistName)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
                if !tracks.isEmpty {
                    Section("Brani") {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            Button {
                                player.play(tracks, startingAt: index,
                                            label: "Risultati", client: library.client)
                            } label: {
                                TrackRow(track: track,
                                         isCurrent: player.current?.id == track.id)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Cerca")
            .searchable(text: $query, prompt: "Artisti, album, brani")
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView("Cerca nella tua libreria",
                                           systemImage: "magnifyingglass",
                                           description: Text("Accenti e maiuscole non contano."))
                } else if albums.isEmpty && tracks.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .task(id: query) {
                let results = await library.search(query)
                albums = results.albums
                tracks = results.tracks
            }
        }
    }
}

// MARK: - Libreria

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 22) {
                    ForEach(library.albums) { album in
                        NavigationLink {
                            AlbumView(album: album)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                ArtworkView(artKey: album.artKey, size: "full")
                                    .aspectRatio(1, contentMode: .fit)
                                    .clipShape(RoundedRectangle(cornerRadius: 8,
                                                                style: .continuous))
                                Text(album.title).font(.subheadline).lineLimit(1)
                                Text(album.artistName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationTitle("Libreria")
        }
    }
}

// MARK: - Album

struct AlbumView: View {
    let album: Album

    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var player: PlayerController
    @State private var tracks: [Track] = []

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    ArtworkView(artKey: album.artKey, size: "full")
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.45), radius: 18, y: 10)

                    VStack(spacing: 3) {
                        Text(album.title).font(.title3.weight(.semibold))
                        Text(album.artistName)
                            .font(.title3)
                            .foregroundStyle(Theme.accent)
                        Text(album.year.map { "\($0)" } ?? "")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button {
                            player.play(tracks, label: album.title, client: library.client)
                        } label: {
                            Label("Riproduci", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        Button {
                            player.play(tracks.shuffled(), label: album.title,
                                        client: library.client)
                        } label: {
                            Label("Casuale", systemImage: "shuffle")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(Theme.accent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        player.play(tracks, startingAt: index, label: album.title,
                                    client: library.client)
                    } label: {
                        HStack(spacing: 14) {
                            Text("\(track.trackNo ?? index + 1)")
                                .font(.body)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 22, alignment: .trailing)
                            Text(track.title)
                                .lineLimit(1)
                                .foregroundStyle(player.current?.id == track.id
                                                 ? Theme.accent : .primary)
                            Spacer(minLength: 8)
                            Text(track.duration.asClock)
                                .font(.footnote)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            tracks = await library.tracks(inAlbum: album.id)
        }
    }
}

// MARK: - Impostazioni

struct SettingsView: View {
    @EnvironmentObject private var library: LibraryStore
    @State private var baseURL = ""
    @State private var token = ""
    @State private var message: String?

    var body: some View {
        Form {
            Section {
                TextField("192.168.1.10:8080", text: $baseURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                SecureField("Token", text: $token)
            } header: {
                Text("Server")
            } footer: {
                Text("Senza porta viene usata la 8080. Sulla rete di casa basta l'indirizzo IP del computer che fa girare il server.")
            }

            Section {
                Button("Salva e verifica") {
                    library.settings = ServerSettings(baseURL: baseURL, token: token)
                    library.settings.save()
                    Task {
                        await library.refresh()
                        message = library.errorMessage ?? "Connesso."
                    }
                }
            }

            if let message {
                Section { Text(message).font(.footnote) }
            }

            if let stats = library.stats {
                Section("Libreria") {
                    LabeledContent("Artisti", value: "\(stats.artists)")
                    LabeledContent("Album", value: "\(stats.albums)")
                    LabeledContent("Brani", value: "\(stats.tracks)")
                }
            }
        }
        .navigationTitle("Impostazioni")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            baseURL = library.settings.baseURL
            token = library.settings.token
        }
    }
}
