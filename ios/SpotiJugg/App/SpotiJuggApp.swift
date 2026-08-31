import SwiftUI

@main
struct SpotiJuggApp: App {
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            if PreviewConfig.showsRemoteCommands {
                RemoteCommandsView()
            } else {
                RootView()
                    .environmentObject(library)
            }
        }
    }
}

/// Configurazione usata solo dalla CI per fotografare l'app.
///
/// Lo sviluppo avviene su Windows, quindi l'unico modo di vedere l'app è
/// lasciare che GitHub Actions la avvii nel Simulatore e ne scatti uno
/// screenshot. Aprire una schermata precisa con un argomento di avvio è molto
/// più semplice che automatizzare dei tocchi, e non richiede un target di test.
///
/// Gli argomenti nella forma `-chiave valore` finiscono automaticamente in
/// `UserDefaults`, quindi non serve altro per leggerli.
enum PreviewConfig {
    /// `-previewData YES` popola l'app con una libreria di esempio, così le
    /// schermate hanno contenuto anche senza un server raggiungibile.
    static var usesSampleData: Bool {
        UserDefaults.standard.bool(forKey: "previewData")
    }

    /// `-previewScreen home|library|search|player|album|settings|comandi`
    static var screen: String? {
        UserDefaults.standard.string(forKey: "previewScreen")
    }

    static var initialTab: RootTab {
        switch screen {
        case "library", "album": return .library
        case "search": return .search
        default: return .home
        }
    }

    /// Le schermate che si aprono sopra la scheda invece di esserne la radice.
    static var opensPlayer: Bool { screen == "player" }
    static var opensAlbum: Bool { screen == "album" }
    static var opensSettings: Bool { screen == "settings" }

    /// Schermata di verifica dei comandi remoti, fuori dall'app vera.
    static var showsRemoteCommands: Bool { screen == "comandi" }
}
