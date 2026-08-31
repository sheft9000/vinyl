<#
.SYNOPSIS
    Comando unico per controllare e gestire il server musicale.

.DESCRIPTION
    Uso:  .\gestisci.ps1 <comando>

      stato       Il server risponde? Su che indirizzo, con quanta musica dentro.
      avvia       Lo accende in sottofondo, con il registro su file.
                  Con -Console resta in primo piano e si ferma con Ctrl+C.
      ferma       Lo spegne.
      riavvia     Spegne e riaccende.
      log         Ultime righe del registro. Con -Segui resta in ascolto.
      scansiona   Rilegge la cartella della musica. Con -Forza rilegge ogni tag.
      indirizzo   Cosa scrivere nelle impostazioni dell'app sul telefono.
      diagnostica Perche' il telefono non vede il server: controlla tutta la
                  catena, dal processo fino al firewall.
      prova       Esegue i controlli automatici del server.
      pannello    Apre nel browser l'elenco completo dei comandi dell'API.
      autoavvio   Lo fa partire da solo a ogni accesso a Windows.
                  Con -Rimuovi toglie l'avvio automatico.

    Senza comando, stampa questo aiuto.
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('stato', 'avvia', 'ferma', 'riavvia', 'log', 'scansiona',
                 'indirizzo', 'diagnostica', 'prova', 'pannello', 'autoavvio', 'aiuto')]
    [string]$Comando = 'aiuto',

    [switch]$Console,
    [switch]$Segui,
    [switch]$Forza,
    [switch]$Rimuovi
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$NOME_ATTIVITA = 'SpotiJugg'

# --- lettura della configurazione ------------------------------------------

function Leggi-Env {
    $valori = @{}
    if (-not (Test-Path '.env')) { return $valori }
    foreach ($riga in Get-Content '.env') {
        $pulita = $riga.Trim()
        if ($pulita -eq '' -or $pulita.StartsWith('#')) { continue }
        $taglio = $pulita.IndexOf('=')
        if ($taglio -lt 1) { continue }
        $chiave = $pulita.Substring(0, $taglio).Trim()
        $valore = $pulita.Substring($taglio + 1).Trim()
        $valori[$chiave] = $valore
    }
    return $valori
}

$CONFIGURAZIONE = Leggi-Env

function Porta {
    if ($CONFIGURAZIONE.ContainsKey('PORT') -and $CONFIGURAZIONE['PORT']) {
        return [int]$CONFIGURAZIONE['PORT']
    }
    return 8080
}

function Token {
    if ($CONFIGURAZIONE.ContainsKey('API_TOKEN')) { return $CONFIGURAZIONE['API_TOKEN'] }
    return ''
}

function CartellaDati {
    if ($CONFIGURAZIONE.ContainsKey('DATA_DIR') -and $CONFIGURAZIONE['DATA_DIR']) {
        return $CONFIGURAZIONE['DATA_DIR']
    }
    return './data'
}

# Due file, e non e' un capriccio: uvicorn scrive gli accessi HTTP sullo
# standard output e tutto il resto — avvio, scansioni, avvertimenti — sullo
# standard error. Tenerli separati e' l'unico modo che Windows offre di
# raccoglierli entrambi, e il secondo e' quello che si legge davvero.
function FileAccessi { return (Join-Path (CartellaDati) 'server-accessi.log') }
function FileEventi { return (Join-Path (CartellaDati) 'server-eventi.log') }

function IndirizziLan {
    # Solo le schede che hanno un gateway: le altre sono schede virtuali (VPN,
    # Hyper-V, WSL) che dal telefono non si vedono. Se il computer e' attaccato
    # sia via cavo sia in Wi-Fi gli indirizzi sono due, ed e' giusto mostrarli
    # entrambi: quale dei due risponda al telefono dipende dalla rete, non da
    # noi.
    $configurazioni = Get-NetIPConfiguration | Where-Object { $null -ne $_.IPv4DefaultGateway }
    $elenco = @()
    foreach ($configurazione in $configurazioni) {
        $elenco += [pscustomobject]@{
            Scheda = $configurazione.InterfaceAlias
            IP     = $configurazione.IPv4Address.IPAddress
        }
    }
    if ($elenco.Count -eq 0) {
        $elenco += [pscustomobject]@{ Scheda = 'nessuna'; IP = '127.0.0.1' }
    }
    return $elenco
}

function IndirizzoLan {
    return (IndirizziLan)[0].IP
}

# --- individuazione del processo -------------------------------------------

function Processi-Server {
    # Si cerca in due modi, e servono entrambi.
    #
    # Per porta: e' l'unica prova certa che qualcosa stia servendo. Cercare
    # solo per nome del programma non basta, perche' a seconda di come e' nato
    # il virtualenv l'eseguibile puo' chiamarsi python.exe o python3.11.exe.
    #
    # Per riga di comando: con il ricaricamento automatico uvicorn e' due
    # processi e in ascolto c'e' solo il figlio. Uccidendo quello, il padre lo
    # fa rinascere. La riga di comando pero' non e' sempre leggibile, quindi
    # da sola non basta nemmeno lei.
    $trovati = @()
    $visti = @()

    $connessioni = Get-NetTCPConnection -LocalPort (Porta) -State Listen -ErrorAction SilentlyContinue
    foreach ($connessione in $connessioni) {
        $processo = Get-CimInstance Win32_Process -Filter "ProcessId = $($connessione.OwningProcess)" -ErrorAction SilentlyContinue
        if ($null -ne $processo -and $visti -notcontains $processo.ProcessId) {
            $trovati += $processo
            $visti += $processo.ProcessId
        }
    }

    $perComando = Get-CimInstance Win32_Process -Filter "Name LIKE '%python%'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*uvicorn*app.main:app*' }
    foreach ($processo in $perComando) {
        if ($visti -notcontains $processo.ProcessId) {
            $trovati += $processo
            $visti += $processo.ProcessId
        }
    }

    return @($trovati)
}

function Chiama-Api {
    param([string]$Percorso, [string]$Metodo = 'Get')
    $indirizzo = "http://127.0.0.1:$(Porta)$Percorso"
    $intestazioni = @{ Authorization = "Bearer $(Token)" }
    return Invoke-RestMethod -Uri $indirizzo -Method $Metodo -Headers $intestazioni -TimeoutSec 15
}

function Durata-Leggibile {
    param([double]$Millisecondi)
    $t = [TimeSpan]::FromMilliseconds($Millisecondi)
    return "{0} ore e {1} minuti" -f [int]$t.TotalHours, $t.Minutes
}

# --- comandi ----------------------------------------------------------------

function Comando-Stato {
    $processi = Processi-Server
    if ($processi.Count -eq 0) {
        Write-Host "SPENTO" -ForegroundColor Red
        Write-Host "  Accendilo con:  .\gestisci.ps1 avvia"
        return
    }

    Write-Host "ACCESO" -ForegroundColor Green
    foreach ($p in $processi) {
        Write-Host ("  processo {0}, avviato {1}" -f $p.ProcessId, $p.CreationDate)
    }

    try {
        $salute = Invoke-RestMethod -Uri "http://127.0.0.1:$(Porta)/health" -TimeoutSec 5
    } catch {
        Write-Host "  ma non risponde ancora sulla porta $(Porta): sara' in fase di avvio." -ForegroundColor Yellow
        return
    }

    Write-Host ("  indirizzo per il telefono:  {0}:{1}" -f (IndirizzoLan), (Porta)) -ForegroundColor Cyan
    if (-not $salute.music_dir_exists) {
        Write-Host "  ATTENZIONE: la cartella della musica non esiste." -ForegroundColor Red
    }
    if ($salute.scanning) {
        Write-Host "  scansione in corso." -ForegroundColor Yellow
    }

    try {
        $dati = Chiama-Api '/api/v1/stats'
    } catch {
        Write-Host "  il token scritto nel .env non e' accettato dal server." -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host ("  {0} brani, {1} album, {2} artisti" -f $dati.tracks, $dati.albums, $dati.artists)
    Write-Host ("  durata totale: {0}" -f (Durata-Leggibile $dati.total_duration_ms))
    Write-Host ("  cartella: {0}" -f $dati.music_dir)
    if ($null -ne $dati.last_scan) {
        Write-Host ("  ultima scansione: {0}, esito {1}" -f $dati.last_scan.finished_at, $dati.last_scan.status)
    }
}

function Comando-Avvia {
    if ((Processi-Server).Count -gt 0) {
        Write-Host "Era gia' acceso." -ForegroundColor Yellow
        Comando-Stato
        return
    }

    $python = '.\.venv\Scripts\python.exe'
    if (-not (Test-Path $python)) {
        Write-Host "Manca il virtualenv: lo creo." -ForegroundColor Yellow
        & .\run.ps1 -Setup
        return
    }

    if ($Console) {
        Write-Host "In primo piano. Ctrl+C per fermare." -ForegroundColor Cyan
        & $python -m uvicorn app.main:app --host 0.0.0.0 --port (Porta) --reload
        return
    }

    $cartella = CartellaDati
    if (-not (Test-Path $cartella)) { New-Item -ItemType Directory -Force $cartella | Out-Null }

    # Senza --reload: in sottofondo il ricaricamento automatico non serve e
    # raddoppia i processi da inseguire quando si vuole spegnere.
    Start-Process -FilePath $python `
        -ArgumentList '-m', 'uvicorn', 'app.main:app', '--host', '0.0.0.0', '--port', "$(Porta)" `
        -WorkingDirectory $PSScriptRoot `
        -RedirectStandardOutput (FileAccessi) `
        -RedirectStandardError (FileEventi) `
        -WindowStyle Hidden

    Write-Host ("Avviato in sottofondo. Registro in {0}" -f (FileEventi)) -ForegroundColor Green
    Write-Host "Controlla fra qualche secondo con:  .\gestisci.ps1 stato"
}

function Comando-Ferma {
    $processi = Processi-Server
    if ($processi.Count -eq 0) {
        Write-Host "Era gia' spento."
        return
    }
    foreach ($p in $processi) {
        Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
        Write-Host ("Fermato il processo {0}." -f $p.ProcessId) -ForegroundColor Green
    }
}

function Comando-Log {
    $eventi = FileEventi
    if (-not (Test-Path $eventi)) {
        Write-Host "Nessun registro: il server non e' mai stato avviato in sottofondo." -ForegroundColor Yellow
        Write-Host "Avviandolo con -Console il registro compare direttamente a schermo."
        return
    }

    if ($Segui) {
        Write-Host "In ascolto sugli eventi. Ctrl+C per uscire." -ForegroundColor Cyan
        Get-Content $eventi -Tail 30 -Wait
        return
    }

    Write-Host "--- eventi del server ---" -ForegroundColor Cyan
    Get-Content $eventi -Tail 30

    $accessi = FileAccessi
    if (Test-Path $accessi) {
        Write-Host ""
        Write-Host "--- ultime richieste ricevute ---" -ForegroundColor Cyan
        Get-Content $accessi -Tail 10
    }
}

function Comando-Scansiona {
    if ((Processi-Server).Count -eq 0) {
        Write-Host "Il server e' spento: accendilo prima." -ForegroundColor Red
        return
    }
    $percorso = '/api/v1/scan'
    if ($Forza) { $percorso = '/api/v1/scan?force=true' }
    $esito = Chiama-Api $percorso 'Post'
    if ($esito.started) {
        Write-Host "Scansione avviata." -ForegroundColor Green
        Write-Host "Segui l'avanzamento con:  .\gestisci.ps1 log -Segui"
    } else {
        Write-Host "Ce n'era gia' una in corso." -ForegroundColor Yellow
    }
}

function Stato-Firewall {
    # Il server ascolta su tutte le schede, ma questo non basta: se il firewall
    # di Windows non lascia entrare la porta, dal computer si vede tutto e dal
    # telefono niente. E' la causa piu' frequente del "non trovo il server".
    #
    # Attenzione al terzo esito. Leggere le regole del firewall richiede i
    # privilegi di amministratore: senza, il comando non risponde "nessuna
    # regola", risponde "accesso negato". Scambiare le due cose significa
    # mandare qualcuno a caccia di un problema che potrebbe non esistere.
    param([int]$NumeroPorta)
    try {
        $filtri = Get-NetFirewallPortFilter -ErrorAction Stop |
            Where-Object { $_.Protocol -eq 'TCP' -and $_.LocalPort -eq "$NumeroPorta" }
    } catch {
        return [pscustomobject]@{ Esito = 'sconosciuto'; Regola = $null }
    }
    foreach ($filtro in $filtri) {
        $regola = $filtro | Get-NetFirewallRule -ErrorAction SilentlyContinue
        if ($null -ne $regola -and $regola.Enabled -eq 'True' -and
            $regola.Direction -eq 'Inbound' -and $regola.Action -eq 'Allow') {
            return [pscustomobject]@{ Esito = 'aperta'; Regola = $regola }
        }
    }
    return [pscustomobject]@{ Esito = 'chiusa'; Regola = $null }
}

function Mostra-Firewall {
    param([int]$NumeroPorta)
    $stato = Stato-Firewall $NumeroPorta

    if ($stato.Esito -eq 'aperta') {
        Write-Host ("Firewall: la porta {0} e' aperta (regola: {1})." -f $NumeroPorta, $stato.Regola.DisplayName) -ForegroundColor Green
        return
    }

    if ($stato.Esito -eq 'sconosciuto') {
        Write-Host "Firewall: non posso controllarlo da qui." -ForegroundColor Yellow
        Write-Host "Leggere le regole richiede i privilegi di amministratore."
        Write-Host "Riapri questa finestra come amministratore per saperlo,"
        Write-Host "oppure aggiungi la regola direttamente: non fa danno se c'e' gia'."
    } else {
        Write-Host ("Firewall: nessuna regola apre la porta {0}." -f $NumeroPorta) -ForegroundColor Yellow
        Write-Host "Dal computer il server si vede lo stesso, dal telefono no."
    }

    Write-Host ""
    Write-Host "Da un PowerShell come amministratore:"
    Write-Host ("  New-NetFirewallRule -DisplayName 'SpotiJugg' -Direction Inbound " +
                "-Protocol TCP -LocalPort {0} -Action Allow -Profile Private" -f $NumeroPorta) -ForegroundColor White
    Write-Host "Solo sul profilo Private: sulle reti pubbliche resta chiuso."
}

function Comando-Indirizzo {
    $porta = Porta
    $indirizzi = IndirizziLan
    Write-Host ""
    Write-Host "Nelle impostazioni dell'app sul telefono scrivi:" -ForegroundColor Cyan
    Write-Host ""
    foreach ($indirizzo in $indirizzi) {
        Write-Host ("  Server:  {0}:{1}   (scheda {2})" -f $indirizzo.IP, $porta, $indirizzo.Scheda) -ForegroundColor White
    }
    Write-Host ("  Token:   {0}" -f (Token)) -ForegroundColor White
    if ($indirizzi.Count -gt 1) {
        Write-Host ""
        Write-Host "Ci sono piu' indirizzi perche' il computer e' attaccato a piu' reti."
        Write-Host "Prova il primo; se non va, prova il secondo."
    }
    Write-Host ""
    Write-Host "Telefono e computer devono stare sulla stessa rete Wi-Fi."
    Write-Host "L'indirizzo cambia se il router riassegna gli IP: se un giorno"
    Write-Host "l'app non vede piu' il server, ricontrolla qui."
    Write-Host ""
    Mostra-Firewall $porta
}

function Comando-Diagnostica {
    $porta = Porta
    Write-Host ""
    Write-Host "=== 1. Il server e' acceso? ===" -ForegroundColor Cyan
    $processi = Processi-Server
    if ($processi.Count -eq 0) {
        Write-Host "NO. Accendilo con:  .\gestisci.ps1 avvia" -ForegroundColor Red
        return
    }
    foreach ($p in $processi) {
        Write-Host ("  si': processo {0} ({1})" -f $p.ProcessId, $p.Name) -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "=== 2. Su quali indirizzi ascolta? ===" -ForegroundColor Cyan
    $ascolti = Get-NetTCPConnection -LocalPort $porta -State Listen -ErrorAction SilentlyContinue
    if ($null -eq $ascolti) {
        Write-Host ("  nessuno sulla porta {0}." -f $porta) -ForegroundColor Red
    }
    foreach ($ascolto in $ascolti) {
        $nota = ''
        if ($ascolto.LocalAddress -eq '127.0.0.1') {
            $nota = '  <-- SOLO in locale: il telefono non arriverebbe mai'
        }
        Write-Host ("  {0}:{1}{2}" -f $ascolto.LocalAddress, $ascolto.LocalPort, $nota)
    }

    Write-Host ""
    Write-Host "=== 3. Risponde? ===" -ForegroundColor Cyan
    foreach ($indirizzo in IndirizziLan) {
        try {
            Invoke-RestMethod ("http://{0}:{1}/health" -f $indirizzo.IP, $porta) -TimeoutSec 5 | Out-Null
            Write-Host ("  {0} risponde" -f $indirizzo.IP) -ForegroundColor Green
        } catch {
            Write-Host ("  {0} NON risponde" -f $indirizzo.IP) -ForegroundColor Red
        }
    }
    Write-Host "  (queste prove partono dal computer stesso: non attraversano"
    Write-Host "   il firewall, quindi non dicono niente su cosa vede il telefono)"

    Write-Host ""
    Write-Host "=== 4. Il firewall ===" -ForegroundColor Cyan
    Mostra-Firewall $porta

    Write-Host ""
    Write-Host "=== 5. Il telefono e' mai arrivato fin qui? ===" -ForegroundColor Cyan
    $accessi = FileAccessi
    if (-not (Test-Path $accessi)) {
        Write-Host "  registro assente: il server non e' stato avviato con questo script." -ForegroundColor Yellow
    } else {
        $miei = @('127.0.0.1') + (IndirizziLan | ForEach-Object { $_.IP })
        $righe = Get-Content $accessi -Tail 400
        $esterne = @()
        foreach ($riga in $righe) {
            $trovato = [regex]::Match($riga, '(\d+\.\d+\.\d+\.\d+):\d+')
            if ($trovato.Success -and $miei -notcontains $trovato.Groups[1].Value) {
                $esterne += $riga
            }
        }
        if ($esterne.Count -eq 0) {
            Write-Host "  MAI. Nessuna richiesta da un altro dispositivo." -ForegroundColor Red
            Write-Host "  Il problema sta fra il telefono e questo computer:"
            Write-Host "  firewall, rete sbagliata, o indirizzo scritto male nell'app."
            Write-Host "  Prova cosi': apri Safari sul telefono e vai su"
            Write-Host ("    http://{0}:{1}/health" -f (IndirizzoLan), $porta) -ForegroundColor White
            Write-Host "  Se non si apre, e' rete. Se si apre, e' l'app o il token."
        } else {
            Write-Host ("  si': {0} richieste da fuori. Ultime:" -f $esterne.Count) -ForegroundColor Green
            $esterne | Select-Object -Last 5 | ForEach-Object { Write-Host "    $_" }
        }
    }
}

function Comando-Prova {
    $python = '.\.venv\Scripts\python.exe'
    if (-not (Test-Path $python)) {
        Write-Host "Manca il virtualenv: esegui  .\run.ps1 -Setup" -ForegroundColor Red
        return
    }
    & $python tests\smoke_test.py
}

function Comando-Pannello {
    $indirizzo = "http://127.0.0.1:$(Porta)/docs"
    Write-Host "Apro $indirizzo" -ForegroundColor Cyan
    Write-Host "E' l'elenco completo dei comandi dell'API, provabili dal browser."
    Write-Host "Per quelli protetti serve il token: .\gestisci.ps1 indirizzo"
    Start-Process $indirizzo
}

function Comando-Autoavvio {
    if ($Rimuovi) {
        try {
            Unregister-ScheduledTask -TaskName $NOME_ATTIVITA -Confirm:$false -ErrorAction Stop
            Write-Host "Avvio automatico rimosso." -ForegroundColor Green
        } catch {
            Write-Host "Non era impostato." -ForegroundColor Yellow
        }
        return
    }

    $argomenti = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$PSScriptRoot\gestisci.ps1`" avvia"
    $azione = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $argomenti -WorkingDirectory $PSScriptRoot
    $innesco = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $opzioni = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -AllowStartIfOnBatteries

    Register-ScheduledTask -TaskName $NOME_ATTIVITA -Action $azione -Trigger $innesco `
        -Settings $opzioni -Description 'Avvia il server musicale SpotiJugg' -Force | Out-Null

    Write-Host "Fatto: il server partira' da solo a ogni accesso a Windows." -ForegroundColor Green
    Write-Host "Per toglierlo:  .\gestisci.ps1 autoavvio -Rimuovi"
}

function Comando-Aiuto {
    Get-Help $PSCommandPath -Detailed
}

switch ($Comando) {
    'stato'     { Comando-Stato }
    'avvia'     { Comando-Avvia }
    'ferma'     { Comando-Ferma }
    'riavvia'   { Comando-Ferma; Start-Sleep -Seconds 2; Comando-Avvia }
    'log'       { Comando-Log }
    'scansiona' { Comando-Scansiona }
    'indirizzo' { Comando-Indirizzo }
    'diagnostica' { Comando-Diagnostica }
    'prova'     { Comando-Prova }
    'pannello'  { Comando-Pannello }
    'autoavvio' { Comando-Autoavvio }
    default     { Comando-Aiuto }
}
