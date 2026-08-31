# Gestire il server senza aiuto

Tutto passa da un unico script. Apri PowerShell nella cartella `server` ed
esegui i comandi qui sotto. Da solo, senza argomenti, stampa l'elenco.

```powershell
cd "D:\.PRIVATE\gab\83126 music player\server"
.\gestisci.ps1 stato
```

## I comandi

| Comando | Cosa fa |
|---|---|
| `.\gestisci.ps1 stato` | Acceso o spento, su che indirizzo, quanti brani, ultima scansione |
| `.\gestisci.ps1 avvia` | Lo accende in sottofondo, senza finestre aperte |
| `.\gestisci.ps1 avvia -Console` | Lo accende in primo piano, si ferma con Ctrl+C |
| `.\gestisci.ps1 ferma` | Lo spegne |
| `.\gestisci.ps1 riavvia` | Spegne e riaccende |
| `.\gestisci.ps1 log` | Ultime righe del registro |
| `.\gestisci.ps1 log -Segui` | Resta in ascolto, come guardare scorrere il registro |
| `.\gestisci.ps1 scansiona` | Rilegge la cartella della musica |
| `.\gestisci.ps1 scansiona -Forza` | Rilegge **tutti** i tag, anche dei file non cambiati |
| `.\gestisci.ps1 indirizzo` | Cosa scrivere nell'app, piu' il controllo del firewall |
| `.\gestisci.ps1 diagnostica` | Perche' il telefono non vede il server: controlla tutta la catena |
| `.\gestisci.ps1 prova` | Esegue i 35 controlli automatici del server |
| `.\gestisci.ps1 pannello` | Apre l'API nel browser |
| `.\gestisci.ps1 autoavvio` | Lo fa partire da solo a ogni accesso a Windows |
| `.\gestisci.ps1 autoavvio -Rimuovi` | Toglie l'avvio automatico |

## Le tre cose che si rompono davvero

**Il telefono non vede il server.** Esegui `.\gestisci.ps1 diagnostica`:
controlla tutta la catena e dice a che anello si rompe.

Il controllo che conta e' l'ultimo, perche' e' l'unico che distingue davvero
fra i due mondi: guarda nel registro se dal telefono e' **mai** arrivata una
richiesta. Se non ne e' arrivata nessuna, il problema sta nella rete e
frugare nelle impostazioni dell'app e' tempo perso. Se ne sono arrivate ma
con risposta 401, allora il token e' sbagliato.

Nove volte su dieci e' il firewall di Windows. Attenzione a una cosa: provare
il server dal computer stesso **non dimostra niente**, perche' il traffico
locale non attraversa il firewall. Il collaudo vero e' aprire Safari sul
telefono e andare su `http://INDIRIZZO:8080/health`: se non si apre e' rete,
se si apre e' l'app.

Leggere le regole del firewall richiede i privilegi di amministratore: da una
finestra normale lo script dice "non posso controllarlo", non "e' chiuso". La
regola si aggiunge comunque, e aggiungerla due volte non fa danno.

**Le modifiche al `.env` non hanno effetto.** Vuol dire che il server non si
e' mai riavviato davvero: la configurazione si legge una volta sola, quando
parte. Quasi sempre la causa e' che il server e' stato avviato da una finestra
**da amministratore** — per esempio quella aperta per la regola del firewall.
Un processo avviato cosi' eredita quei privilegi, e da una finestra normale
non si riesce piu' a fermarlo: `ferma` lo dice, con il comando da usare.

Si risolve chiudendolo da un PowerShell come amministratore
(`Stop-Process -Id NUMERO -Force`) e riavviandolo da una finestra **normale**.
Da allora in poi `ferma` funziona senza storie. Lo script ora avvisa prima di
avviare il server da una finestra elevata, cosi' non ricapita.

**L'indirizzo IP e' cambiato.** Il router assegna gli indirizzi a rotazione e
ogni tanto ne cambia uno. Se l'app smette di collegarsi da un giorno all'altro
senza che nessuno abbia toccato niente, e' quasi sempre questo:
`.\gestisci.ps1 indirizzo` e riscrivi il nuovo numero nelle impostazioni
dell'app. Per non pensarci mai piu', assegna al computer un indirizzo fisso
dal pannello del router.

**Un brano nuovo non compare.** Il server sorveglia la cartella da solo, ma
aspetta qualche secondo che le copie finiscano. Se dopo mezzo minuto ancora
non c'e', dai `.\gestisci.ps1 scansiona`. Se il brano c'e' ma con artista o
album sbagliati, il problema sono i tag del file: correggili e poi
`.\gestisci.ps1 scansiona -Forza`, che rilegge tutto da capo.

## Dove guardare quando qualcosa non torna

`.\gestisci.ps1 log` mostra due parti. Sopra gli **eventi**: avvio, scansioni,
avvertimenti — e' quella che serve quasi sempre. Sotto le **richieste
ricevute**: una riga per ogni chiamata, con il codice di risposta. Se il
telefono si sta collegando davvero, qui le righe compaiono mentre navighi
nell'app. Se non compare niente, il telefono non sta arrivando fino al server
e il problema e' di rete, non di libreria.

I file stanno in `server\data\`: `server-eventi.log` e `server-accessi.log`.
Sono divisi perche' uvicorn scrive le due cose su canali diversi, e Windows
non permette di raccoglierle in un file solo.

## Il pannello dell'API

`.\gestisci.ps1 pannello` apre `http://127.0.0.1:8080/docs`. E' l'elenco
completo di tutto cio' che il server sa fare, generato da solo dal codice, e
ogni comando si puo' provare dal browser. Utile per capire cosa e' successo
senza passare dall'app: per esempio se un album esiste davvero nel database o
no.

Per i comandi protetti serve il token, che trovi con
`.\gestisci.ps1 indirizzo`.

## Configurazione

Tutto sta in `server\.env`, un file di testo. Le voci che contano:

- `MUSIC_DIR` — la cartella della musica. Il server la apre **solo in
  lettura**: non sposta, non rinomina, non cancella mai niente.
- `API_TOKEN` — l'unica cosa che protegge la libreria. Cambiandolo va
  riscritto anche nell'app.
- `PORT` — la porta, 8080. Cambiandola va rifatta la regola del firewall.
- `SCAN_ON_STARTUP` — se rileggere la cartella a ogni avvio.
- `WATCH_LIBRARY` — se sorvegliare la cartella mentre gira.

Dopo ogni modifica: `.\gestisci.ps1 riavvia`.
