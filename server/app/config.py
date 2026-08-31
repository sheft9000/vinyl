from __future__ import annotations

from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Configurazione del server.

    Ogni campo e' sovrascrivibile da .env o da variabile d'ambiente con lo stesso
    nome in maiuscolo (MUSIC_DIR, API_TOKEN, ...). Nessun percorso e' scritto nel
    codice: e' questo che rende il server spostabile su un'altra macchina, o
    dentro un container, senza toccare una riga.
    """

    model_config = SettingsConfigDict(
        env_file=".env", env_file_encoding="utf-8", extra="ignore"
    )

    app_name: str = "SpotiJugg"
    host: str = "0.0.0.0"
    port: int = 8080

    # Radice della libreria musicale. Il server la apre sempre in sola lettura.
    music_dir: Path = Path("./music")
    # Cartella di lavoro: database SQLite e cache delle copertine.
    data_dir: Path = Path("./data")

    # Token del primo utente, l'unica cosa che protegge la libreria.
    api_token: str = "change-me"
    primary_username: str = "owner"

    # Quando i tag mancano, deduce artista e album dal percorso del file.
    # E' un'ipotesi, non una verita': si spegne da qui se dice sciocchezze.
    infer_tags_from_path: bool = True

    scan_on_startup: bool = True
    watch_library: bool = True
    watch_debounce_seconds: float = 5.0

    artwork_thumb_px: int = 256
    artwork_full_px: int = 1024

    dev_web_player: bool = True

    @property
    def db_path(self) -> Path:
        return self.data_dir / "vinyl.db"

    @property
    def db_url(self) -> str:
        return f"sqlite:///{self.db_path.as_posix()}"

    @property
    def artwork_dir(self) -> Path:
        return self.data_dir / "artwork"


@lru_cache
def get_settings() -> Settings:
    s = Settings()
    s.data_dir.mkdir(parents=True, exist_ok=True)
    s.artwork_dir.mkdir(parents=True, exist_ok=True)
    return s


settings = get_settings()
