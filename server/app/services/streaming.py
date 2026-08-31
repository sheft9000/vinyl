from __future__ import annotations

import re
from collections.abc import Iterator
from pathlib import Path

from fastapi import HTTPException, status
from fastapi.responses import FileResponse, Response, StreamingResponse

CHUNK_SIZE = 64 * 1024

MIME_TYPES = {
    ".mp3": "audio/mpeg",
    ".m4a": "audio/mp4",
    ".aac": "audio/aac",
    ".flac": "audio/flac",
    ".wav": "audio/wav",
}

_RANGE_RE = re.compile(r"^bytes=(\d*)-(\d*)$")


def _file_chunks(path: Path, start: int, length: int) -> Iterator[bytes]:
    remaining = length
    with path.open("rb") as fh:
        fh.seek(start)
        while remaining > 0:
            chunk = fh.read(min(CHUNK_SIZE, remaining))
            if not chunk:
                break
            remaining -= len(chunk)
            yield chunk


def build_audio_response(path: Path, range_header: str | None, head: bool = False) -> Response:
    """Serve un file audio rispettando le richieste Range.

    Non e' un dettaglio: senza risposte 206 il player iOS non puo' saltare
    avanti nella traccia e in molti casi si rifiuta proprio di iniziare.
    """
    if not path.is_file():
        raise HTTPException(status.HTTP_404_NOT_FOUND, "file non trovato su disco")

    size = path.stat().st_size
    media_type = MIME_TYPES.get(path.suffix.lower(), "application/octet-stream")
    headers = {
        "Accept-Ranges": "bytes",
        "Cache-Control": "private, max-age=3600",
    }

    if not range_header:
        if head:
            return Response(
                status_code=status.HTTP_200_OK,
                headers={**headers, "Content-Length": str(size)},
                media_type=media_type,
            )
        return FileResponse(path, media_type=media_type, headers=headers)

    match = _RANGE_RE.match(range_header.strip())
    if not match:
        return Response(
            status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
            headers={**headers, "Content-Range": f"bytes */{size}"},
        )

    raw_start, raw_end = match.groups()
    if raw_start == "":
        # Forma "bytes=-500": gli ultimi 500 byte.
        length = int(raw_end or 0)
        if length <= 0:
            return Response(
                status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
                headers={**headers, "Content-Range": f"bytes */{size}"},
            )
        start = max(0, size - length)
        end = size - 1
    else:
        start = int(raw_start)
        end = int(raw_end) if raw_end else size - 1

    end = min(end, size - 1)
    if start > end or start >= size:
        return Response(
            status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
            headers={**headers, "Content-Range": f"bytes */{size}"},
        )

    length = end - start + 1
    headers |= {
        "Content-Range": f"bytes {start}-{end}/{size}",
        "Content-Length": str(length),
    }

    if head:
        return Response(
            status_code=status.HTTP_206_PARTIAL_CONTENT,
            headers=headers,
            media_type=media_type,
        )

    return StreamingResponse(
        _file_chunks(path, start, length),
        status_code=status.HTTP_206_PARTIAL_CONTENT,
        headers=headers,
        media_type=media_type,
    )
