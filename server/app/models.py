from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    DateTime,
    ForeignKey,
    Index,
    Integer,
    String,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class User(Base):
    """Un solo utente oggi, ma la tabella c'e' dal primo giorno.

    Aggiungere il secondo utente domani sara' una INSERT, non una migrazione.
    """

    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    username: Mapped[str] = mapped_column(String(64), unique=True)
    token: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow)


class Artist(Base):
    __tablename__ = "artists"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(512), unique=True)
    search_text: Mapped[str] = mapped_column(String(512), index=True, default="")

    albums: Mapped[list["Album"]] = relationship(
        back_populates="artist", cascade="all, delete-orphan"
    )


class Album(Base):
    __tablename__ = "albums"
    __table_args__ = (UniqueConstraint("artist_id", "title", name="uq_album_artist_title"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    title: Mapped[str] = mapped_column(String(512))
    artist_id: Mapped[int] = mapped_column(ForeignKey("artists.id"), index=True)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    art_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    search_text: Mapped[str] = mapped_column(String(1024), index=True, default="")
    added_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, index=True)

    artist: Mapped[Artist] = relationship(back_populates="albums")
    tracks: Mapped[list["Track"]] = relationship(
        back_populates="album", cascade="all, delete-orphan"
    )


class Track(Base):
    __tablename__ = "tracks"
    __table_args__ = (
        Index("ix_tracks_album_order", "album_id", "disc_no", "track_no"),
        Index("ix_tracks_visible", "missing", "added_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)

    # Identita' del file su disco.
    path: Mapped[str] = mapped_column(String(1024), unique=True)
    rel_path: Mapped[str] = mapped_column(String(1024), default="")
    ext: Mapped[str] = mapped_column(String(16), default="")
    size: Mapped[int] = mapped_column(Integer, default=0)
    mtime: Mapped[float] = mapped_column(default=0.0)

    # Tag.
    title: Mapped[str] = mapped_column(String(512))
    artist_id: Mapped[int | None] = mapped_column(ForeignKey("artists.id"), index=True)
    album_id: Mapped[int | None] = mapped_column(ForeignKey("albums.id"), index=True)
    track_no: Mapped[int | None] = mapped_column(Integer, nullable=True)
    disc_no: Mapped[int | None] = mapped_column(Integer, nullable=True)
    year: Mapped[int | None] = mapped_column(Integer, nullable=True)
    genre: Mapped[str | None] = mapped_column(String(128), nullable=True, index=True)

    # Audio.
    duration_ms: Mapped[int] = mapped_column(Integer, default=0)
    bitrate: Mapped[int | None] = mapped_column(Integer, nullable=True)
    sample_rate: Mapped[int | None] = mapped_column(Integer, nullable=True)

    art_key: Mapped[str | None] = mapped_column(String(64), nullable=True)
    search_text: Mapped[str] = mapped_column(String(1024), index=True, default="")

    # Un file sparito non viene cancellato dal DB: viene marcato. Cosi' se stacchi
    # un disco esterno non perdi nulla, e al ricollegamento torna com'era.
    missing: Mapped[bool] = mapped_column(Boolean, default=False, index=True)

    added_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow, index=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow)

    artist: Mapped[Artist | None] = relationship()
    album: Mapped[Album | None] = relationship(back_populates="tracks")


class ScanRun(Base):
    """Storico delle scansioni: serve a mostrare lo stato nella UI e a debuggare."""

    __tablename__ = "scan_runs"

    id: Mapped[int] = mapped_column(primary_key=True)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=_utcnow)
    finished_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    status: Mapped[str] = mapped_column(String(32), default="running")
    files_seen: Mapped[int] = mapped_column(Integer, default=0)
    added: Mapped[int] = mapped_column(Integer, default=0)
    updated: Mapped[int] = mapped_column(Integer, default=0)
    removed: Mapped[int] = mapped_column(Integer, default=0)
    error: Mapped[str | None] = mapped_column(String(1024), nullable=True)
