# Installare SpotiJugg sull'iPhone

L'app esce **non firmata**: non c'e' nessun account sviluppatore a pagamento.
A firmarla pensa un programma di sideload usando il tuo Apple ID gratuito.

Indirizzo dell'IPA, sempre lo stesso a ogni versione:

```
https://github.com/sheft9000/vinyl/releases/download/ultima/SpotiJugg.ipa
```

## Cosa comporta l'Apple ID gratuito

Tre limiti che valgono per qualsiasi strada tu scelga, e che non dipendono da
come e' fatta l'app:

- La firma **scade dopo sette giorni**. Passati quelli l'app non si apre piu'
  finche' non la si rinnova. I dati e le impostazioni restano.
- Al massimo **tre app** sideloadate contemporaneamente sullo stesso telefono.
- Al massimo **dieci identificativi** nuovi a settimana. Rinnovare la stessa
  app non ne consuma.

## Prima di tutto: Modalita' sviluppatore

Da iOS 16 un'app firmata cosi' non parte se la modalita' sviluppatore e'
spenta. Si accende una volta sola:

**Impostazioni → Privacy e sicurezza → Modalita sviluppatore → attiva**, poi
il telefono chiede di riavviarsi.

La voce compare solo **dopo** che il telefono e' stato collegato almeno una
volta a un programma di sideload. Se ancora non la vedi, fai prima
l'installazione e torna qui.

## Strada A — Sideloadly: la piu' corta per la prima volta

Serve il telefono collegato via cavo. Nessun file di accoppiamento, nessuna
VPN, nessun servizio da tenere in piedi.

1. Scarica **iTunes dal sito di Apple** (non la versione del Microsoft Store:
   quella non espone i driver che servono) e installalo.
2. Scarica **Sideloadly** da `https://sideloadly.io` e installalo.
3. Collega l'iPhone, sbloccalo, e se chiede "Autorizzare questo computer?"
   rispondi di si'.
4. Apri Sideloadly, trascina dentro `SpotiJugg.ipa`, scrivi il tuo Apple ID,
   premi **Start** e inserisci la password quando la chiede.
5. Sul telefono: **Impostazioni → Generali → VPN e gestione dispositivo**,
   tocca il tuo Apple ID e **Autorizza**.

Per rinnovare fra sette giorni: ricollega il cavo e ripeti dal punto 4. Meno
di un minuto.

Se Apple chiede una password specifica per l'app, generala da
`https://account.apple.com` nella sezione della sicurezza: succede quando
sull'account e' attiva l'autenticazione a due fattori.

## Strada B — SideStore: si rinnova da sola, senza il PC

Piu' laboriosa da mettere su, ma dopo il telefono si rinnova da solo, senza
cavo e senza computer acceso. E' la strada scelta all'inizio del progetto.

Il primo passo resta la strada A: SideStore e' a sua volta un'app da
sideloadare. In breve:

1. Con Sideloadly installa **SideStore.ipa** invece di SpotiJugg.
2. Genera il **file di accoppiamento** con `jitterbugpair.exe`: produce un
   file `.mobiledevicepairing` legato a quel telefono.
3. Passa quel file all'iPhone e aprilo con SideStore.
4. Attiva la VPN locale che SideStore installa: e' quella che gli permette di
   rifirmare le app da solo.
5. Dentro SideStore, **+** e scegli `SpotiJugg.ipa`.

I passaggi esatti cambiano fra una versione e l'altra di SideStore: prima di
partire guarda `https://docs.sidestore.io`, che e' la fonte aggiornata.

## Dopo l'installazione

1. Fai partire il server sul PC: `server\run.ps1`.
2. Scopri l'indirizzo del PC sulla rete di casa: `ipconfig`, voce
   **Indirizzo IPv4**, qualcosa come `192.168.1.20`.
3. Sul telefono apri SpotiJugg, ingranaggio in alto a destra, scrivi
   l'indirizzo e il token, poi **Salva e verifica**.
4. Alla prima richiesta iOS chiede il permesso per la **rete locale**:
   rispondi di si', altrimenti l'app non vede il server e non spiega perche'.

Telefono e computer devono stare sulla stessa rete Wi-Fi. Da fuori casa non
funziona ancora: quello e' il passo successivo del piano.
