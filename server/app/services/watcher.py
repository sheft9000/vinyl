from __future__ import annotations

import logging
import threading
from pathlib import Path

from watchdog.events import FileSystemEventHandler
from watchdog.observers import Observer

from app.config import settings
from app.services.metadata import AUDIO_EXTS
from app.services.scanner import request_scan

log = logging.getLogger(__name__)


class _DebouncedHandler(FileSystemEventHandler):
    """Copiare un album genera decine di eventi: aspettiamo che la calma torni.

    Ogni evento riavvia il timer, e la scansione parte solo quando per
    `delay` secondi non e' successo piu' nulla.
    """

    def __init__(self, delay: float) -> None:
        self.delay = delay
        self._timer: threading.Timer | None = None
        self._lock = threading.Lock()

    def on_any_event(self, event) -> None:
        if event.is_directory:
            return
        path = getattr(event, "dest_path", None) or event.src_path
        if Path(str(path)).suffix.lower() not in AUDIO_EXTS:
            return

        with self._lock:
            if self._timer is not None:
                self._timer.cancel()
            self._timer = threading.Timer(self.delay, self._fire)
            self._timer.daemon = True
            self._timer.start()

    def _fire(self) -> None:
        log.info("libreria modificata: avvio scansione incrementale")
        request_scan()


def start_watcher():
    if not settings.watch_library:
        return None
    root = settings.music_dir
    if not root.is_dir():
        log.warning("watcher non avviato: MUSIC_DIR non esiste (%s)", root)
        return None

    observer = Observer()
    observer.schedule(
        _DebouncedHandler(settings.watch_debounce_seconds), str(root), recursive=True
    )
    observer.start()
    log.info("watcher attivo su %s", root)
    return observer


def stop_watcher(observer) -> None:
    if observer is None:
        return
    observer.stop()
    observer.join(timeout=5)
