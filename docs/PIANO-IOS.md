# Cambio di rotta: da Flutter a SwiftUI

Data della decisione: 31 agosto 2026.

## Perché

L'obiettivo è "un'applicazione iOS in tutto e per tutto". Flutter non può
arrivarci: non usa nemmeno un controllo di iOS, disegna ogni pixel su una tela.
Tab bar, titoli grandi, materiali, SF Symbols, Liquid Glass — in Flutter sono
tutti reimplementazioni a mano, e le cuciture si vedono. Tre tentativi di
avvicinamento sono stati respinti, correttamente, come "skin iOS su Android".

SwiftUI usa i componenti veri: la tab bar *è* la tab bar di sistema,
`NavigationStack` fa i titoli grandi con il comportamento nativo, `.searchable`
è il campo di ricerca di iOS, `.glassEffect` (iOS 26) è il Liquid Glass vero.

## Il vincolo

Nessun Mac. Niente Xcode locale, niente anteprime, niente simulatore.

Conseguenze operative:

- Il progetto Xcode non si crea a mano: si genera da **XcodeGen** partendo da
  `project.yml`, che è testo e si scrive da Windows.
- Si compila sui **runner macOS di GitHub Actions**, gratuiti e illimitati
  perché il repo è pubblico.
- Il ciclo di revisione visiva passa dalla CI: build → avvio del Simulatore →
  screenshot → caricati come artefatto della run. Circa 12 minuti a giro.
- Ogni errore di compilazione costa un giro di CI: il codice va scritto con
  attenzione, non a tentativi.

## Cosa sopravvive

Tutto il server, invariato:

- `server/app/` — FastAPI, scanner, API, streaming con Range
- `server/tests/smoke_test.py` — 35 controlli, verdi
- Deduzione dei tag dal percorso quando i file non sono taggati

L'API è già quella che consumerà l'app iOS. Nessuna modifica prevista.

## Cosa si butta

`app/` — il client Flutter, circa 3.700 righe. Il progetto Android, l'SDK e
l'emulatore restano installati ma non servono più.

## Struttura di arrivo

```
server/            invariato
ios/
  project.yml      definizione del progetto per XcodeGen
  Vinyl/
    App/           punto di ingresso, configurazione
    Models/        Track, Album, Artist — rispecchiano l'API
    Services/      APIClient, PlayerController (AVFoundation)
    Features/      Home, Cerca, Libreria, Album, Artista, Player
.github/workflows/
  screenshots.yml  build + Simulatore + screenshot come artefatto
  ipa.yml          build dell'IPA unsigned per SideStore
```

## Stato al 31 agosto 2026

Fatto:

- Repo pubblico `sheft9000/vinyl`, ramo `main`.
- Workflow `screenshots.yml`: compila su runner macOS, avvia il Simulatore,
  apre una schermata alla volta con `-previewScreen <nome>` e carica le
  immagini fra gli artefatti della run. Verde.
- App SwiftUI che compila: modelli, client HTTP, `PlayerController` su
  `AVQueuePlayer` con sessione audio e comandi remoti, schermate Home, Cerca,
  Libreria, Album, Impostazioni, mini player e player a schermo intero.
- Dati di esempio (`SampleLibrary`) con copertine generate, perche' dal
  Simulatore il server di casa non e' raggiungibile.

Difetti gia' trovati e corretti grazie agli screenshot:

- `UILaunchScreen` mancante: l'app girava in modalita' compatibilita', scalata,
  con le bande nere. Le impostazioni `INFOPLIST_KEY_*` non bastano quando il
  plist lo forniamo noi.
- `safeAreaInset` attorno alla `TabView` spingeva fuori schermo la barra delle
  schede su iOS 26.
- Tinte delle copertine generate tutte uguali per un hash mal rimescolato.

## Vincolo aggiunto: iOS 17

L'app deve girare su iOS 17. Conseguenze:

- Il target di deployment resta `17.0`.
- Le novita' di iOS 26 (tab bar flottante, `tabViewBottomAccessory`, i nuovi
  materiali) sul telefono di destinazione **non compaiono**: vanno usate solo
  dietro `if #available(iOS 26.0, *)`, con un ripiego per iOS 17.
- La CI deve fotografare su un Simulatore iOS 17, non sul piu' recente:
  altrimenti si verifica l'aspetto contro un sistema diverso da quello vero.

## Ordine di lavoro

1. Repo pubblico su GitHub + workflow che compila e restituisce screenshot.
   Prima il ciclo di verifica, poi l'interfaccia: senza, si torna a indovinare.
2. Modelli, client API, riproduzione audio con AVFoundation.
3. Le schermate, usando i componenti di sistema e nient'altro.
4. IPA unsigned + installazione con SideStore.
5. Accesso da fuori casa (Cloudflare Tunnel) e multiutente.

## Impostazioni del server già in uso

- `MUSIC_DIR` = `D:/.PRIVATE/gab/songs&images/songs` (cartella di prova)
- Token API in `server/.env`
- Il server si avvia con `server/run.ps1`
