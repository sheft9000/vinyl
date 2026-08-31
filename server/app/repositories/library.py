from __future__ import annotations

from sqlalchemy import Select, func, select
from sqlalchemy.orm import Session

from app.models import Album, Artist, ScanRun, Track
from app.schemas import AlbumOut, ArtistOut, GenreOut, ScanStatusOut, TrackOut
from app.utils.text import normalize

# Un brano il cui file e' sparito resta nel database ma non deve mai comparire
# nelle liste: questo filtro e' l'unico posto in cui la regola e' scritta.
_VISIBLE = Track.missing.is_(False)

# Nascondere i brani spariti non basta: album e artisti restavano in elenco
# anche quando *tutti* i loro brani erano spariti, con tanto di copertina.
# Cambiando la cartella della musica si otteneva cosi' una libreria fatta di
# sole copertine vecchie e nessun brano. Un album esiste finche' ha almeno un
# brano che si puo' ascoltare.
#
# Si filtra invece di cancellare: se un disco esterno e' staccato i file
# risultano spariti, e cancellare l'anagrafica vorrebbe dire perdere anche le
# copertine gia' ritagliate. Riattaccando il disco tutto ricompare da solo.
_ALBUM_ASCOLTABILE = Album.id.in_(
    select(Track.album_id).where(_VISIBLE, Track.album_id.is_not(None))
)
_ARTISTA_ASCOLTABILE = Artist.id.in_(
    select(Track.artist_id).where(_VISIBLE, Track.artist_id.is_not(None))
)


def _like(q: str) -> str:
    return f"%{normalize(q)}%"


def _count_of(stmt: Select, db: Session) -> int:
    return db.scalar(select(func.count()).select_from(stmt.subquery())) or 0


# --------------------------------------------------------------------------- artisti


def _artist_columns():
    albums = (
        select(func.count(Album.id))
        .where(Album.artist_id == Artist.id)
        .correlate(Artist)
        .scalar_subquery()
    )
    tracks = (
        select(func.count(Track.id))
        .where(Track.artist_id == Artist.id, _VISIBLE)
        .correlate(Artist)
        .scalar_subquery()
    )
    art = (
        select(Album.art_key)
        .where(Album.artist_id == Artist.id, Album.art_key.is_not(None))
        .limit(1)
        .correlate(Artist)
        .scalar_subquery()
    )
    return select(Artist.id, Artist.name, albums, tracks, art)


def _to_artist(row) -> ArtistOut:
    return ArtistOut(
        id=row[0], name=row[1], album_count=row[2], track_count=row[3], art_key=row[4]
    )


def list_artists(
    db: Session, q: str | None = None, offset: int = 0, limit: int = 100
) -> tuple[list[ArtistOut], int]:
    stmt = _artist_columns().where(_ARTISTA_ASCOLTABILE)
    if q:
        stmt = stmt.where(Artist.search_text.like(_like(q)))
    total = _count_of(stmt, db)
    rows = db.execute(stmt.order_by(Artist.search_text).offset(offset).limit(limit)).all()
    return [_to_artist(r) for r in rows], total


def get_artist(db: Session, artist_id: int) -> ArtistOut | None:
    row = db.execute(_artist_columns().where(Artist.id == artist_id)).first()
    return _to_artist(row) if row else None


# ---------------------------------------------------------------------------- album


def _album_columns():
    tracks = (
        select(func.count(Track.id))
        .where(Track.album_id == Album.id, _VISIBLE)
        .correlate(Album)
        .scalar_subquery()
    )
    duration = (
        select(func.coalesce(func.sum(Track.duration_ms), 0))
        .where(Track.album_id == Album.id, _VISIBLE)
        .correlate(Album)
        .scalar_subquery()
    )
    return (
        select(
            Album.id,
            Album.title,
            Album.artist_id,
            Artist.name,
            Album.year,
            Album.art_key,
            tracks,
            duration,
        )
        .join(Artist, Artist.id == Album.artist_id)
    )


def _to_album(row) -> AlbumOut:
    return AlbumOut(
        id=row[0],
        title=row[1],
        artist_id=row[2],
        artist_name=row[3],
        year=row[4],
        art_key=row[5],
        track_count=row[6],
        duration_ms=row[7],
    )


def list_albums(
    db: Session,
    artist_id: int | None = None,
    q: str | None = None,
    sort: str = "title",
    offset: int = 0,
    limit: int = 100,
) -> tuple[list[AlbumOut], int]:
    stmt = _album_columns().where(_ALBUM_ASCOLTABILE)
    if artist_id is not None:
        stmt = stmt.where(Album.artist_id == artist_id)
    if q:
        stmt = stmt.where(Album.search_text.like(_like(q)))

    total = _count_of(stmt, db)

    order = {
        "title": (Album.search_text.asc(),),
        "recent": (Album.added_at.desc(), Album.id.desc()),
        "year": (Album.year.desc().nulls_last(), Album.search_text.asc()),
        "artist": (Artist.search_text.asc(), Album.year.asc().nulls_last()),
    }.get(sort, (Album.search_text.asc(),))

    rows = db.execute(stmt.order_by(*order).offset(offset).limit(limit)).all()
    return [_to_album(r) for r in rows], total


def get_album(db: Session, album_id: int) -> AlbumOut | None:
    row = db.execute(_album_columns().where(Album.id == album_id)).first()
    return _to_album(row) if row else None


# ---------------------------------------------------------------------------- brani

def _track_columns():
    return (
        select(
            Track.id,
            Track.title,
            Track.artist_id,
            Artist.name,
            Track.album_id,
            Album.title,
            Track.track_no,
            Track.disc_no,
            Track.year,
            Track.genre,
            Track.duration_ms,
            Track.ext,
            Track.art_key,
        )
        .join(Artist, Artist.id == Track.artist_id, isouter=True)
        .join(Album, Album.id == Track.album_id, isouter=True)
        .where(_VISIBLE)
    )


def _to_track(row) -> TrackOut:
    return TrackOut(
        id=row[0],
        title=row[1],
        artist_id=row[2],
        artist_name=row[3] or "",
        album_id=row[4],
        album_title=row[5] or "",
        track_no=row[6],
        disc_no=row[7],
        year=row[8],
        genre=row[9],
        duration_ms=row[10],
        ext=row[11] or "",
        art_key=row[12],
    )


def list_tracks(
    db: Session,
    album_id: int | None = None,
    artist_id: int | None = None,
    genre: str | None = None,
    q: str | None = None,
    sort: str = "added",
    offset: int = 0,
    limit: int = 100,
) -> tuple[list[TrackOut], int]:
    stmt = _track_columns()
    if album_id is not None:
        stmt = stmt.where(Track.album_id == album_id)
        sort = "album"
    if artist_id is not None:
        stmt = stmt.where(Track.artist_id == artist_id)
    if genre:
        stmt = stmt.where(Track.genre == genre)
    if q:
        stmt = stmt.where(Track.search_text.like(_like(q)))

    total = _count_of(stmt, db)

    order = {
        "album": (
            Track.disc_no.asc().nulls_first(),
            Track.track_no.asc().nulls_last(),
            Track.title.asc(),
        ),
        "added": (Track.added_at.desc(), Track.id.desc()),
        "title": (Track.search_text.asc(),),
    }.get(sort, (Track.added_at.desc(),))

    rows = db.execute(stmt.order_by(*order).offset(offset).limit(limit)).all()
    return [_to_track(r) for r in rows], total


def random_tracks(db: Session, limit: int = 200) -> list[TrackOut]:
    """Coda casuale: lo shuffle globale della libreria."""
    rows = db.execute(_track_columns().order_by(func.random()).limit(limit)).all()
    return [_to_track(r) for r in rows]


def get_track_file(db: Session, track_id: int) -> Track | None:
    """L'unico punto che restituisce l'oggetto ORM: serve il percorso su disco."""
    return db.scalar(select(Track).where(Track.id == track_id, _VISIBLE))


# ---------------------------------------------------------------------- generi & co.


def list_genres(db: Session) -> list[GenreOut]:
    rows = db.execute(
        select(Track.genre, func.count(Track.id))
        .where(Track.genre.is_not(None), _VISIBLE)
        .group_by(Track.genre)
        .order_by(func.count(Track.id).desc())
    ).all()
    return [GenreOut(name=r[0], track_count=r[1]) for r in rows]


def last_scan(db: Session) -> ScanStatusOut | None:
    run = db.scalar(select(ScanRun).order_by(ScanRun.id.desc()).limit(1))
    return ScanStatusOut.model_validate(run) if run else None


def library_totals(db: Session) -> tuple[int, int, int, int]:
    artists = db.scalar(select(func.count(Artist.id)).where(_ARTISTA_ASCOLTABILE)) or 0
    albums = db.scalar(select(func.count(Album.id)).where(_ALBUM_ASCOLTABILE)) or 0
    tracks = db.scalar(select(func.count(Track.id)).where(_VISIBLE)) or 0
    duration = db.scalar(select(func.coalesce(func.sum(Track.duration_ms), 0)).where(_VISIBLE)) or 0
    return artists, albums, tracks, duration
