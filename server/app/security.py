from __future__ import annotations

import logging
import secrets

from fastapi import Depends, HTTPException, Query, Request, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.models import User

log = logging.getLogger(__name__)


def ensure_primary_user(db: Session) -> User:
    """Allinea l'utente principale a quello descritto nel .env.

    Cosi' il file di configurazione resta l'unica fonte di verita' finche'
    l'utente e' uno solo; il giorno in cui ne aggiungerai altri, saranno
    semplici righe in piu' nella tabella.
    """
    if settings.api_token in ("", "change-me"):
        log.warning(
            "API_TOKEN non impostato: la libreria e' senza protezione. "
            'Generane uno con: python -c "import secrets; print(secrets.token_urlsafe(32))"'
        )

    user = db.scalar(select(User).where(User.username == settings.primary_username))
    if user is None:
        user = User(
            username=settings.primary_username, token=settings.api_token, is_admin=True
        )
        db.add(user)
    else:
        user.token = settings.api_token
        user.is_admin = True
    db.commit()
    return user


def _token_from_request(request: Request, query_token: str | None) -> str | None:
    header = request.headers.get("Authorization", "")
    if header.lower().startswith("bearer "):
        return header[7:].strip()
    # Il parametro in query serve a <audio> e <img> del browser, che non possono
    # aggiungere header. L'app Flutter usera' sempre l'header.
    return query_token.strip() if query_token else None


def get_current_user(
    request: Request,
    token: str | None = Query(default=None, include_in_schema=True),
    db: Session = Depends(get_db),
) -> User:
    raw = _token_from_request(request, token)
    if not raw:
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "token mancante",
            headers={"WWW-Authenticate": "Bearer"},
        )

    user = db.scalar(select(User).where(User.token == raw))
    # compare_digest non serve qui (il confronto lo fa SQLite), ma se il token
    # non esiste rispondiamo comunque in tempo costante rispetto alla lunghezza.
    if user is None or not secrets.compare_digest(user.token, raw):
        raise HTTPException(
            status.HTTP_401_UNAUTHORIZED,
            "token non valido",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user


def require_admin(user: User = Depends(get_current_user)) -> User:
    if not user.is_admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "servono i permessi di amministratore")
    return user
