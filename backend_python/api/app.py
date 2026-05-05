from __future__ import annotations

import os

try:
    from fastapi import FastAPI
    from fastapi.middleware.cors import CORSMiddleware
except Exception:
    FastAPI = None
    CORSMiddleware = None

from core.api_profile import NOVA_API_VERSION, build_api_health
from .routes_actions import router as actions_router
from .routes_brain import router as brain_router
from .routes_chat import router as chat_router
from .routes_compat import router as compat_router
from .routes_dev import compat_router as dev_compat_router, router as dev_router
from .routes_files import camera_router, router as files_router
from .routes_location import router as location_router
from .routes_memory import router as memory_router
from .routes_system import router as system_router
from .routes_voice import router as voice_router

try:
    from .routes_admin import router as admin_router
except Exception:
    admin_router = None


def _resolve_cors_settings() -> dict[str, object]:
    raw = os.getenv("NOVA_API_CORS_ORIGINS", "").strip()

    if raw:
        origins: list[str] = []
        for item in raw.split(","):
            normalized = item.strip()
            if normalized and normalized not in origins:
                origins.append(normalized)

        if "*" in origins:
            return {
                "allow_origins": ["*"],
                "allow_origin_regex": None,
                "allow_credentials": False,
            }

        if origins:
            return {
                "allow_origins": origins,
                "allow_origin_regex": None,
                "allow_credentials": True,
            }

    return {
        "allow_origins": [],
        "allow_origin_regex": r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
        "allow_credentials": True,
    }


def create_app():
    if FastAPI is None:
        raise RuntimeError(
            "FastAPI is not installed. Run `pip install -r backend_python/requirements.txt` first."
        )

    app = FastAPI(
        title="NOVA API",
        version=NOVA_API_VERSION,
        description="Base Jarvis Fase 1 com orquestrador, memoria SQLite e ferramentas seguras.",
    )

    if CORSMiddleware is not None:
        cors_settings = _resolve_cors_settings()
        app.add_middleware(
            CORSMiddleware,
            allow_origins=list(cors_settings["allow_origins"]),
            allow_origin_regex=cors_settings["allow_origin_regex"],
            allow_credentials=bool(cors_settings["allow_credentials"]),
            allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            allow_headers=[
                "Content-Type",
                "Authorization",
                "X-API-Key",
                "X-User-Role",
                "X-User-Name",
            ],
        )

    @app.get("/health")
    def health() -> dict[str, object]:
        return build_api_health(entrypoint="fastapi_app")

    app.include_router(chat_router)
    app.include_router(memory_router)
    if files_router is not None:
        app.include_router(files_router)
    if camera_router is not None:
        app.include_router(camera_router)
    if brain_router is not None:
        app.include_router(brain_router)
    app.include_router(actions_router)
    if dev_router is not None:
        app.include_router(dev_router)
    if dev_compat_router is not None:
        app.include_router(dev_compat_router)
    app.include_router(voice_router)

    if compat_router is not None:
        app.include_router(compat_router)

    if admin_router is not None:
        app.include_router(admin_router)

    if system_router is not None:
        app.include_router(system_router)

    if location_router is not None:
        app.include_router(location_router)

    return app
