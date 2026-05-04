from __future__ import annotations

try:
    from fastapi import APIRouter, Depends
    from fastapi.responses import JSONResponse
except Exception:
    APIRouter = None
    Depends = None
    JSONResponse = None

from core.dev_assistente import processar_comando_dev

from .dependencies import rate_limit, require_token


def _json(payload: dict, status_code: int = 200):
    return JSONResponse(content=payload, status_code=status_code)


if APIRouter is not None:
    router = APIRouter(
        prefix="/dev",
        tags=["dev"],
        dependencies=[Depends(rate_limit(120)), Depends(require_token())],
    )

    @router.post("/generate")
    def generate_code(body: dict):
        prompt = str(body.get("prompt", "")).strip()
        language = str(body.get("language", "")).strip()
        project_name = str(body.get("project_name", "")).strip()
        auto_confirm = bool(body.get("auto_confirm", False))

        if not prompt:
            pieces = ["Nova, gerar codigo"]
            if language:
                pieces.append(f"em {language}")
            if project_name:
                pieces.append(f"para {project_name}")
            prompt = " ".join(pieces).strip()

        context: dict[str, object] = {}
        first_pass = processar_comando_dev(prompt, contexto=context)
        if first_pass is None:
            return _json(
                {
                    "ok": False,
                    "error": "prompt_not_supported",
                    "message": "Nao consegui interpretar esse pedido de geracao de codigo.",
                },
                status_code=400,
            )

        answer = first_pass
        pending_confirmation = "confirmar cria" in str(first_pass).lower()

        if pending_confirmation and auto_confirm:
            confirmed = processar_comando_dev("confirmar criacao", contexto=context)
            if confirmed:
                answer = confirmed
                pending_confirmation = False

        return {
            "ok": True,
            "status": "ok",
            "type": "dev",
            "answer": str(answer).strip(),
            "pending_confirmation": pending_confirmation,
            "next_actions": [
                "Continuar projeto",
                "Melhorar interface",
                "Explicar codigo",
            ],
        }

else:
    router = None
