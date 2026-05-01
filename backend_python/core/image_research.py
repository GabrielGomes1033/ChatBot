from __future__ import annotations

from datetime import datetime
import re
from typing import Any

from core.assistente_plus import formatar_resposta_pesquisa
from integrations.brave_search import search_web


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", str(text or "").strip())


def _shorten(text: str, limit: int = 220) -> str:
    body = _clean(text)
    if len(body) <= limit:
        return body
    shortened = body[: max(50, limit)].rsplit(" ", 1)[0].strip()
    return (shortened or body[:limit]).rstrip(" ,.;:-") + "..."


def _normalize_label(item: Any) -> tuple[str, float]:
    if not isinstance(item, dict):
        return "", 0.0
    label = _clean(str(item.get("label", "")))
    try:
        confidence = float(item.get("confidence", 0.0) or 0.0)
    except Exception:
        confidence = 0.0
    return label, confidence


def _build_query(
    filename: str, recognized_text: str, labels: list[dict[str, Any]]
) -> tuple[str, str]:
    text = _clean(recognized_text)
    if text:
        words = re.findall(r"[A-Za-zÀ-ÿ0-9][A-Za-zÀ-ÿ0-9./&-]*", text)
        if len(words) >= 2:
            return (" ".join(words[:10]).strip(), "texto_detectado")

    normalized_labels = [
        label for label, confidence in (_normalize_label(item) for item in labels) if label
    ]
    if normalized_labels:
        top = normalized_labels[:3]
        if len(top) == 1:
            return (f"o que e {top[0]}", "objetos_detectados")
        return (" ".join(top), "objetos_detectados")

    stem = re.sub(r"\.[a-z0-9]{1,6}$", "", filename.strip(), flags=re.IGNORECASE)
    stem = re.sub(r"[_-]+", " ", stem)
    stem = _clean(stem)
    if stem and stem.lower() not in {"image", "img", "foto", "photo"}:
        return (stem, "nome_arquivo")
    return ("", "")


def _detect_risks(text: str) -> list[str]:
    lowered = text.lower()
    risks = []
    checks = {
        "senha": "A imagem pode expor senha ou credencial.",
        "token": "A imagem pode expor token ou chave de acesso.",
        "cpf": "A imagem pode expor dado pessoal sensível (CPF).",
        "cartao": "A imagem pode expor dado financeiro sensível.",
        "cartão": "A imagem pode expor dado financeiro sensível.",
        "pix": "A imagem menciona contexto financeiro via PIX.",
        "confidencial": "A imagem parece conter conteúdo confidencial.",
    }
    for token, message in checks.items():
        if token in lowered:
            risks.append(message)
    return risks


def _keywords_from_image(
    recognized_text: str, labels: list[dict[str, Any]]
) -> list[dict[str, Any]]:
    freq: dict[str, int] = {}

    for token in re.findall(r"[A-Za-zÀ-ÿ0-9_]{4,}", recognized_text.lower()):
        freq[token] = freq.get(token, 0) + 1

    for item in labels:
        label, confidence = _normalize_label(item)
        if not label:
            continue
        for token in re.findall(r"[a-zà-ÿ0-9_]{3,}", label.lower()):
            boost = max(1, int(round(confidence * 10)))
            freq[token] = freq.get(token, 0) + boost

    ordered = sorted(freq.items(), key=lambda entry: entry[1], reverse=True)[:12]
    return [{"token": token, "count": count} for token, count in ordered]


def analisar_imagem_contextualizada(
    *,
    filename: str,
    metadata: dict[str, Any] | None = None,
    recognized_text: str = "",
    labels: list[dict[str, Any]] | None = None,
    from_camera: bool = False,
    byte_size: int = 0,
) -> dict[str, Any]:
    metadata = metadata if isinstance(metadata, dict) else {}
    labels = labels if isinstance(labels, list) else []

    query, query_source = _build_query(filename, recognized_text, labels)
    normalized_text = _clean(recognized_text)
    image_labels = [
        {"label": label, "confidence": round(confidence, 2)}
        for label, confidence in (_normalize_label(item) for item in labels)
        if label
    ]

    if not query:
        return {
            "ok": True,
            "report": {
                "file_name": filename or "imagem",
                "generated_at": datetime.now().isoformat(timespec="seconds"),
                "analysis_type": "image",
                "source": "camera" if from_camera else "imagem",
                "stats": {
                    "bytes": int(byte_size or 0),
                    "chars": len(normalized_text),
                    "words": len(normalized_text.split()) if normalized_text else 0,
                    "estimated_pages": 1,
                },
                "image": metadata,
                "detected_labels": image_labels,
                "executive_summary": (
                    "Não encontrei pista suficiente para pesquisar essa imagem com segurança. "
                    "Se puder, envie uma foto mais nítida, com o objeto centralizado ou com algum texto visível."
                ),
                "keywords": _keywords_from_image(normalized_text, labels),
                "risks": _detect_risks(normalized_text),
                "sample_excerpts": [],
                "recommendations": [
                    "Tente reenviar a imagem com melhor foco e iluminação.",
                    "Se houver texto, placa, embalagem ou nome visível, deixe isso no enquadramento.",
                    "Se quiser, descreva o que você quer identificar e eu refaço a busca por esse contexto.",
                ],
            },
            "learning": {
                "ok": False,
                "skipped": True,
                "local_fallback": True,
                "message": "Sem sinal suficiente para pesquisa web confiável da imagem.",
                "subject_memory": {"subjects": []},
            },
        }

    result = search_web(query)
    summary = (
        formatar_resposta_pesquisa(result)
        if result.get("ok")
        else (
            "Consegui extrair pistas da imagem, mas a pesquisa online não respondeu com confiança agora."
        )
    )

    labels_text = ", ".join(item["label"] for item in image_labels[:4])
    excerpts = []
    if labels_text:
        excerpts.append(f"Objetos detectados: {labels_text}")
    if normalized_text:
        excerpts.append(f"Texto identificado: {_shorten(normalized_text, 280)}")
    excerpts.append(f"Consulta gerada para pesquisa: {query}")

    recommendations = [
        "Se quiser, posso aprofundar só no objeto, só no lugar ou só no texto detectado.",
        "Para melhorar a identificação, envie uma imagem mais nítida e com o assunto principal em destaque.",
    ]
    if query_source == "texto_detectado":
        recommendations.append(
            "A pesquisa ficou mais confiável porque havia texto legível na imagem."
        )
    elif query_source == "objetos_detectados":
        recommendations.append(
            "A pesquisa foi guiada pelos objetos detectados localmente, então pode valer refinar se houver mais contexto."
        )

    return {
        "ok": True,
        "report": {
            "file_name": filename or "imagem",
            "generated_at": datetime.now().isoformat(timespec="seconds"),
            "analysis_type": "image",
            "source": "camera" if from_camera else "imagem",
            "stats": {
                "bytes": int(byte_size or 0),
                "chars": len(normalized_text),
                "words": len(normalized_text.split()) if normalized_text else 0,
                "estimated_pages": 1,
            },
            "image": metadata,
            "detected_labels": image_labels,
            "research_query": query,
            "executive_summary": summary,
            "keywords": _keywords_from_image(normalized_text, labels),
            "risks": _detect_risks(normalized_text),
            "sample_excerpts": excerpts[:4],
            "recommendations": recommendations,
        },
        "learning": {
            "ok": False,
            "skipped": True,
            "local_fallback": False,
            "message": "Pesquisa de imagem combinada com pistas locais e busca web.",
            "subject_memory": {"subjects": []},
        },
    }
