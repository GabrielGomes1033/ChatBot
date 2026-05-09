from __future__ import annotations

try:
    from fastapi import APIRouter, Depends, HTTPException, Query
except Exception:
    APIRouter = None
    Depends = None
    HTTPException = None
    Query = None

from core.painel_admin import autenticar_usuario, obter_usuario, registrar_usuario_publico

from .dependencies import rate_limit


def _build_session_payload(user: dict) -> dict:
    return {
        "user_id": str(user.get("id", "")).strip(),
        "name": str(user.get("nome", "")).strip(),
        "email": str(user.get("email", "")).strip().lower(),
        "role": str(user.get("papel", "usuario")).strip().lower() or "usuario",
        "created_at": str(user.get("criado_em", "")).strip(),
        "last_login_at": str(user.get("ultimo_login_em", "")).strip(),
    }


if APIRouter is not None:
    def _register_impl(body: dict):
        nome = str(body.get("name", body.get("nome", ""))).strip()
        email = str(body.get("email", "")).strip()
        senha = str(body.get("password", body.get("senha", ""))).strip()
        try:
            user = registrar_usuario_publico(nome=nome, email=email, senha=senha)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))
        return {
            "ok": True,
            "session": _build_session_payload(user),
            "user": user,
        }

    def _login_impl(body: dict):
        email = str(body.get("email", "")).strip()
        senha = str(body.get("password", body.get("senha", ""))).strip()
        try:
            user = autenticar_usuario(email=email, senha=senha)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc))
        if not user:
            raise HTTPException(status_code=401, detail="invalid_credentials")
        return {
            "ok": True,
            "session": _build_session_payload(user),
            "user": user,
        }

    def _profile_impl(user_id: str):
        user = obter_usuario(user_id)
        if not user or not bool(user.get("ativo", True)):
            raise HTTPException(status_code=404, detail="user_not_found")
        return {
            "ok": True,
            "session": _build_session_payload(user),
            "user": user,
        }

    router = APIRouter(
        prefix="/auth",
        tags=["auth"],
        dependencies=[Depends(rate_limit(40, 60))],
    )

    compat_router = APIRouter(
        prefix="/api/auth",
        tags=["auth_compat"],
        dependencies=[Depends(rate_limit(40, 60))],
    )

    @router.post("/register")
    def register(body: dict):
        return _register_impl(body)

    @compat_router.post("/register")
    def register_compat(body: dict):
        return _register_impl(body)

    @router.post("/login")
    def login(body: dict):
        return _login_impl(body)

    @compat_router.post("/login")
    def login_compat(body: dict):
        return _login_impl(body)

    @router.get("/profile")
    def profile(user_id: str = Query(...)):
        return _profile_impl(user_id)

    @compat_router.get("/profile")
    def profile_compat(user_id: str = Query(...)):
        return _profile_impl(user_id)

else:
    router = None
    compat_router = None
