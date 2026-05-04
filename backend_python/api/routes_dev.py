from __future__ import annotations

try:
    from fastapi import APIRouter, Depends
    from fastapi.responses import JSONResponse
except Exception:
    APIRouter = None
    Depends = None
    JSONResponse = None

from core.dev_assistente import gerar_codigo_por_ideia

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

        if not prompt:
            return _json(
                {
                    "ok": False,
                    "error": "prompt_required",
                    "message": "Descreva a ideia que deseja transformar em codigo.",
                },
                status_code=400,
            )

        try:
            generated = gerar_codigo_por_ideia(
                prompt,
                language=language,
                project_name=project_name,
            )
        except ValueError:
            return _json(
                {
                    "ok": False,
                    "error": "prompt_not_supported",
                    "message": "Nao consegui interpretar esse pedido de geracao de codigo.",
                },
                status_code=400,
            )

        return {
            "ok": True,
            "status": "ok",
            "type": "dev",
            "answer": str(generated.get("answer", "")).strip(),
            "reply": str(generated.get("answer", "")).strip(),
            "resumo": str(generated.get("summary", "")).strip(),
            "explicacao": str(generated.get("answer", "")).strip(),
            "assistant_state": "suggesting",
            "language": generated.get("language"),
            "language_label": generated.get("language_label"),
            "project_name": generated.get("project_name"),
            "project_dir": generated.get("project_dir"),
            "project_ref": generated.get("project_ref"),
            "files": generated.get("files", []),
            "run_instructions": generated.get("run_instructions", []),
            "improvements": generated.get("improvements", []),
            "code_bundle": generated.get("code_bundle", ""),
            "copy_label": generated.get("copy_label", "Copiar codigo"),
            "pending_confirmation": False,
            "next_actions": [
                "Continuar projeto",
                "Explicar codigo",
                "Melhorar interface",
            ],
        }

else:
    router = None
