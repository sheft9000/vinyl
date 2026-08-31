from __future__ import annotations

from fastapi import APIRouter

from app.api.v1 import admin, library, media

api_router = APIRouter(prefix="/api/v1")
api_router.include_router(library.router)
api_router.include_router(media.router)
api_router.include_router(admin.router)
