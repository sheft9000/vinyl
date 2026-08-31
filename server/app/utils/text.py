from __future__ import annotations

import re
import unicodedata

_SPACES = re.compile(r"\s+")


def normalize(*parts: str | None) -> str:
    """Testo normalizzato per la ricerca: minuscolo, senza accenti, spazi compattati.

    Serve perche' SQLite confronta byte: senza questo, cercare "bjork" non
    troverebbe mai "Bjork" con la o barrata.
    """
    joined = " ".join(p for p in parts if p)
    decomposed = unicodedata.normalize("NFKD", joined)
    stripped = "".join(c for c in decomposed if not unicodedata.combining(c))
    return _SPACES.sub(" ", stripped.lower()).strip()


def clean(value: str | None, max_len: int = 512) -> str | None:
    if value is None:
        return None
    v = _SPACES.sub(" ", str(value)).strip()
    return v[:max_len] or None
