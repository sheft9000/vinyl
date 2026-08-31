# Avvio del server in sviluppo.
#   .\run.ps1          -> avvia con reload automatico
#   .\run.ps1 -Setup   -> ricrea il virtualenv e installa le dipendenze
param([switch]$Setup)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if ($Setup -or -not (Test-Path ".venv")) {
    Write-Host "==> Creo il virtualenv..." -ForegroundColor Cyan
    py -3 -m venv .venv
    & .\.venv\Scripts\python.exe -m pip install --upgrade pip
    & .\.venv\Scripts\python.exe -m pip install -r requirements.txt
}

if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "==> Creato .env da .env.example. Apri il file e imposta MUSIC_DIR e API_TOKEN." -ForegroundColor Yellow
}

& .\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
