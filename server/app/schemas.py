from __future__ import annotations

from datetime import datetime
from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict

T = TypeVar("T")


class Page(BaseModel, Generic[T]):
    items: list[T]
    total: int
    offset: int
    limit: int


class ArtistOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    album_count: int = 0
    track_count: int = 0
    art_key: str | None = None


class AlbumOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    artist_id: int
    artist_name: str = ""
    year: int | None = None
    art_key: str | None = None
    track_count: int = 0
    duration_ms: int = 0


class TrackOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    title: str
    artist_id: int | None = None
    artist_name: str = ""
    album_id: int | None = None
    album_title: str = ""
    track_no: int | None = None
    disc_no: int | None = None
    year: int | None = None
    genre: str | None = None
    duration_ms: int = 0
    ext: str = ""
    art_key: str | None = None


class GenreOut(BaseModel):
    name: str
    track_count: int


class SearchOut(BaseModel):
    artists: list[ArtistOut]
    albums: list[AlbumOut]
    tracks: list[TrackOut]


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    username: str
    is_admin: bool


class ScanStatusOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int | None = None
    status: str = "idle"
    started_at: datetime | None = None
    finished_at: datetime | None = None
    files_seen: int = 0
    added: int = 0
    updated: int = 0
    removed: int = 0
    error: str | None = None


class StatsOut(BaseModel):
    artists: int
    albums: int
    tracks: int
    total_duration_ms: int
    music_dir: str
    music_dir_exists: bool
    last_scan: ScanStatusOut | None = None
