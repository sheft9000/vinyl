from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.repositories import library as repo
from app.schemas import ScanStatusOut, StatsOut
from app.security import require_admin
from app.services import scanner

router = APIRouter(dependencies=[Depends(require_admin)], tags=["amministrazione"])


@router.get("/stats", response_model=StatsOut)
def stats(db: Session = Depends(get_db)) -> StatsOut:
    artists, albums, tracks, duration = repo.library_totals(db)
    return StatsOut(
        artists=artists,
        albums=albums,
        tracks=tracks,
        total_duration_ms=duration,
        music_dir=str(settings.music_dir),
        music_dir_exists=settings.music_dir.is_dir(),
        last_scan=repo.last_scan(db),
    )


@router.post("/scan", response_model=dict)
def start_scan(force: bool = False) -> dict:
    """Avvia una scansione in background.

    `force=true` rilegge i tag di tutti i file anche se non sono cambiati:
    serve dopo aver ritaggato la libreria dall'esterno.
    """
    started = scanner.request_scan(force=force)
    return {"started": started, "already_running": not started}


@router.get("/scan/status", response_model=ScanStatusOut)
def scan_status(db: Session = Depends(get_db)) -> ScanStatusOut:
    last = repo.last_scan(db)
    if last is None:
        return ScanStatusOut(status="idle")
    if scanner.is_scanning():
        last.status = "running"
    return last
