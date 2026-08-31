# SpotiJugg

Streaming musicale privato: un server che indicizza la tua libreria su disco e
un'app iOS che la riproduce. Niente cloud, niente abbonamenti, niente account
di terze parti.

- **server/** — API Python (FastAPI + SQLite), gira sul PC di casa
- **app/** — client Flutter per iPhone *(da M2)*
- **.github/workflows/** — build automatica dell'IPA *(da M4)*

## Stato

| | Milestone | Fatto |
|---|---|---|
| M0 | Scheletro del progetto | ✅ |
| M1 | Scanner libreria, API, streaming | ✅ |
| M2 | App Flutter, riproduzione | ⬜ |
| M3 | Interfaccia dark / vetro iOS | ⬜ |
| M4 | GitHub Actions → IPA → SideStore | ⬜ |
| M5 | Accesso remoto (Cloudflare Tunnel) + multi-utente | ⬜ |

## Avviare il server

```powershell
cd server
.\run.ps1 -Setup     # solo la prima volta: crea il virtualenv e installa tutto
```

Poi apri `server\.env` e imposta due valori:

```ini
MUSIC_DIR=D:/percorso/della/tua/musica
API_TOKEN=<genera un token>
```

Un token si genera con:

```powershell
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Riavvia con `.\run.ps1` e apri <http://localhost:8080>: incolla il token e
premi *Collega*. Quella pagina e' una console di test, non l'app — serve a
verificare che la libreria venga letta e che l'audio arrivi.

La documentazione interattiva dell'API e' su <http://localhost:8080/docs>.

## Come funziona

Il server **non scrive mai** dentro `MUSIC_DIR`: la apre in sola lettura.
Tutto cio' che produce (database SQLite e copertine ridimensionate) finisce in
`server/data/`, che puoi cancellare in qualsiasi momento — alla ripartenza
viene ricostruito dalla scansione.

Un brano il cui file sparisce non viene cancellato dal database ma marcato come
mancante: se stacchi un disco esterno non perdi nulla, e al ricollegamento
torna tutto al suo posto.

Le copertine sono indicizzate per hash del contenuto, quindi due album con la
stessa immagine occupano un solo file e il client puo' tenerle in cache per
sempre.

## Struttura del server

```
app/
  api/v1/        rotte HTTP           — nessuna logica, solo traduzione
  services/      logica applicativa   — scansione, tag, copertine, streaming
  repositories/  accesso ai dati      — le uniche query del progetto
  models.py      tabelle SQLAlchemy
  config.py      configurazione (.env), nessun percorso scritto nel codice
```

I tre livelli sono separati perche' ognuno sia sostituibile: SQLite diventa
PostgreSQL cambiando una stringa di connessione, e le rotte non se ne accorgono.
