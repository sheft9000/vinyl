import MediaPlayer
import SwiftUI

/// Schermata di sola verifica. Ci si arriva soltanto con
/// `-previewScreen comandi`: nessun percorso dell'app la raggiunge.
///
/// Serve perché lo sviluppo avviene senza un iPhone in mano. Quali tasti
/// disegnare nel Centro di Controllo lo decide iOS, e quella decisione non si
/// può fotografare dal Simulatore: senza audio in riproduzione non esiste
/// nessuna scheda "In riproduzione" da inquadrare. Qui si legge però lo stato
/// vero di `MPRemoteCommandCenter` mentre l'app gira, che è l'unica cosa su
/// cui l'app abbia voce in capitolo.
struct RemoteCommandsView: View {
    /// Non è decorativo: i comandi vengono dichiarati dentro l'inizializzatore
    /// di `PlayerController`. Senza toccarlo qui, questa schermata leggerebbe
    /// lo stato di partenza del sistema invece del nostro.
    @StateObject private var player = PlayerController.shared

    private struct Comando: Identifiable {
        let id = UUID()
        let nome: String
        let attivo: Bool
        let atteso: Bool
        var giusto: Bool { attivo == atteso }
    }

    private var comandi: [Comando] {
        let centro = MPRemoteCommandCenter.shared()
        return [
            Comando(nome: "Brano successivo", attivo: centro.nextTrackCommand.isEnabled, atteso: true),
            Comando(nome: "Brano precedente", attivo: centro.previousTrackCommand.isEnabled, atteso: true),
            Comando(nome: "Riproduci", attivo: centro.playCommand.isEnabled, atteso: true),
            Comando(nome: "Pausa", attivo: centro.pauseCommand.isEnabled, atteso: true),
            Comando(nome: "Riproduci/Pausa", attivo: centro.togglePlayPauseCommand.isEnabled, atteso: true),
            Comando(nome: "Avanti di 15 secondi", attivo: centro.skipForwardCommand.isEnabled, atteso: false),
            Comando(nome: "Indietro di 15 secondi", attivo: centro.skipBackwardCommand.isEnabled, atteso: false),
            Comando(nome: "Avanzamento veloce", attivo: centro.seekForwardCommand.isEnabled, atteso: false),
            Comando(nome: "Riavvolgimento", attivo: centro.seekBackwardCommand.isEnabled, atteso: false),
        ]
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(comandi) { comando in
                        HStack(spacing: 12) {
                            Image(systemName: comando.giusto
                                  ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(comando.giusto ? .green : .red)
                            Text(comando.nome)
                            Spacer(minLength: 8)
                            Text(comando.attivo ? "attivo" : "spento")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Comandi dichiarati a iOS")
                } footer: {
                    Text("I quattro comandi in fondo devono risultare spenti: è la loro presenza che autorizza iOS a disegnare le frecce circolari da quindici secondi al posto di quelle di cambio brano.")
                }

                Section("In riproduzione") {
                    LabeledContent("Brano", value: player.current?.title ?? "nessuno")
                    LabeledContent("Tipo dichiarato", value: "musica")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Comandi remoti")
        }
    }
}
