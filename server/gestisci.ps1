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
      prova       Esegue i controlli automatici del server.
      pannello    Apre nel browser l'elenco completo dei comandi dell'API.
      autoavvio   Lo fa partire da solo a ogni accesso a Windows.
                  Con -Rimuovi toglie l'avvio automatico.

    Senza comando, stampa questo aiuto.
#>
param(
    [Parameter(Position = 0)]
    [ValidateSet('stato', 'avvia', 'ferma', 'riavvia', 'log', 'scansiona',
                 'indirizzo', 'prova', 'pannello', 'autoavvio', 'aiuto')]
    [string]$Comando = 'aiuto',

    [switch]$Console,
    [switch]$Segui,
    [switch]$Forza,
    [switch]$Rimuovi
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

$NOME_ATTIVITA = 'SpotiJugg - server musicale'

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

function IndirizzoLan {
    # L'indirizzo giusto e' quello della scheda che ha un gateway: le altre sono
    # schede virtuali (VPN, Hyper-V, WSL) che dal telefono non si vedono.
    $configurazioni = Get-NetIPConfiguration | Where-Object { $null -ne $_.IPv4DefaultGateway }
    $prima = $configurazioni | Select-Object -First 1
    if ($null -eq $prima) { return '127.0.0.1' }
    return $prima.IPv4Address.IPAddress
}

# --- individuazione del processo -------------------------------------------

function Processi-Server {
    # Cercare per porta troverebbe solo il figlio: con il ricaricamento
    # automatico uvicorn e' due processi, e uccidendo il figlio il padre lo fa
    # rinascere. Si cerca quindi per riga di comando.
    $trovati = Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*uvicorn*app.main:app*' }
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

function Regola-Firewall {
    # Il server ascolta su tutte le schede, ma questo non basta: se il firewall
    # di Windows non lascia entrare la porta, dal computer si vede tutto e dal
    # telefono niente. E' la causa piu' frequente del "non trovo il server".
    param([int]$NumeroPorta)
    try {
        $filtri = Get-NetFirewallPortFilter -ErrorAction Stop |
            Where-Object { $_.Protocol -eq 'TCP' -and $_.LocalPort -eq "$NumeroPorta" }
    } catch {
        return $null
    }
    foreach ($filtro in $filtri) {
        $regola = $filtro | Get-NetFirewallRule -ErrorAction SilentlyContinue
        if ($null -ne $regola -and $regola.Enabled -eq 'True' -and
            $regola.Direction -eq 'Inbound' -and $regola.Action -eq 'Allow') {
            return $regola
        }
    }
    return $null
}

function Comando-Indirizzo {
    $ip = IndirizzoLan
    $porta = Porta
    Write-Host ""
    Write-Host "Nelle impostazioni dell'app sul telefono scrivi:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("  Server:  {0}:{1}" -f $ip, $porta) -ForegroundColor White
    Write-Host ("  Token:   {0}" -f (Token)) -ForegroundColor White
    Write-Host ""
    Write-Host "Telefono e computer devono stare sulla stessa rete Wi-Fi."
    Write-Host "L'indirizzo cambia se il router riassegna gli IP: se un giorno"
    Write-Host "l'app non vede piu' il server, ricontrolla qui."

    Write-Host ""
    $regola = Regola-Firewall $porta
    if ($null -ne $regola) {
        Write-Host ("Firewall: la porta {0} e' aperta (regola: {1})." -f $porta, $regola.DisplayName) -ForegroundColor Green
        return
    }

    Write-Host ("Firewall: non trovo nessuna regola che apra la porta {0}." -f $porta) -ForegroundColor Yellow
    Write-Host "Dal computer il server si vede lo stesso, dal telefono no."
    Write-Host "Apri PowerShell come amministratore e incolla questa riga:"
    Write-Host ""
    Write-Host ("  New-NetFirewallRule -DisplayName 'SpotiJugg' -Direction Inbound " +
                "-Protocol TCP -LocalPort {0} -Action Allow -Profile Private" -f $porta) -ForegroundColor White
    Write-Host ""
    Write-Host "Solo sul profilo Private: sulle reti pubbliche resta chiuso."
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
    'prova'     { Comando-Prova }
    'pannello'  { Comando-Pannello }
    'autoavvio' { Comando-Autoavvio }
    default     { Comando-Aiuto }
}
