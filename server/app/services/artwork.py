from __future__ import annotations

import hashlib
import io
import logging
from pathlib import Path

from PIL import Image

from app.config import settings

log = logging.getLogger(__name__)

VARIANTS = {"thumb": settings.artwork_thumb_px, "full": settings.artwork_full_px}


def artwork_path(key: str, variant: str = "thumb") -> Path:
    # Sottocartella a due caratteri: evita decine di migliaia di file in una sola dir.
    return settings.artwork_dir / key[:2] / f"{key}_{variant}.jpg"


def store_picture(data: bytes | None) -> str | None:
    """Salva una copertina in due misure e restituisce la sua chiave.

    La chiave e' l'hash del contenuto: due album con la stessa copertina
    condividono lo stesso file su disco, e il client puo' fare cache per sempre.
    """
    if not data:
        return None

    key = hashlib.sha1(data).hexdigest()
    targets = {v: artwork_path(key, v) for v in VARIANTS}
    if all(p.is_file() for p in targets.values()):
        return key

    try:
        source = Image.open(io.BytesIO(data))
        source = source.convert("RGB")
    except Exception as exc:
        log.warning("copertina non decodificabile: %s", exc)
        return None

    for variant, size in VARIANTS.items():
        target = targets[variant]
        target.parent.mkdir(parents=True, exist_ok=True)
        image = source.copy()
        image.thumbnail((size, size), Image.LANCZOS)
        image.save(target, "JPEG", quality=88, optimize=True)

    return key
