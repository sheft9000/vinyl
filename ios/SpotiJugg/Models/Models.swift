import Foundation

// I modelli rispecchiano uno a uno le risposte del server. Il decoder usa
// `convertFromSnakeCase`, quindi `art_key` diventa `artKey` senza bisogno di
// scrivere le CodingKeys a mano. I campi che il server invia ma che qui non
// servono vengono semplicemente ignorati.

struct Album: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let artistId: Int
    let artistName: String
    let year: Int?
    let artKey: String?
    let trackCount: Int
    let durationMs: Int
}

struct Artist: Identifiable, Decodable, Hashable {
    let id: Int
    let name: String
    let albumCount: Int
    let trackCount: Int
    let artKey: String?
}

struct Track: Identifiable, Decodable, Hashable {
    let id: Int
    let title: String
    let artistName: String
    let albumTitle: String
    let trackNo: Int?
    let durationMs: Int
    let artKey: String?

    var duration: TimeInterval { Double(durationMs) / 1000 }

    /// Riga secondaria mostrata sotto al titolo in tutta l'app.
    var subtitle: String {
        [artistName, albumTitle].filter { !$0.isEmpty }.joined(separator: " — ")
    }
}

struct Page<Item: Decodable>: Decodable {
    let items: [Item]
    let total: Int
}

struct LibraryStats: Decodable {
    let artists: Int
    let albums: Int
    let tracks: Int
    let totalDurationMs: Int
}

extension TimeInterval {
    /// 3:07, e 1:02:11 solo quando serve davvero.
    var asClock: String {
        let total = Int(rounded())
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
