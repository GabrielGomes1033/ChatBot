from __future__ import annotations

import os
from typing import Any

import requests

from core.assistente_plus import pesquisar_na_internet
from core.kira_client import pesquisar_kira
from core.pesquisa import gerar_pesquisa_wikipedia
from core.pesquisa import buscar_opcoes_desambiguacao


BRAVE_SEARCH_URL = "https://api.search.brave.com/res/v1/web/search"


def _map_brave_results(payload: dict[str, Any]) -> list[dict[str, str]]:
    web = payload.get("web", {}) if isinstance(payload, dict) else {}
    items = web.get("results", []) if isinstance(web, dict) else []
    results: list[dict[str, str]] = []
    for item in items[:5]:
        if not isinstance(item, dict):
            continue
        title = str(item.get("title", "")).strip()
        snippet = str(item.get("description", "")).strip()
        url = str(item.get("url", "")).strip()
        if not (title or snippet or url):
            continue
        results.append(
            {
                "title": title,
                "snippet": snippet,
                "url": url,
            }
        )
    return results


def _summary_looks_noisy(text: str) -> bool:
    summary = str(text or "").strip()
    if not summary:
        return True
    first_sentence = summary.split(".", 1)[0]
    comma_count = first_sentence.count(",")
    repeated_short_fragments = len(first_sentence.split()) <= 12 and comma_count >= 2
    snippet_list_pattern = (
        comma_count >= 4 and " é " not in summary.lower() and " is " not in summary.lower()
    )
    return repeated_short_fragments or snippet_list_pattern


def _best_wikipedia_summary(query: str) -> dict[str, str] | None:
    wiki = gerar_pesquisa_wikipedia(query)
    if wiki:
        return wiki

    words = [part for part in str(query or "").split() if part.strip()]
    if len(words) >= 2:
        fallback_query = words[0].strip()
        if fallback_query:
            return gerar_pesquisa_wikipedia(fallback_query)
    return None


def search_web(query: str) -> dict[str, Any]:
    consulta = str(query or "").strip()
    if not consulta:
        return {"ok": False, "error": "query_required", "query": ""}

    ambiguity_options = buscar_opcoes_desambiguacao(consulta, max_opcoes=4)
    if ambiguity_options:
        return {
            "ok": True,
            "provider": "disambiguation",
            "query": consulta,
            "ambiguous": True,
            "options": ambiguity_options,
            "summary": "",
            "results": [],
            "sources": [],
        }

    kira_result = pesquisar_kira(consulta)
    warnings: list[str] = []
    if kira_result.get("ok"):
        summary = str(kira_result.get("summary", "")).strip()
        wiki = None
        if not any(
            token in consulta.lower()
            for token in ("hoje", "agora", "ultimas", "últimas", "recentes", "breaking")
        ):
            wiki = _best_wikipedia_summary(consulta)
        if wiki and (_summary_looks_noisy(summary) or len(consulta.split()) <= 4):
            summary = str(wiki.get("resumo", "")).strip() or summary
        return {
            "ok": True,
            "provider": "kira",
            "query": consulta,
            "summary": summary,
            "results": kira_result.get("results") or [],
            "sources": [],
            "raw_response": str(kira_result.get("raw_response", "")).strip(),
            "latency_ms": kira_result.get("latency_ms"),
        }
    if kira_result.get("error"):
        warnings.append(str(kira_result.get("error")))

    api_key = os.getenv("BRAVE_API_KEY") or os.getenv("NOVA_BRAVE_API_KEY")
    if api_key:
        try:
            response = requests.get(
                BRAVE_SEARCH_URL,
                headers={
                    "Accept": "application/json",
                    "X-Subscription-Token": api_key,
                },
                params={"q": consulta},
                timeout=15,
            )
            response.raise_for_status()
            payload = response.json() if response.text else {}
            results = _map_brave_results(payload)
            summary = ""
            if results:
                first = results[0]
                summary = first.get("snippet", "") or first.get("title", "")
            return {
                "ok": True,
                "provider": "brave",
                "query": consulta,
                "summary": summary,
                "results": results,
                "sources": [item.get("url", "") for item in results if item.get("url")],
                "warnings": warnings,
            }
        except Exception as exc:
            brave_error = str(exc)
        else:
            brave_error = ""
    else:
        brave_error = "brave_api_key_missing"

    fallback = pesquisar_na_internet(consulta)
    if fallback.get("ok"):
        links = [link for link in (fallback.get("links") or []) if isinstance(link, str)]
        return {
            "ok": True,
            "provider": "fallback_search",
            "query": consulta,
            "summary": str(fallback.get("resumo", "")).strip(),
            "results": [
                {
                    "title": str(fallback.get("consulta", consulta)).strip(),
                    "snippet": str(fallback.get("resumo", "")).strip(),
                    "url": links[0] if links else "",
                }
            ],
            "sources": links or [str(src).strip() for src in (fallback.get("fontes") or [])],
            "warnings": warnings + ([brave_error] if brave_error else []),
        }

    wiki = gerar_pesquisa_wikipedia(consulta)
    if wiki:
        url = str(wiki.get("url", "")).strip()
        return {
            "ok": True,
            "provider": "wikipedia",
            "query": consulta,
            "summary": str(wiki.get("resumo", "")).strip(),
            "results": [
                {
                    "title": str(wiki.get("titulo", consulta)).strip(),
                    "snippet": str(wiki.get("resumo", "")).strip(),
                    "url": url,
                }
            ],
            "sources": [url] if url else [],
            "warnings": warnings + ([brave_error] if brave_error else []),
        }

    return {
        "ok": False,
        "error": "search_unavailable",
        "query": consulta,
        "warnings": warnings + ([brave_error] if brave_error else []),
    }
