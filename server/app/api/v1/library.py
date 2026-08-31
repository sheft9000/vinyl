from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.models import User
from app.repositories import library as repo
from app.schemas import (
    AlbumOut,
    ArtistOut,
    GenreOut,
    Page,
    SearchOut,
    TrackOut,
    UserOut,
)
from app.security import get_current_user

router = APIRouter(dependencies=[Depends(get_current_user)])


@router.get("/me", response_model=UserOut, tags=["account"])
def me(user: User = Depends(get_current_user)) -> UserOut:
    return UserOut.model_validate(user)


# --------------------------------------------------------------------------- artisti


@router.get("/artists", response_model=Page[ArtistOut], tags=["libreria"])
def get_artists(
    q: str | None = None,
    offset: int = 0,
    limit: int = Query(default=100, le=500),
    db: Session = Depends(get_db),
) -> Page[ArtistOut]:
    items, total = repo.list_artists(db, q=q, offset=offset, limit=limit)
    return Page(items=items, total=total, offset=offset, limit=limit)


@router.get("/artists/{artist_id}", response_model=ArtistOut, tags=["libreria"])
def get_artist(artist_id: int, db: Session = Depends(get_db)) -> ArtistOut:
    artist = repo.get_artist(db, artist_id)
    if artist is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "artista non trovato")
    return artist


@router.get("/artists/{artist_id}/albums", response_model=Page[AlbumOut], tags=["libreria"])
def get_artist_albums(
    artist_id: int,
    offset: int = 0,
    limit: int = Query(default=100, le=500),
    db: Session = Depends(get_db),
) -> Page[AlbumOut]:
    items, total = repo.list_albums(
        db, artist_id=artist_id, sort="year", offset=offset, limit=limit
    )
    return Page(items=items, total=total, offset=offset, limit=limit)


# ---------------------------------------------------------------------------- album


@router.get("/albums", response_model=Page[AlbumOut], tags=["libreria"])
def get_albums(
    q: str | None = None,
    artist_id: int | None = None,
    sort: str = Query(default="title", pattern="^(title|recent|year|artist)$"),
    offset: int = 0,
    limit: int = Query(default=100, le=500),
    db: Session = Depends(get_db),
) -> Page[AlbumOut]:
    items, total = repo.list_albums(
        db, artist_id=artist_id, q=q, sort=sort, offset=offset, limit=limit
    )
    return Page(items=items, total=total, offset=offset, limit=limit)


@router.get("/albums/{album_id}", response_model=AlbumOut, tags=["libreria"])
def get_album(album_id: int, db: Session = Depends(get_db)) -> AlbumOut:
    album = repo.get_album(db, album_id)
    if album is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "album non trovato")
    return album


@router.get("/albums/{album_id}/tracks", response_model=Page[TrackOut], tags=["libreria"])
def get_album_tracks(album_id: int, db: Session = Depends(get_db)) -> Page[TrackOut]:
    items, total = repo.list_tracks(db, album_id=album_id, limit=500)
    return Page(items=items, total=total, offset=0, limit=500)


# ---------------------------------------------------------------------------- brani


@router.get("/tracks", response_model=Page[TrackOut], tags=["libreria"])
def get_tracks(
    q: str | None = None,
    album_id: int | None = None,
    artist_id: int | None = None,
    genre: str | None = None,
    sort: str = Query(default="added", pattern="^(added|title|album)$"),
    offset: int = 0,
    limit: int = Query(default=100, le=500),
    db: Session = Depends(get_db),
) -> Page[TrackOut]:
    items, total = repo.list_tracks(
        db,
        album_id=album_id,
        artist_id=artist_id,
        genre=genre,
        q=q,
        sort=sort,
        offset=offset,
        limit=limit,
    )
    return Page(items=items, total=total, offset=offset, limit=limit)


@router.get("/tracks/random", response_model=list[TrackOut], tags=["libreria"])
def get_random_tracks(
    limit: int = Query(default=200, le=500), db: Session = Depends(get_db)
) -> list[TrackOut]:
    """Coda gia' mescolata dal server: e' il modo piu' economico di fare
    shuffle su tutta la libreria senza scaricarla tutta sul telefono."""
    return repo.random_tracks(db, limit=limit)


# ------------------------------------------------------------------- generi, ricerca


@router.get("/genres", response_model=list[GenreOut], tags=["libreria"])
def get_genres(db: Session = Depends(get_db)) -> list[GenreOut]:
    return repo.list_genres(db)


@router.get("/search", response_model=SearchOut, tags=["libreria"])
def search(
    q: str = Query(min_length=1),
    limit: int = Query(default=20, le=100),
    db: Session = Depends(get_db),
) -> SearchOut:
    artists, _ = repo.list_artists(db, q=q, limit=limit)
    albums, _ = repo.list_albums(db, q=q, limit=limit)
    tracks, _ = repo.list_tracks(db, q=q, sort="title", limit=limit)
    return SearchOut(artists=artists, albums=albums, tracks=tracks)
