from __future__ import annotations

try:
    from fastapi import APIRouter, Depends
    from fastapi.responses import JSONResponse
except Exception:
    APIRouter = None
    Depends = None
    JSONResponse = None

from .dependencies import rate_limit
from api_server import processar_mensagem
from .routes_files import build_file_chat_context
from routes.chat_routes import handle_chat_post


def _dispatch_chat(body: dict) -> tuple[dict, int]:
    payload: dict = {"ok": False, "error": "chat_not_handled"}
    status_code = 500

    def _send_json(data: dict, status: int = 200):
        nonlocal payload, status_code
        payload = data
        status_code = status

    handled = handle_chat_post(
        path="/chat",
        body=body,
        process_message=processar_mensagem,
        send_json=_send_json,
    )
    if not handled:
        return {"ok": False, "error": "chat_not_handled"}, 404
    return payload, status_code


if APIRouter is not None:
    router = APIRouter(tags=["chat"], dependencies=[Depends(rate_limit(90))])

    @router.post("/chat")
    def chat(body: dict):
        payload_body = body if isinstance(body, dict) else {}
        file_id = str(payload_body.get("file_id", "")).strip()
        if file_id:
            attachment = build_file_chat_context(file_id)
            if attachment:
                prompt_context = str(attachment.get("prompt_context", "")).strip()
                inbound_text = str(
                    payload_body.get("text", payload_body.get("message", ""))
                ).strip()
                if not inbound_text:
                    inbound_text = "Analise o arquivo anexado e responda com base nele."
                payload_body = dict(payload_body)
                payload_body["text"] = f"{inbound_text}\n\n{prompt_context}".strip()
        payload, status_code = _dispatch_chat(payload_body)
        return JSONResponse(content=payload, status_code=status_code)

else:
    router = None
