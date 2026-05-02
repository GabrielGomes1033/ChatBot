# Utilitários de pesquisa da NOVA.
# Este módulo tenta gerar um resumo curto do tema pesquisado antes de abrir a busca no navegador.
from __future__ import annotations

import re
from urllib.parse import quote
import unicodedata

import requests


TIMEOUT_PADRAO = 4
WIKIPEDIA_HEADERS = {"User-Agent": "NOVA-Assistente/1.0 (resumo de pesquisa local)"}


def _limpar_texto(texto: str) -> str:
    # Remove excesso de espaços, referências e trechos que não ficam naturais no chat.
    texto = re.sub(r"\[[^\]]+\]", " ", texto)
    texto = re.sub(r"\s+", " ", texto).strip()
    return texto


def _resumo_curto(texto: str, limite_sentencas: int = 3, limite_chars: int = 520) -> str:
    # Encurta o texto para algo breve e agradável de ler e ouvir.
    texto = _limpar_texto(texto)
    partes = re.split(r"(?<=[.!?])\s+", texto)
    resumo = " ".join(parte for parte in partes[:limite_sentencas] if parte).strip()
    if not resumo:
        resumo = texto

    if len(resumo) > limite_chars:
        corte = resumo[:limite_chars].rsplit(" ", 1)[0].strip()
        resumo = f"{corte}..."

    return resumo


def _normalizar_ascii(texto: str) -> str:
    base = unicodedata.normalize("NFKD", texto or "")
    return re.sub(r"\s+", " ", base.encode("ascii", "ignore").decode("ascii").lower()).strip()


def _buscar_titulos_wikipedia(consulta: str, idioma: str, limit: int = 5) -> list[str]:
    url = (
        f"https://{idioma}.wikipedia.org/w/api.php"
        f"?action=opensearch&search={quote(consulta)}&limit={max(1, limit)}&namespace=0&format=json"
    )
    resposta = requests.get(url, headers=WIKIPEDIA_HEADERS, timeout=TIMEOUT_PADRAO)
    resposta.raise_for_status()
    dados = resposta.json()
    titulos = dados[1] if isinstance(dados, list) and len(dados) > 1 else []
    return [str(t).strip() for t in titulos if str(t).strip()]


def _buscar_titulo_wikipedia(consulta: str, idioma: str) -> str | None:
    # Usa a busca da Wikipedia para encontrar a página mais provável para a consulta.
    titulos = _buscar_titulos_wikipedia(consulta, idioma, limit=1)
    if not titulos:
        return None
    return titulos[0]


def _buscar_resumo_wikipedia_direto(titulo: str, idioma: str) -> dict[str, str] | None:
    url = f"https://{idioma}.wikipedia.org/api/rest_v1/page/summary/{quote(titulo)}"
    resposta = requests.get(url, headers=WIKIPEDIA_HEADERS, timeout=TIMEOUT_PADRAO)
    if resposta.status_code == 404:
        return None
    resposta.raise_for_status()
    dados = resposta.json()
    extrato = str(dados.get("extract", "")).strip()
    if not extrato:
        return None
    return {
        "titulo": str(dados.get("title") or titulo).strip(),
        "tipo": str(dados.get("type") or "").strip(),
        "extrato": extrato,
    }


def _buscar_resumo_wikipedia_por_titulo(titulo: str, idioma: str) -> str | None:
    # Busca o resumo da página encontrada.
    pagina = _buscar_resumo_wikipedia_direto(titulo, idioma)
    if not pagina:
        return None
    return _resumo_curto(pagina["extrato"])


def gerar_pesquisa_wikipedia(consulta: str) -> dict[str, str] | None:
    # Busca um artigo na Wikipedia e devolve os dados principais para chat, link e voz.
    consulta = consulta.strip()
    if not consulta:
        return None

    for idioma, fonte in (("pt", "Wikipedia PT"), ("en", "Wikipedia EN")):
        try:
            titulo = _buscar_titulo_wikipedia(consulta, idioma)
            if not titulo:
                continue
            resumo = _buscar_resumo_wikipedia_por_titulo(titulo, idioma)
            if resumo:
                return {
                    "titulo": titulo,
                    "resumo": resumo,
                    "fonte": fonte,
                    "url": f"https://{idioma}.wikipedia.org/wiki/{quote(titulo.replace(' ', '_'))}",
                }
        except requests.RequestException:
            continue

    return None


def gerar_resumo_pesquisa(consulta: str) -> tuple[str | None, str | None]:
    # Mantém compatibilidade com o fluxo antigo quando só o resumo é necessário.
    resultado = gerar_pesquisa_wikipedia(consulta)
    if not resultado:
        return None, None
    return resultado["resumo"], resultado["fonte"]


def _consulta_parece_ambigua(consulta: str) -> bool:
    texto = _normalizar_ascii(consulta)
    if not texto:
        return False
    palavras = [p for p in texto.split() if p]
    if len(palavras) > 2:
        return False
    pistas_de_contexto = {
        "linguagem",
        "programacao",
        "programming",
        "empresa",
        "company",
        "rio",
        "river",
        "ilha",
        "island",
        "cobra",
        "snake",
        "framework",
        "livro",
        "book",
        "filme",
        "movie",
        "aws",
        "pypi",
    }
    return not any(token in texto for token in pistas_de_contexto)


def _titulo_relacionado_a_consulta(titulo: str, consulta: str) -> bool:
    titulo_n = _normalizar_ascii(titulo)
    consulta_n = _normalizar_ascii(consulta)
    if not titulo_n or not consulta_n:
        return False
    if titulo_n == consulta_n:
        return True
    return bool(re.search(rf"\b{re.escape(consulta_n)}\b", titulo_n))


def _pontuar_opcao_ambiguidade(titulo: str, descricao: str, consulta: str) -> int:
    titulo_n = _normalizar_ascii(titulo)
    desc_n = _normalizar_ascii(descricao)
    consulta_n = _normalizar_ascii(consulta)
    score = 0

    if titulo_n == consulta_n:
        score += 5
    if "(" in titulo and ")" in titulo:
        score += 3
    if any(
        token in desc_n
        for token in (
            "linguagem de programacao",
            "programming language",
            "empresa",
            "company",
            "rio",
            "river",
            "ilha",
            "island",
            "serpente",
            "snake",
            "familia",
            "family",
            "floresta",
            "rainforest",
            "servico",
            "service",
        )
    ):
        score += 4
    if any(
        token in f"{titulo_n} {desc_n}"
        for token in (
            "version history",
            "syntax",
            "semantics",
            "fluente",
            "livro",
            "book",
            "episodio",
            "episode",
            "lista",
        )
    ):
        score -= 4
    return score


def buscar_opcoes_desambiguacao(consulta: str, max_opcoes: int = 4) -> list[dict[str, str]]:
    consulta = consulta.strip()
    if not _consulta_parece_ambigua(consulta):
        return []

    candidatos: dict[str, dict[str, str]] = {}
    for idioma in ("pt", "en"):
        try:
            titulos = _buscar_titulos_wikipedia(consulta, idioma, limit=8)
        except requests.RequestException:
            continue

        for titulo in titulos:
            if not _titulo_relacionado_a_consulta(titulo, consulta):
                continue
            try:
                pagina = _buscar_resumo_wikipedia_direto(titulo, idioma)
            except requests.RequestException:
                continue
            if not pagina:
                continue

            descricao = _resumo_curto(pagina["extrato"], limite_sentencas=1, limite_chars=160)
            score = _pontuar_opcao_ambiguidade(pagina["titulo"], descricao, consulta)
            if score <= 0:
                continue

            chave = _normalizar_ascii(pagina["titulo"])
            existente = candidatos.get(chave)
            if isinstance(existente, dict):
                score_atual = int(existente.get("_score", 0))
                if score <= score_atual:
                    continue

            candidatos[chave] = {
                "title": pagina["titulo"],
                "description": descricao,
                "_score": str(score),
            }

    ordenados = sorted(
        (
            {
                "title": str(item.get("title", "")).strip(),
                "description": str(item.get("description", "")).strip(),
                "_score": int(str(item.get("_score", "0"))),
            }
            for item in candidatos.values()
            if isinstance(item, dict)
        ),
        key=lambda entry: (entry["_score"], len(entry["title"])),
        reverse=True,
    )

    saida: list[dict[str, str]] = []
    vistos = set()
    for item in ordenados:
        titulo = item["title"]
        descricao = item["description"]
        chave = (_normalizar_ascii(titulo), _normalizar_ascii(descricao))
        if chave in vistos:
            continue
        vistos.add(chave)
        saida.append({"title": titulo, "description": descricao})
        if len(saida) >= max(2, max_opcoes):
            break

    return saida if len(saida) >= 2 else []
