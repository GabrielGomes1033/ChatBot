from __future__ import annotations

from core.response_style import PERSONA_STYLES, normalize_mode, style_response


modos = {
    nome: {
        "prefixos": list(config.get("prefixes", [])),
        "sufixos": list(config.get("suffixes", [])),
    }
    for nome, config in PERSONA_STYLES.items()
}

modo_atual = "normal"


def set_modo(modo: str) -> str:
    global modo_atual
    modo_normalizado = normalize_mode(modo)
    if modo_normalizado in modos:
        modo_atual = modo_normalizado
        return f"Modo alterado para '{modo_atual.upper()}'"
    return "Modo nao encontrado."


def estilizar(resposta: str) -> str:
    return style_response(resposta, modo=modo_atual, use_persona=True)
