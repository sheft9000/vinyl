import SwiftUI

/// Libreria di esempio usata dalla CI per fotografare l'app.
///
/// Senza un server raggiungibile dal Simulatore le schermate sarebbero vuote,
/// e una schermata vuota non dice niente su come sarà l'app. Le copertine sono
/// generate a partire dal nome, così non serve nessun file di immagine.
enum SampleLibrary {
    static let albums: [Album] = [
        Album(id: 1, title: "Luci Basse", artistId: 1, artistName: "Corale Notturna",
              year: 2021, artKey: "album-1", trackCount: 9, durationMs: 2_412_000),
        Album(id: 2, title: "Campi Aperti", artistId: 2, artistName: "Sestetto Meridiano",
              year: 2019, artKey: "album-2", trackCount: 7, durationMs: 1_980_000),
        Album(id: 3, title: "Rovine Gentili", artistId: 3, artistName: "Ombre Lunghe",
              year: 2023, artKey: "album-3", trackCount: 11, durationMs: 2_760_000),
        Album(id: 4, title: "Marea di Settembre", artistId: 4, artistName: "Anna Vestri",
              year: 2024, artKey: "album-4", trackCount: 8, durationMs: 2_100_000),
        Album(id: 5, title: "Cinque Stanze", artistId: 5, artistName: "Il Grande Vetro",
              year: 2018, artKey: "album-5", trackCount: 5, durationMs: 1_440_000),
    ]

    static let artists: [Artist] = [
        Artist(id: 1, name: "Corale Notturna", albumCount: 2, trackCount: 17, artKey: "album-1"),
        Artist(id: 2, name: "Sestetto Meridiano", albumCount: 1, trackCount: 7, artKey: "album-2"),
        Artist(id: 3, name: "Ombre Lunghe", albumCount: 3, trackCount: 24, artKey: "album-3"),
        Artist(id: 4, name: "Anna Vestri", albumCount: 1, trackCount: 8, artKey: "album-4"),
        Artist(id: 5, name: "Il Grande Vetro", albumCount: 1, trackCount: 5, artKey: "album-5"),
    ]

    static let tracks: [Track] = [
        Track(id: 101, title: "Preludio al buio", artistName: "Corale Notturna",
              albumTitle: "Luci Basse", trackNo: 1, durationMs: 214_000, artKey: "album-1"),
        Track(id: 102, title: "Vetro bagnato", artistName: "Corale Notturna",
              albumTitle: "Luci Basse", trackNo: 2, durationMs: 187_000, artKey: "album-1"),
        Track(id: 103, title: "Ultimo tram", artistName: "Corale Notturna",
              albumTitle: "Luci Basse", trackNo: 3, durationMs: 246_000, artKey: "album-1"),
        Track(id: 201, title: "Marea bassa", artistName: "Sestetto Meridiano",
              albumTitle: "Campi Aperti", trackNo: 1, durationMs: 301_000, artKey: "album-2"),
        Track(id: 202, title: "Grano", artistName: "Sestetto Meridiano",
              albumTitle: "Campi Aperti", trackNo: 2, durationMs: 158_000, artKey: "album-2"),
        Track(id: 301, title: "Cortile", artistName: "Ombre Lunghe",
              albumTitle: "Rovine Gentili", trackNo: 1, durationMs: 233_000, artKey: "album-3"),
        Track(id: 302, title: "Pietra calda", artistName: "Ombre Lunghe",
              albumTitle: "Rovine Gentili", trackNo: 2, durationMs: 279_000, artKey: "album-3"),
        Track(id: 401, title: "Settembre, poi", artistName: "Anna Vestri",
              albumTitle: "Marea di Settembre", trackNo: 1, durationMs: 195_000, artKey: "album-4"),
        Track(id: 501, title: "La stanza chiara", artistName: "Il Grande Vetro",
              albumTitle: "Cinque Stanze", trackNo: 1, durationMs: 262_000, artKey: "album-5"),
    ]

    static let stats = LibraryStats(
        artists: 5, albums: 5, tracks: 40, totalDurationMs: 10_692_000)
}

/// Copertina: scaricata dal server, oppure generata quando siamo in modalità
/// campione. Il colore deriva dal nome, quindi lo stesso album ha sempre la
/// stessa copertina.
struct ArtworkView: View {
    let artKey: String?
    var size: String = "thumb"

    @EnvironmentObject private var library: LibraryStore

    var body: some View {
        if library.usesSampleData {
            GeneratedArtwork(key: artKey ?? "")
        } else if let url = library.client.artworkURL(artKey, size: size) {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ArtworkPlaceholder()
            }
        } else {
            ArtworkPlaceholder()
        }
    }
}

struct ArtworkPlaceholder: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.tertiary)
        }
    }
}

struct GeneratedArtwork: View {
    let key: String

    private var hue: Double {
        // Sommare i codici dei caratteri dava tinte a un grado di distanza fra
        // "album-1" e "album-2": tutte le copertine venivano dello stesso
        // viola. djb2 le sparpaglia su tutto il cerchio cromatico.
        var hash = 5381
        for scalar in key.unicodeScalars {
            hash = (hash &* 33) &+ Int(scalar.value)
        }
        return Double(abs(hash) % 360) / 360
    }

    var body: some View {
        LinearGradient(
            colors: [
                Color(hue: hue, saturation: 0.62, brightness: 0.78),
                Color(hue: (hue + 0.08).truncatingRemainder(dividingBy: 1),
                      saturation: 0.78, brightness: 0.32),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            Circle()
                .strokeBorder(.white.opacity(0.28), lineWidth: 2)
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
        }
    }
}
