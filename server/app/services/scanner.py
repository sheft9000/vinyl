from __future__ import annotations

import logging
import os
import threading
from datetime import datetime, timezone
from pathlib import Path

from sqlalchemy import delete, select
from sqlalchemy.orm import Session

from app.config import settings
from app.db import SessionLocal
from app.models import Album, Artist, ScanRun, Track
from app.services.artwork import store_picture
from app.services.metadata import (
    AUDIO_EXTS,
    extract_embedded_picture,
    find_folder_cover,
    infer_from_path,
    read_tags,
)
from app.utils.text import clean, normalize

log = logging.getLogger(__name__)

_lock = threading.Lock()

# Cartelle di servizio che non contengono mai musica.
_SKIP_DIRS = {
    "$recycle.bin",
    "system volume information",
    ".git",
    "@eadir",
    ".stfolder",
    "__macosx",
}

_COMMIT_EVERY = 200


def is_scanning() -> bool:
    return _lock.locked()


def request_scan(force: bool = False) -> bool:
    """Avvia una scansione in background. False se ce n'e' gia' una in corso."""
    if _lock.locked():
        return False
    thread = threading.Thread(
        target=run_scan, kwargs={"force": force}, daemon=True, name="vinyl-scan"
    )
    thread.start()
    return True


def run_scan(force: bool = False) -> dict:
    if not _lock.acquire(blocking=False):
        return {"status": "already_running"}
    try:
        with SessionLocal() as db:
            return _scan(db, force=force)
    except Exception as exc:  # una scansione fallita non deve mai far cadere il server
        log.exception("scansione fallita")
        return {"status": "error", "error": str(exc)}
    finally:
        _lock.release()


def _iter_audio_files(root: Path):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d for d in dirnames if d.lower() not in _SKIP_DIRS and not d.startswith(".")
        ]
        for name in filenames:
            if name.startswith("."):
                continue
            if os.path.splitext(name)[1].lower() in AUDIO_EXTS:
                yield Path(dirpath) / name


def _get_artist(db: Session, cache: dict[str, Artist], name: str | None) -> Artist:
    name = clean(name) or "Artista sconosciuto"
    key = name.lower()
    artist = cache.get(key)
    if artist is not None:
        return artist

    artist = db.scalar(select(Artist).where(Artist.name == name))
    if artist is None:
        artist = Artist(name=name, search_text=normalize(name))
        db.add(artist)
        db.flush()
    cache[key] = artist
    return artist


def _get_album(
    db: Session,
    cache: dict[tuple[int, str], Album],
    title: str | None,
    artist: Artist,
    year: int | None,
) -> Album:
    title = clean(title) or "Album sconosciuto"
    key = (artist.id, title.lower())
    album = cache.get(key)
    if album is not None:
        return album

    album = db.scalar(
        select(Album).where(Album.artist_id == artist.id, Album.title == title)
    )
    if album is None:
        album = Album(
            title=title,
            artist_id=artist.id,
            year=year,
            search_text=normalize(title, artist.name),
        )
        db.add(album)
        db.flush()
    elif album.year is None and year is not None:
        album.year = year
    cache[key] = album
    return album


def _scan(db: Session, force: bool) -> dict:
    root = settings.music_dir
    run = ScanRun(started_at=datetime.now(timezone.utc))
    db.add(run)
    db.commit()

    if not root.is_dir():
        run.status = "error"
        run.error = f"MUSIC_DIR non esiste: {root}"
        run.finished_at = datetime.now(timezone.utc)
        db.commit()
        log.warning(run.error)
        return {"status": "error", "error": run.error}

    log.info("scansione di %s (force=%s)", root, force)

    # Foto della libreria attuale: una sola query invece di una per file.
    existing: dict[str, tuple[int, float, int, bool]] = {
        row[1]: (row[0], row[2], row[3], row[4])
        for row in db.execute(
            select(Track.id, Track.path, Track.mtime, Track.size, Track.missing)
        ).all()
    }

    artist_cache: dict[str, Artist] = {}
    album_cache: dict[tuple[int, str], Album] = {}
    folder_art_cache: dict[str, str | None] = {}

    seen: set[str] = set()
    added = updated = files_seen = 0

    for file in _iter_audio_files(root):
        path_str = str(file)
        seen.add(path_str)
        files_seen += 1

        try:
            stat = file.stat()
        except OSError:
            continue

        known = existing.get(path_str)
        unchanged = (
            known is not None
            and abs(known[1] - stat.st_mtime) < 1.0
            and known[2] == stat.st_size
        )
        if unchanged and not force:
            if known[3]:  # era marcato come sparito, ma il file e' tornato
                track = db.get(Track, known[0])
                if track:
                    track.missing = False
            continue

        tags = read_tags(file)
        if tags is None:
            continue

        artist_name = tags.artist
        album_artist_name = tags.album_artist
        album_name = tags.album
        title = tags.title

        # I tag veri vincono sempre. Solo cio' che manca viene dedotto dal
        # percorso, e solo se il ripiego e' acceso.
        if settings.infer_tags_from_path and (
            artist_name is None or album_name is None or title is None
        ):
            guessed_artist, guessed_album, guessed_title = infer_from_path(file, root)
            artist_name = artist_name or guessed_artist
            album_artist_name = album_artist_name or guessed_artist
            album_name = album_name or guessed_album
            title = title or guessed_title

        artist = _get_artist(db, artist_cache, artist_name)
        album_artist = _get_artist(db, artist_cache, album_artist_name or artist_name)
        album = _get_album(db, album_cache, album_name, album_artist, tags.year)

        if album.art_key is None:
            art_key = store_picture(extract_embedded_picture(file))
            if art_key is None:
                folder = str(file.parent)
                if folder not in folder_art_cache:
                    folder_art_cache[folder] = store_picture(find_folder_cover(file.parent))
                art_key = folder_art_cache[folder]
            album.art_key = art_key

        track = db.get(Track, known[0]) if known else Track(path=path_str)
        if track is None:
            continue

        try:
            track.rel_path = str(file.relative_to(root))
        except ValueError:
            track.rel_path = file.name
        track.ext = file.suffix.lower()
        track.size = stat.st_size
        track.mtime = stat.st_mtime
        track.title = clean(title) or file.stem
        track.artist_id = artist.id
        track.album_id = album.id
        track.track_no = tags.track_no
        track.disc_no = tags.disc_no
        track.year = tags.year or album.year
        track.genre = clean(tags.genre, 128)
        track.duration_ms = tags.duration_ms
        track.bitrate = tags.bitrate
        track.sample_rate = tags.sample_rate
        track.art_key = album.art_key
        track.search_text = normalize(track.title, artist.name, album.title)
        track.missing = False
        track.updated_at = datetime.now(timezone.utc)

        if known:
            updated += 1
        else:
            db.add(track)
            added += 1

        if (added + updated) % _COMMIT_EVERY == 0:
            db.commit()

    db.commit()

    # I file spariti restano nel DB, solo marcati: staccare un disco esterno
    # non deve cancellarti la libreria.
    removed = 0
    for path_str, (track_id, _mtime, _size, was_missing) in existing.items():
        if path_str not in seen and not was_missing:
            track = db.get(Track, track_id)
            if track:
                track.missing = True
                removed += 1
    db.commit()

    _prune_empty(db)

    run.status = "ok"
    run.files_seen = files_seen
    run.added = added
    run.updated = updated
    run.removed = removed
    run.finished_at = datetime.now(timezone.utc)
    db.commit()

    log.info(
        "scansione completata: %s file, +%s nuovi, %s aggiornati, %s spariti",
        files_seen,
        added,
        updated,
        removed,
    )
    return {
        "status": "ok",
        "files_seen": files_seen,
        "added": added,
        "updated": updated,
        "removed": removed,
    }


def _prune_empty(db: Session) -> None:
    """Album e artisti rimasti senza brani: residui di file rinominati o rimossi."""
    used_albums = select(Track.album_id).where(Track.album_id.is_not(None))
    db.execute(delete(Album).where(Album.id.not_in(used_albums)))

    used_by_tracks = select(Track.artist_id).where(Track.artist_id.is_not(None))
    used_by_albums = select(Album.artist_id)
    db.execute(
        delete(Artist).where(
            Artist.id.not_in(used_by_tracks), Artist.id.not_in(used_by_albums)
        )
    )
    db.commit()
