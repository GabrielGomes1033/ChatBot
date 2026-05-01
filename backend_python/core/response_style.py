from __future__ import annotations

import random


PERSONA_STYLES = {
    "normal": {
        "prefixes": ["", "", ""],
        "suffixes": ["", "", ""],
    },
    "engracado": {
        "prefixes": ["Olha so...", "Hmm, interessante:", "KKK, vamos la:"],
        "suffixes": ["", " Essa foi boa.", " Nada mal, vai."],
    },
    "formal": {
        "prefixes": ["Compreendo.", "De acordo com sua solicitacao:", "Certamente."],
        "suffixes": [" Estou a disposicao.", " Se precisar de mais ajuda, me avise.", ""],
    },
    "sarcastico": {
        "prefixes": ["Ah, claro...", "Nossa, que surpresa...", "Uau, totalmente inesperado..."],
        "suffixes": ["", " Incrivel, ne?", " O obvio sempre se esforca."],
    },
    "inspirador": {
        "prefixes": ["Lembre-se:", "Aqui vai uma reflexao:", "Para voce pensar:"],
        "suffixes": ["", " Segue firme.", " Um passo de cada vez."],
    },
    "tecnologico": {
        "prefixes": ["Processando:", "Analisando dados:", "Sinal recebido:"],
        "suffixes": ["", " Diagnostico concluido.", " Fluxo validado."],
    },
}

STRUCTURED_MODES = {"compacto", "executivo", "tecnico", "estrategico"}
PERSONA_ALIASES = {
    "casual": "normal",
    "humano": "normal",
    "humana": "normal",
    "humor": "engracado",
    "brincalhao": "engracado",
    "brincalhona": "engracado",
    "sarc": "sarcastico",
    "sarcasmo": "sarcastico",
    "tech": "tecnologico",
}


def _clean_text(text: str) -> str:
    return " ".join(str(text or "").strip().split())


def _truncate(text: str, limit: int) -> str:
    body = _clean_text(text)
    if len(body) <= limit:
        return body
    shortened = body[: max(40, limit)].rsplit(" ", 1)[0].strip()
    return (shortened or body[:limit]).rstrip(" ,.;:-") + "..."


def normalize_mode(modo: str | None) -> str:
    normalized = _clean_text(str(modo or "normal")).lower() or "normal"
    return PERSONA_ALIASES.get(normalized, normalized)


def _apply_structured_mode(body: str, modo_normalizado: str) -> str:
    if modo_normalizado == "compacto":
        return _truncate(body, 180)
    if modo_normalizado == "executivo":
        return f"Resumo executivo:\n{body}"
    if modo_normalizado == "tecnico":
        return f"Analise tecnica:\n{body}"
    if modo_normalizado == "estrategico":
        return f"Visao estrategica:\n{body}"
    return body


def _apply_persona(body: str, modo_normalizado: str) -> str:
    style = PERSONA_STYLES.get(modo_normalizado, PERSONA_STYLES["normal"])
    prefix = random.choice(style["prefixes"]).strip()
    suffix = random.choice(style["suffixes"]).strip()

    if prefix:
        body = f"{prefix} {body}"
    if suffix:
        body = f"{body} {suffix}"
    return body


def style_response(
    texto_base: str,
    modo: str = "normal",
    *,
    use_persona: bool = False,
) -> str:
    body = str(texto_base or "").strip()
    if not body:
        return ""

    modo_normalizado = normalize_mode(modo)
    if modo_normalizado in STRUCTURED_MODES:
        return _apply_structured_mode(body, modo_normalizado)
    if use_persona or (modo_normalizado in PERSONA_STYLES and modo_normalizado != "normal"):
        return _apply_persona(body, modo_normalizado)
    return body
