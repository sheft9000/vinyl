from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from pathlib import Path

from mutagen import File as MutagenFile

log = logging.getLogger(__name__)

# Formati indicizzati. mp3 e m4a sono gli unici che iOS riproduce senza conversione;
# gli altri sono qui per il futuro, quando aggiungeremo la transcodifica.
AUDIO_EXTS = {".mp3", ".m4a", ".aac", ".flac", ".wav"}

_COVER_NAMES = ("cover", "folder", "front", "album", "albumart")
_COVER_EXTS = (".jpg", ".jpeg", ".png", ".webp")


@dataclass(slots=True)
class TrackTags:
    """Cio' che c'e' scritto nel file, e nient'altro.

    I campi mancanti restano None: decidere con cosa sostituirli non e'
    compito di chi legge i tag.
    """

    title: str | None
    artist: str | None
    album_artist: str | None
    album: str | None
    track_no: int | None
    disc_no: int | None
    year: int | None
    genre: str | None
    duration_ms: int
    bitrate: int | None
    sample_rate: int | None


def _first(tags, *keys: str) -> str | None:
    for key in keys:
        value = tags.get(key)
        if value:
            item = value[0] if isinstance(value, list) else value
            text = str(item).strip()
            if text:
                return text
    return None


def _as_int(value: str | None) -> int | None:
    """Accetta "3", "3/12", "2019-05-01" e restituisce il primo numero utile."""
    if not value:
        return None
    head = str(value).split("/")[0].split("-")[0].strip()
    try:
        return int(head)
    except ValueError:
        return None


def read_tags(path: Path) -> TrackTags | None:
    """Legge i tag di un file audio. None se il file non e' leggibile."""
    try:
        audio = MutagenFile(path, easy=True)
    except Exception as exc:  # file corrotto, permessi, ecc.
        log.warning("tag illeggibili per %s: %s", path, exc)
        return None
    if audio is None:
        return None

    tags = audio.tags or {}
    info = getattr(audio, "info", None)

    artist = _first(tags, "artist", "albumartist")

    return TrackTags(
        title=_first(tags, "title"),
        artist=artist,
        album_artist=_first(tags, "albumartist") or artist,
        album=_first(tags, "album"),
        track_no=_as_int(_first(tags, "tracknumber")),
        disc_no=_as_int(_first(tags, "discnumber")),
        year=_as_int(_first(tags, "date", "originaldate", "year")),
        genre=_first(tags, "genre"),
        duration_ms=int((getattr(info, "length", 0) or 0) * 1000),
        bitrate=getattr(info, "bitrate", None),
        sample_rate=getattr(info, "sample_rate", None),
    )


def extract_embedded_picture(path: Path) -> bytes | None:
    """Copertina incorporata nel file: APIC per gli MP3, atomo 'covr' per gli M4A."""
    try:
        audio = MutagenFile(path)
    except Exception:
        return None
    if audio is None:
        return None

    tags = getattr(audio, "tags", None)
    if tags is None:
        return None

    # MP3 / ID3
    try:
        for frame in tags.getall("APIC"):
            if frame.data:
                return bytes(frame.data)
    except AttributeError:
        pass

    # MP4 / M4A
    try:
        covers = tags.get("covr")
        if covers:
            return bytes(covers[0])
    except Exception:
        pass

    # FLAC e simili
    pictures = getattr(audio, "pictures", None)
    if pictures:
        return bytes(pictures[0].data)

    return None


def find_folder_cover(directory: Path) -> bytes | None:
    """Fallback: cover.jpg / folder.jpg accanto ai file, come li salva quasi ogni ripper."""
    try:
        entries = {p.name.lower(): p for p in directory.iterdir() if p.is_file()}
    except OSError:
        return None

    for name in _COVER_NAMES:
        for ext in _COVER_EXTS:
            candidate = entries.get(f"{name}{ext}")
            if candidate:
                try:
                    return candidate.read_bytes()
                except OSError:
                    continue
    return None


# "Artista - Titolo", con o senza spazio prima del trattino, e anche con i
# trattini lunghi che escono dai convertitori.
_ARTIST_TITLE = re.compile(r"^(?P<artist>.{2,80}?)\s*[-–—]\s+(?P<title>.+)$")

# "01 Titolo", "01. Titolo", "01 - Titolo".
_LEADING_NUMBER = re.compile(r"^\d{1,3}\s*[-.)]?\s+")


def infer_from_path(path: Path, root: Path) -> tuple[str | None, str | None, str | None]:
    """Deduce artista, album e titolo dal percorso, per i file senza tag.

    Riconosce due convenzioni: le cartelle `Artista/Album/traccia.mp3` e i nomi
    di file `Artista - Titolo`. Sono ipotesi ragionevoli, non certezze: le
    cartelle hanno la precedenza sul nome del file, e i tag veri hanno sempre
    la precedenza su entrambe.
    """
    artist: str | None = None
    album: str | None = None

    try:
        folders = path.relative_to(root).parts[:-1]
    except ValueError:
        folders = ()

    if len(folders) >= 2:
        artist, album = folders[-2], folders[-1]
    elif len(folders) == 1:
        album = folders[0]

    stem = _LEADING_NUMBER.sub("", path.stem).strip()
    title: str | None = stem or None

    match = _ARTIST_TITLE.match(stem)
    if match:
        if artist is None:
            artist = match.group("artist").strip()
            title = match.group("title").strip()
        # Con l'artista gia' noto dalle cartelle, il nome del file resta intero:
        # spesso ripete l'artista, ma tagliarlo a occhi chiusi rovinerebbe
        # titoli che un trattino ce l'hanno per conto loro.

    return artist or None, album or None, title
