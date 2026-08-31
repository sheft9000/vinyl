"""Smoke test end-to-end del server Vinyl.

Costruisce una finta libreria di MP3 (frame MPEG validi + tag ID3 + copertina),
avvia uvicorn davvero, e verifica scansione, API e streaming con Range.
"""
from __future__ import annotations

import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

PY = None  # impostato in main()
PORT = 8099
TOKEN = "smoke-test-token-123"
BASE = f"http://127.0.0.1:{PORT}"

# MPEG-1 Layer III, 128 kbps, 44100 Hz, mono -> frame di 417 byte.
FRAME = b"\xff\xfb\x90\xc0" + b"\x00" * 413


def make_mp3(path: Path, frames: int = 100) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(FRAME * frames)


def tag(path: Path, title: str, artist: str, album: str, no: int, cover: bytes | None) -> None:
    from mutagen.id3 import APIC, ID3, TALB, TCON, TDRC, TIT2, TPE1, TPE2, TRCK

    audio = ID3()
    audio.add(TIT2(encoding=3, text=title))
    audio.add(TPE1(encoding=3, text=artist))
    audio.add(TPE2(encoding=3, text=artist))
    audio.add(TALB(encoding=3, text=album))
    audio.add(TRCK(encoding=3, text=str(no)))
    audio.add(TDRC(encoding=3, text="2021"))
    audio.add(TCON(encoding=3, text="Test"))
    if cover:
        audio.add(APIC(encoding=3, mime="image/jpeg", type=3, desc="Cover", data=cover))
    audio.save(path)


def make_cover(color: tuple[int, int, int]) -> bytes:
    from PIL import Image

    buf = io.BytesIO()
    Image.new("RGB", (600, 600), color).save(buf, "JPEG")
    return buf.getvalue()


def request(path: str, headers: dict | None = None, method: str = "GET"):
    req = urllib.request.Request(
        BASE + path, method=method, headers={"Authorization": f"Bearer {TOKEN}", **(headers or {})}
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as res:
            return res.status, dict(res.headers), res.read()
    except urllib.error.HTTPError as exc:
        return exc.code, dict(exc.headers), exc.read()


def get_json(path: str):
    status, _, body = request(path)
    assert status == 200, f"{path} -> {status}: {body[:200]!r}"
    return json.loads(body)


failures: list[str] = []


def check(label: str, condition: bool, detail: str = "") -> None:
    mark = "OK  " if condition else "FAIL"
    print(f"  [{mark}] {label}{('  -> ' + detail) if detail and not condition else ''}")
    if not condition:
        failures.append(label)


def main() -> int:
    global PY
    server_dir = (
        Path(sys.argv[1]).resolve()
        if len(sys.argv) > 1
        else Path(__file__).resolve().parents[1]
    )
    PY = server_dir / ".venv" / "Scripts" / "python.exe"
    sys.path.insert(0, str(server_dir))

    root = Path(tempfile.mkdtemp(prefix="vinyl-smoke-"))
    music = root / "music"
    data = root / "data"

    print("== Costruisco una libreria di prova ==")
    red, blue = make_cover((200, 40, 60)), make_cover((40, 90, 200))
    tracks = [
        ("Bjork/Homogenic/01 Joga.mp3", "Joga", "Björk", "Homogenic", 1, red),
        ("Bjork/Homogenic/02 Unravel.mp3", "Unravel", "Björk", "Homogenic", 2, red),
        ("Aphex Twin/Selected Ambient/01 Xtal.mp3", "Xtal", "Aphex Twin", "Selected Ambient", 1, blue),
    ]
    for rel, title, artist, album, no, cover in tracks:
        path = music / rel
        make_mp3(path)
        tag(path, title, artist, album, no, cover)
    # Un file senza copertina incorporata: deve prendere folder.jpg
    extra = music / "Vari" / "Senza Tag" / "traccia.mp3"
    make_mp3(extra)
    tag(extra, "Traccia nuda", "Ignoto", "Raccolta", 1, None)
    (music / "Vari" / "Senza Tag" / "cover.jpg").write_bytes(blue)
    print(f"  {len(tracks) + 1} file in {music}")

    env = {
        **os.environ,
        "MUSIC_DIR": str(music),
        "DATA_DIR": str(data),
        "API_TOKEN": TOKEN,
        "SCAN_ON_STARTUP": "true",
        "WATCH_LIBRARY": "true",
        "PYTHONPATH": str(server_dir),
        "PYTHONIOENCODING": "utf-8",
    }

    print("== Avvio il server ==")
    log = open(root / "server.log", "wb")
    proc = subprocess.Popen(
        [str(PY), "-m", "uvicorn", "app.main:app", "--host", "127.0.0.1", "--port", str(PORT)],
        cwd=str(server_dir), env=env, stdout=log, stderr=subprocess.STDOUT,
    )

    try:
        for _ in range(60):
            if proc.poll() is not None:
                print((root / "server.log").read_text(errors="replace"))
                print("Il server e' morto durante l'avvio.")
                return 1
            try:
                with urllib.request.urlopen(BASE + "/health", timeout=2) as res:
                    if res.status == 200:
                        break
            except Exception:
                time.sleep(0.5)
        else:
            print("Il server non risponde.")
            return 1

        print("== Scansione ==")
        for _ in range(60):
            status = get_json("/api/v1/scan/status")
            if status["status"] in ("ok", "error"):
                break
            time.sleep(0.5)
        check("scansione completata", status["status"] == "ok", json.dumps(status))
        check("4 file trovati", status["files_seen"] == 4, str(status.get("files_seen")))
        check("4 brani aggiunti", status["added"] == 4, str(status.get("added")))

        print("== Autenticazione ==")
        code, _, _ = request("/api/v1/stats", headers={"Authorization": "Bearer sbagliato"})
        check("token errato -> 401", code == 401, str(code))
        req = urllib.request.Request(BASE + "/api/v1/stats")
        try:
            urllib.request.urlopen(req, timeout=5)
            check("senza token -> 401", False, "ha risposto 200")
        except urllib.error.HTTPError as exc:
            check("senza token -> 401", exc.code == 401, str(exc.code))
        code, _, _ = request(f"/api/v1/stats?token={TOKEN}", headers={"Authorization": ""})
        check("token in query string accettato", code == 200, str(code))

        print("== Libreria ==")
        stats = get_json("/api/v1/stats")
        check("3 artisti", stats["artists"] == 3, str(stats["artists"]))
        check("3 album", stats["albums"] == 3, str(stats["albums"]))
        check("4 brani", stats["tracks"] == 4, str(stats["tracks"]))
        check("durata calcolata dai tag", stats["total_duration_ms"] > 0, str(stats["total_duration_ms"]))

        albums = get_json("/api/v1/albums?sort=artist")
        titles = [a["title"] for a in albums["items"]]
        check("album elencati", "Homogenic" in titles, str(titles))
        homogenic = next(a for a in albums["items"] if a["title"] == "Homogenic")
        check("nome artista sull'album", homogenic["artist_name"] == "Björk", homogenic["artist_name"])
        check("2 brani in Homogenic", homogenic["track_count"] == 2, str(homogenic["track_count"]))
        check("copertina incorporata estratta", bool(homogenic["art_key"]))

        album_tracks = get_json(f"/api/v1/albums/{homogenic['id']}/tracks")["items"]
        check("ordine per numero di traccia", [t["track_no"] for t in album_tracks] == [1, 2],
              str([t["track_no"] for t in album_tracks]))

        raccolta = next(a for a in albums["items"] if a["title"] == "Raccolta")
        check("fallback su cover.jpg nella cartella", bool(raccolta["art_key"]))

        print("== Ricerca ==")
        found = get_json("/api/v1/search?q=bjork")
        check("ricerca senza accenti trova Björk", len(found["artists"]) == 1, json.dumps(found["artists"]))
        check("ricerca trova anche gli album", len(found["albums"]) == 1, str(len(found["albums"])))
        check("ricerca a caso non trova nulla", get_json("/api/v1/search?q=zzzzz")["tracks"] == [])
        check("ricerca parziale sui titoli", len(get_json("/api/v1/search?q=unrav")["tracks"]) == 1)

        print("== Shuffle ==")
        shuffled = get_json("/api/v1/tracks/random?limit=50")
        check("shuffle restituisce tutti i brani", len(shuffled) == 4, str(len(shuffled)))

        print("== Streaming ==")
        track_id = album_tracks[0]["id"]
        code, headers, body = request(f"/api/v1/tracks/{track_id}/stream")
        check("stream completo -> 200", code == 200, str(code))
        check("Accept-Ranges dichiarato", headers.get("accept-ranges") == "bytes", str(headers.get("accept-ranges")))
        full_size = len(body)
        check("il file arriva intero", full_size > 40000, str(full_size))

        code, headers, body = request(
            f"/api/v1/tracks/{track_id}/stream", headers={"Range": "bytes=0-1023"}
        )
        check("richiesta Range -> 206", code == 206, str(code))
        check("1024 byte esatti", len(body) == 1024, str(len(body)))
        check("Content-Range corretto",
              headers.get("content-range") == f"bytes 0-1023/{full_size}",
              str(headers.get("content-range")))

        code, headers, body = request(
            f"/api/v1/tracks/{track_id}/stream", headers={"Range": "bytes=-512"}
        )
        check("Range dalla fine -> 206", code == 206, str(code))
        check("ultimi 512 byte", len(body) == 512, str(len(body)))

        code, headers, _ = request(
            f"/api/v1/tracks/{track_id}/stream", headers={"Range": f"bytes={full_size + 10}-"}
        )
        check("Range oltre la fine -> 416", code == 416, str(code))

        code, headers, body = request(f"/api/v1/tracks/{track_id}/stream", method="HEAD")
        check("HEAD -> 200 senza corpo", code == 200 and body == b"", f"{code}/{len(body)}")

        print("== Copertine ==")
        code, headers, body = request(f"/api/v1/artwork/{homogenic['art_key']}?size=thumb")
        check("thumb servita", code == 200 and body[:2] == b"\xff\xd8", str(code))
        check("cache immutabile", "immutable" in headers.get("cache-control", ""),
              str(headers.get("cache-control")))
        code, _, full = request(f"/api/v1/artwork/{homogenic['art_key']}?size=full")
        check("full piu' grande della thumb", len(full) > len(body), f"{len(full)} vs {len(body)}")
        code, _, _ = request("/api/v1/artwork/nonesiste123")
        check("copertina inesistente -> 404", code == 404, str(code))

        print("== Scansione incrementale ==")
        before = get_json("/api/v1/stats")["tracks"]
        new_file = music / "Bjork" / "Homogenic" / "03 Bachelorette.mp3"
        make_mp3(new_file)
        tag(new_file, "Bachelorette", "Björk", "Homogenic", 3, red)
        deadline = time.time() + 25
        after = before
        while time.time() < deadline:
            time.sleep(1)
            after = get_json("/api/v1/stats")["tracks"]
            if after > before:
                break
        check("il watcher ha visto il file nuovo", after == before + 1, f"{before} -> {after}")

        print("== File sparito ==")
        new_file.unlink()
        request("/api/v1/scan", method="POST")
        for _ in range(40):
            time.sleep(0.5)
            if get_json("/api/v1/scan/status")["status"] == "ok":
                break
        check("il brano sparito viene nascosto", get_json("/api/v1/stats")["tracks"] == before,
              str(get_json("/api/v1/stats")["tracks"]))

        print("== Console web ==")
        with urllib.request.urlopen(BASE + "/", timeout=5) as res:
            page = res.read()
        check("console di test servita", res.status == 200 and b"Vinyl" in page)

    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
        log.close()

    print()
    if failures:
        print(f"{len(failures)} CONTROLLI FALLITI: " + ", ".join(failures))
        print("--- log del server ---")
        print((root / "server.log").read_text(errors="replace")[-4000:])
        return 1

    print("Tutti i controlli superati.")
    shutil.rmtree(root, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
