from __future__ import annotations

import re
import time
from typing import Any

import requests


KIRA_URL = "https://kira-knowledge-intelligence-research.onrender.com/pesquisar"
KIRA_TIMEOUT = 25
KIRA_HEADERS = {
    "Content-Type": "application/json",
    "User-Agent": "NOVA-KIRA/1.0",
}


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", str(text or "").strip())


def _strip_markdown(text: str) -> str:
    cleaned = str(text or "")
    cleaned = re.sub(r"!\[[^\]]*]\([^)]+\)", " ", cleaned)
    cleaned = re.sub(r"\[([^\]]+)]\([^)]+\)", r"\1", cleaned)
    cleaned = re.sub(r"`{1,3}", "", cleaned)
    cleaned = re.sub(r"[*_#>~-]+", " ", cleaned)
    cleaned = re.sub(r"\s+", " ", cleaned)
    return cleaned.strip()


def _split_sentences(text: str) -> list[str]:
    return [
        part.strip() for part in re.split(r"(?<=[.!?])\s+", _strip_markdown(text)) if part.strip()
    ]


def _shorten(text: str, limit: int = 320) -> str:
    body = _clean(text)
    if len(body) <= limit:
        return body
    shortened = body[: max(60, limit)].rsplit(" ", 1)[0].strip()
    return (shortened or body[:limit]).rstrip(" ,.;:-") + "..."


def _summary_from_text(text: str, *, max_sentences: int = 2, limit: int = 360) -> str:
    sentences = _split_sentences(text)
    if not sentences:
        return ""
    summary = " ".join(sentences[:max_sentences]).strip()
    return _shorten(summary or text, limit=limit)


def _parse_sections(raw_response: str) -> dict[str, str]:
    text = str(raw_response or "").strip()
    if not text:
        return {}

    parts = re.split(r"(?m)^##\s+", text)
    sections: dict[str, str] = {}
    for part in parts:
        block = part.strip()
        if not block:
            continue
        if "\n" not in block:
            sections[_clean(block).lower()] = ""
            continue
        title, content = block.split("\n", 1)
        sections[_clean(title).lower()] = content.strip()
    return sections


def _extract_points(section_text: str) -> list[dict[str, str]]:
    items: list[dict[str, str]] = []
    seen: set[str] = set()
    for raw_line in re.split(r"(?m)^\s*\d+\.\s+", "\n" + str(section_text or "")):
        line = _strip_markdown(raw_line)
        if not line:
            continue
        line = _clean(line)
        if not line or line.lower() in seen:
            continue
        seen.add(line.lower())

        title = line
        snippet = ""
        if " — " in line:
            title, snippet = line.split(" — ", 1)
        elif " - " in line:
            title, snippet = line.split(" - ", 1)
        elif ":" in line and len(line.split(":", 1)[0]) <= 80:
            title, snippet = line.split(":", 1)

        items.append(
            {
                "title": _shorten(title, 110),
                "snippet": _shorten(snippet or line, 180),
            }
        )
        if len(items) >= 4:
            break
    return items


def _is_generic_objective(summary: str) -> bool:
    normalized = _clean(summary).lower()
    if not normalized:
        return True
    return normalized.startswith("a pergunta central é")


def _build_chat_payload(query: str, raw_response: str) -> dict[str, Any]:
    sections = _parse_sections(raw_response)
    objective = _summary_from_text(
        sections.get("resposta objetiva", ""), max_sentences=2, limit=280
    )
    detailed = _summary_from_text(
        sections.get("alto resumo detalhado", ""),
        max_sentences=3,
        limit=420,
    )
    points = _extract_points(sections.get("pontos principais", ""))

    summary = objective
    if _is_generic_objective(summary):
        summary = detailed or objective
    if not summary and points:
        summary = _shorten(points[0].get("snippet", ""), 280)
    if not summary:
        summary = _summary_from_text(raw_response, max_sentences=3, limit=420)

    if summary:
        summary = re.sub(
            r"(?i)^a pergunta central e:\s*",
            "",
            summary,
        ).strip()
        summary = re.sub(
            r"(?i)^pelas fontes encontradas,\s*o tema envolve principalmente:\s*",
            "",
            summary,
        ).strip()

    return {
        "ok": bool(summary or points),
        "provider": "kira",
        "query": _clean(query),
        "summary": summary,
        "results": points,
        "raw_response": _clean(raw_response),
    }


def pesquisar_kira(query: str, *, timeout: int = KIRA_TIMEOUT) -> dict[str, Any]:
    consulta = _clean(query)
    if not consulta:
        return {"ok": False, "error": "query_required", "query": ""}

    started = time.perf_counter()
    try:
        response = requests.post(
            KIRA_URL,
            json={"query": consulta},
            headers=KIRA_HEADERS,
            timeout=timeout,
        )
        response.raise_for_status()
        payload = response.json() if response.text else {}
    except requests.exceptions.Timeout:
        return {
            "ok": False,
            "error": "kira_timeout",
            "query": consulta,
            "message": "A KIRA demorou mais do que o esperado para responder.",
        }
    except requests.RequestException as exc:
        return {
            "ok": False,
            "error": "kira_request_failed",
            "query": consulta,
            "message": f"Falha de conexão com a KIRA: {exc}",
        }
    except ValueError:
        return {
            "ok": False,
            "error": "kira_invalid_json",
            "query": consulta,
            "message": "A KIRA respondeu em um formato inválido.",
        }

    if payload.get("status") != "ok":
        return {
            "ok": False,
            "error": "kira_not_ok",
            "query": consulta,
            "message": str(payload.get("mensagem") or "A KIRA não retornou status OK."),
        }

    raw_response = str(payload.get("resposta", "")).strip()
    formatted = _build_chat_payload(consulta, raw_response)
    formatted["latency_ms"] = round((time.perf_counter() - started) * 1000, 2)

    if not formatted.get("ok"):
        return {
            "ok": False,
            "error": "kira_empty_response",
            "query": consulta,
            "message": "A KIRA respondeu, mas sem conteúdo útil para o chat.",
            "raw_response": raw_response,
        }

    return formatted


def verificar_conexao_kira(*, timeout: int = 12) -> dict[str, Any]:
    started = time.perf_counter()
    result = pesquisar_kira("teste de conectividade", timeout=timeout)
    return {
        "ok": bool(result.get("ok")),
        "provider": "kira",
        "latency_ms": round((time.perf_counter() - started) * 1000, 2),
        "message": result.get("message") or result.get("summary") or "",
        "error": result.get("error", ""),
    }


def perguntar_kira(pergunta: str) -> str:
    result = pesquisar_kira(pergunta)
    if result.get("ok"):
        return str(result.get("summary") or result.get("raw_response") or "").strip()
    return str(result.get("message") or "Não consegui conectar com a KIRA.").strip()
