import SwiftUI
import UIKit

/// Il colore d'accento dell'app, scelto dalle Impostazioni e ricordato fra un
/// avvio e l'altro.
///
/// Serve un oggetto osservabile e non una costante: SwiftUI ridisegna solo
/// quello che osserva, quindi con una `static let` il colore cambierebbe
/// soltanto riavviando l'app. La tinta viene applicata una volta sola alla
/// `TabView`, e da lì SwiftUI la propaga da sé a barre, cursori e pulsanti;
/// le poche viste che colorano del testo a mano leggono direttamente questo
/// oggetto.
final class AccentTheme: ObservableObject {
    static let shared = AccentTheme()

    private static let chiave = "coloreAccento"

    /// Il rosso dell'app Musica di iOS.
    static let predefinito = "FA294A"

    /// Le tinte di sistema di iOS. Sono quelle che Apple usa nelle sue app,
    /// quindi restano leggibili sul fondo scuro senza doverle correggere.
    static let preset: [String] = [
        "FA294A", // rosso
        "FF9500", // arancione
        "FFCC00", // giallo
        "34C759", // verde
        "00C7BE", // menta
        "0A84FF", // blu
        "5E5CE6", // indaco
        "BF5AF2", // viola
    ]

    @Published var color: Color {
        didSet { UserDefaults.standard.set(color.hexRGB, forKey: Self.chiave) }
    }

    private init() {
        let salvato = UserDefaults.standard.string(forKey: Self.chiave) ?? Self.predefinito
        // Il `didSet` non scatta dentro l'inizializzatore: qui si legge soltanto.
        color = Color(hexRGB: salvato) ?? Color(hexRGB: Self.predefinito)
            ?? Color(red: 0.98, green: 0.16, blue: 0.29)
    }
}

extension Color {
    /// Costruisce il colore da sei cifre esadecimali, con o senza cancelletto.
    init?(hexRGB: String) {
        var testo = hexRGB.trimmingCharacters(in: .whitespacesAndNewlines)
        if testo.hasPrefix("#") { testo.removeFirst() }
        guard testo.count == 6, let valore = UInt32(testo, radix: 16) else { return nil }
        self.init(
            red: Double((valore >> 16) & 0xFF) / 255,
            green: Double((valore >> 8) & 0xFF) / 255,
            blue: Double(valore & 0xFF) / 255
        )
    }

    /// Le sei cifre esadecimali corrispondenti. Serve per salvare la scelta:
    /// `Color` non è archiviabile così com'è.
    var hexRGB: String {
        var rosso: CGFloat = 0, verde: CGFloat = 0, blu: CGFloat = 0, alfa: CGFloat = 0
        _ = UIColor(self).getRed(&rosso, green: &verde, blue: &blu, alpha: &alfa)
        return String(format: "%02X%02X%02X",
                      Int((rosso * 255).rounded()),
                      Int((verde * 255).rounded()),
                      Int((blu * 255).rounded()))
    }
}
