from __future__ import annotations

from core.kira_client import pesquisar_kira


def consultar_kira(pergunta: str) -> str | None:
    result = pesquisar_kira(pergunta)
    if result.get("ok"):
        return str(result.get("raw_response") or result.get("summary") or "").strip() or None
    return None
