from __future__ import annotations

import re
from typing import Any, Callable

from core.jarvis_chat_bridge import process_pending_tool_confirmation
from core.orchestrator import get_default_orchestrator

_PENDING_STRUCTURED_CHAT: dict[str, dict] = {}
_SENTENCE_BREAK_RE = re.compile(r"(?<=[.!?])\s+")


def _clean_text(value: Any) -> str:
    return " ".join(str(value or "").split()).strip()


def _short_summary(text: str, *, max_sentences: int = 2, limit: int = 240) -> str:
    cleaned = _clean_text(text)
    if not cleaned:
        return ""
    parts = [part.strip() for part in _SENTENCE_BREAK_RE.split(cleaned) if part.strip()]
    summary = " ".join(parts[:max_sentences]).strip() or cleaned
    if len(summary) <= limit:
        return summary
    clipped = summary[:limit].rsplit(" ", 1)[0].strip()
    return f"{clipped}..." if clipped else f"{summary[:limit].strip()}..."


def _dedupe_items(items: list[str], *, limit: int = 3) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        cleaned = _clean_text(item)
        if not cleaned:
            continue
        key = cleaned.casefold()
        if key in seen:
            continue
        seen.add(key)
        out.append(cleaned)
        if len(out) >= limit:
            break
    return out


def _contains_any(text: str, options: tuple[str, ...]) -> bool:
    lowered = _clean_text(text).casefold()
    return any(option in lowered for option in options)


def _infer_assistant_state(result: dict[str, Any], reply: str) -> str:
    if bool(result.get("approval_needed")):
        return "suggesting"
    if str(result.get("decision_type", "")).strip() == "tool_call":
        return "executing"
    if _clean_text(reply):
        return "responding"
    return "idle"


def _infer_actions(
    *,
    user_text: str,
    reply: str,
    tool_name: str,
    approval_needed: bool,
) -> list[str]:
    text = f"{user_text} {reply}".casefold()
    if approval_needed:
        return [
            "Revisar a acao",
            "Continuar com seguranca",
            "Ajustar o pedido",
        ]
    if tool_name == "search_web":
        return [
            "Comparar fontes",
            "Transformar em plano",
            "Salvar na memoria",
        ]
    if "codigo" in text or "flutter" in text or "interface" in text or "projeto" in text:
        return [
            "Continuar projeto",
            "Gerar codigo",
            "Melhorar interface",
        ]
    if "pesquisa" in text or "pesquise" in text or "resuma" in text:
        return [
            "Aprofundar pesquisa",
            "Extrair pontos-chave",
            "Salvar resumo",
        ]
    if "agenda" in text or "reuniao" in text or "calendario" in text:
        return [
            "Criar lembrete",
            "Preparar reuniao",
            "Organizar proximos passos",
        ]
    return [
        "Continuar daqui",
        "Organizar proximos passos",
        "Salvar contexto",
    ]


def _infer_suggestions(
    *,
    user_text: str,
    reply: str,
    tool_name: str,
    approval_needed: bool,
) -> list[str]:
    text = f"{user_text} {reply}".casefold()
    suggestions: list[str] = []
    if approval_needed:
        suggestions.extend(
            [
                "Posso cuidar disso agora",
                "Quero revisar antes",
                "Explique o impacto",
            ]
        )
    if tool_name == "search_web":
        suggestions.extend(
            [
                "Montar briefing",
                "Gerar checklist",
                "Traduzir resultado",
            ]
        )
    if _contains_any(text, ("codigo", "flutter", "dev", "bug", "interface", "projeto")):
        suggestions.extend(
            [
                "Continuar projeto",
                "Gerar codigo",
                "Melhorar interface",
            ]
        )
    if _contains_any(text, ("finance", "financeiro", "orcamento", "custo", "receita")):
        suggestions.extend(
            [
                "Analisar numeros",
                "Criar previsao",
                "Resumir riscos",
            ]
        )
    if _contains_any(text, ("pesquisa", "pesquise", "pesquisar", "resuma", "explicar")):
        suggestions.extend(
            [
                "Aprofundar pesquisa",
                "Comparar opcoes",
                "Salvar referencia",
            ]
        )
    if not suggestions:
        suggestions.extend(
            [
                "Continuar daqui",
                "Organizar proximo passo",
                "Automatizar depois",
            ]
        )
    return _dedupe_items(suggestions, limit=3)


def _build_structured_payload(
    result: dict[str, Any],
    *,
    user_text: str,
) -> dict[str, Any]:
    reply = _clean_text(
        result.get("reply")
        or result.get("message")
        or result.get("explicacao")
        or result.get("resumo")
    )
    summary = _clean_text(result.get("resumo")) or _short_summary(reply)
    explanation = _clean_text(result.get("explicacao")) or reply or summary
    tool_name = _clean_text(result.get("tool_name"))
    approval_needed = bool(result.get("approval_needed"))

    raw_actions = result.get("acoes")
    raw_suggestions = result.get("sugestoes")
    actions = (
        _dedupe_items([str(item) for item in raw_actions], limit=3)
        if isinstance(raw_actions, list)
        else _infer_actions(
            user_text=user_text,
            reply=reply,
            tool_name=tool_name,
            approval_needed=approval_needed,
        )
    )
    suggestions = (
        _dedupe_items([str(item) for item in raw_suggestions], limit=3)
        if isinstance(raw_suggestions, list)
        else _infer_suggestions(
            user_text=user_text,
            reply=reply,
            tool_name=tool_name,
            approval_needed=approval_needed,
        )
    )

    return {
        **result,
        "reply": reply or explanation or summary,
        "resumo": summary or explanation,
        "explicacao": explanation or summary,
        "acoes": actions,
        "sugestoes": suggestions,
        "assistant_state": _clean_text(result.get("assistant_state"))
        or _infer_assistant_state(result, reply),
    }


def handle_chat_post(
    *,
    path: str,
    body: dict,
    process_message: Callable[[str], str],
    send_json: Callable[[dict], None],
) -> bool:
    if path != "/chat":
        return False

    if any(key in body for key in ("text", "user_id", "mode", "auto_approve")):
        orchestrator = get_default_orchestrator()
        user_id = str(body.get("user_id", "default")).strip() or "default"
        mode = str(body.get("mode", "normal")).strip() or "normal"
        text = str(body.get("text", body.get("message", ""))).strip()
        extra_context = str(body.get("context", "")).strip()
        if extra_context:
            text = (
                f"{text}\n\nContexto adicional:\n{extra_context}".strip()
                if text
                else extra_context
            )
        if user_id in _PENDING_STRUCTURED_CHAT:
            ctx = {
                "nome_usuario": user_id,
                "jarvis_tool_pending": _PENDING_STRUCTURED_CHAT.get(user_id),
            }
            pending_result = process_pending_tool_confirmation(text, ctx, mode=mode)
            if isinstance(pending_result, dict) and pending_result.get("handled"):
                next_pending = ctx.get("jarvis_tool_pending")
                if isinstance(next_pending, dict) and next_pending:
                    _PENDING_STRUCTURED_CHAT[user_id] = next_pending
                else:
                    _PENDING_STRUCTURED_CHAT.pop(user_id, None)
                send_json(
                    _build_structured_payload(
                        {"ok": True, **pending_result},
                        user_text=text,
                    )
                )
                return True

        result = orchestrator.handle(
            user_id,
            text,
            mode=mode,
            auto_approve=bool(body.get("auto_approve", False)),
        )
        if result.get("approval_needed"):
            _PENDING_STRUCTURED_CHAT[user_id] = {
                "tool_name": result.get("tool_name"),
                "params": result.get("params") or {},
                "prompt_text": text,
                "mode": mode,
            }
        else:
            _PENDING_STRUCTURED_CHAT.pop(user_id, None)
        send_json(
            _build_structured_payload(
                {"ok": True, **result},
                user_text=text,
            )
        )
        return True

    message = str(body.get("message", "")).strip()
    reply = process_message(message)
    send_json(
        _build_structured_payload(
            {"ok": True, "reply": reply},
            user_text=message,
        )
    )
    return True
