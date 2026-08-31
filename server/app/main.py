from __future__ import annotations

import logging
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse

from app.api.v1.router import api_router
from app.config import settings
from app.db import SessionLocal, init_db
from app.security import ensure_primary_user
from app.services import scanner
from app.services.watcher import start_watcher, stop_watcher

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-7s %(name)s: %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("vinyl")

WEB_DIR = Path(__file__).parent / "web"


@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    with SessionLocal() as db:
        ensure_primary_user(db)

    log.info("libreria: %s", settings.music_dir)
    if not settings.music_dir.is_dir():
        log.warning(
            "MUSIC_DIR non esiste ancora. Il server parte lo stesso: "
            "imposta il percorso in .env e riavvia."
        )

    if settings.scan_on_startup:
        scanner.request_scan()

    observer = start_watcher()
    try:
        yield
    finally:
        stop_watcher(observer)


app = FastAPI(
    title=f"{settings.app_name} API",
    version="0.1.0",
    summary="Server di streaming per la libreria musicale personale.",
    lifespan=lifespan,
)

# In LAN e in sviluppo il client puo' essere il browser, l'emulatore Android o
# il telefono: l'origine cambia continuamente e non aggiunge sicurezza qui,
# perche' l'accesso e' comunque protetto dal token.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["Content-Range", "Accept-Ranges", "Content-Length"],
)

app.include_router(api_router)


@app.get("/health", tags=["servizio"])
def health() -> JSONResponse:
    """Senza token: serve a verificare da un altro device che il server risponda."""
    return JSONResponse(
        {
            "status": "ok",
            "app": settings.app_name,
            "music_dir_exists": settings.music_dir.is_dir(),
            "scanning": scanner.is_scanning(),
        }
    )


if settings.dev_web_player:

    @app.get("/", include_in_schema=False)
    def dev_player() -> FileResponse:
        return FileResponse(WEB_DIR / "index.html")
