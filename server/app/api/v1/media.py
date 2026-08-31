from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from app.db import get_db
from app.repositories import library as repo
from app.security import get_current_user
from app.services.artwork import VARIANTS, artwork_path
from app.services.streaming import build_audio_response

router = APIRouter(dependencies=[Depends(get_current_user)], tags=["media"])


@router.get("/tracks/{track_id}/stream")
@router.head("/tracks/{track_id}/stream")
def stream_track(
    track_id: int, request: Request, db: Session = Depends(get_db)
) -> Response:
    track = repo.get_track_file(db, track_id)
    if track is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "brano non trovato")
    return build_audio_response(
        Path(track.path),
        request.headers.get("Range"),
        head=request.method == "HEAD",
    )


@router.get("/artwork/{art_key}")
def get_artwork(
    art_key: str,
    size: str = Query(default="thumb", pattern="^(thumb|full)$"),
) -> Response:
    if not art_key.isalnum():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "chiave copertina non valida")
    if size not in VARIANTS:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "misura non valida")

    path = artwork_path(art_key, size)
    if not path.is_file():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "copertina non trovata")

    # La chiave e' l'hash del contenuto: il file a quella chiave non cambiera'
    # mai, quindi il client puo' tenerlo in cache per sempre.
    return FileResponse(
        path,
        media_type="image/jpeg",
        headers={"Cache-Control": "public, max-age=31536000, immutable"},
    )
