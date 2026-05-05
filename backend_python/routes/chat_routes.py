from __future__ import annotations

import re
from typing import Any, Callable

from core.dev_assistente import gerar_codigo_por_ideia
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


def _extract_dev_chat_request(text: str, extra_context: str = "") -> dict[str, str]:
    lines = [
        _clean_text(line)
        for line in str(text or "").splitlines()
        if _clean_text(line)
    ]
    prompt_parts: list[str] = []
    language = ""
    project_name = ""

    for line in lines:
        lowered = line.casefold()
        if lowered.startswith("gerar codigo:"):
            prompt_parts.append(line.split(":", 1)[1].strip())
            continue
        if lowered.startswith("linguagem:"):
            language = line.split(":", 1)[1].strip()
            continue
        if lowered.startswith("projeto:"):
            project_name = line.split(":", 1)[1].strip()
            continue
        if lowered.startswith("contexto adicional:"):
            continue
        if lowered.startswith("priorizar geracao em "):
            continue
        if re.match(r"^usar\s+.+\s+como nome do projeto\.?$", lowered):
            continue
        prompt_parts.append(line)

    normalized_extra = _clean_text(extra_context)
    if not language:
        language_match = re.search(
            r"priorizar geracao em\s+([a-z0-9_+#.-]+)",
            normalized_extra,
            flags=re.IGNORECASE,
        )
        if language_match:
            language = language_match.group(1).strip()
    if not project_name:
        project_match = re.search(
            r"usar\s+([a-z0-9_./-]+)\s+como nome do projeto",
            normalized_extra,
            flags=re.IGNORECASE,
        )
        if project_match:
            project_name = project_match.group(1).strip()

    prompt = " ".join(prompt_parts).strip()
    if not prompt:
        prompt = _clean_text(text)
    prompt = re.sub(r"^gerar codigo:\s*", "", prompt, flags=re.IGNORECASE).strip()

    return {
        "prompt": prompt,
        "language": language.strip(),
        "project_name": project_name.strip(),
    }


def _build_dev_payload(generated: dict[str, Any]) -> dict[str, Any]:
    answer = _clean_text(generated.get("answer"))
    summary = _clean_text(generated.get("summary")) or answer
    return {
        "ok": True,
        "status": "ok",
        "type": "dev",
        "answer": answer,
        "reply": answer,
        "resumo": summary,
        "explicacao": answer,
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
        raw_text = text
        if extra_context:
            text = (
                f"{text}\n\nContexto adicional:\n{extra_context}".strip()
                if text
                else extra_context
            )
        if mode == "dev":
            _PENDING_STRUCTURED_CHAT.pop(user_id, None)
            request = _extract_dev_chat_request(raw_text or text, extra_context)
            try:
                generated = gerar_codigo_por_ideia(
                    request["prompt"],
                    language=request["language"],
                    project_name=request["project_name"],
                )
            except ValueError:
                send_json(
                    {
                        "ok": False,
                        "error": "prompt_not_supported",
                        "reply": "Nao consegui interpretar esse pedido de geracao de codigo.",
                        "resumo": "Pedido de codigo nao reconhecido.",
                        "explicacao": (
                            "Nao consegui interpretar esse pedido de geracao de codigo."
                        ),
                        "assistant_state": "responding",
                        "next_actions": [
                            "Continuar projeto",
                            "Gerar codigo",
                            "Melhorar interface",
                        ],
                    },
                    400,
                )
                return True
            send_json(_build_dev_payload(generated))
            return True
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
