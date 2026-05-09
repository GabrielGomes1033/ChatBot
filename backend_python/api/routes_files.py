from __future__ import annotations

import base64
from datetime import datetime
import mimetypes
from pathlib import Path
import re
from typing import Any
from uuid import uuid4

try:
    from fastapi import APIRouter, Depends
    from fastapi.responses import JSONResponse
except Exception:
    APIRouter = None
    Depends = None
    JSONResponse = None

from core.caminhos import pasta_dados_app
from core.document_analysis import analisar_documento_base64
from core.image_research import analisar_imagem_contextualizada

from .dependencies import rate_limit, require_token


UPLOADS_DIR = pasta_dados_app() / "uploads"
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

_IMAGE_EXTENSIONS = {"png", "jpg", "jpeg", "webp", "bmp", "gif"}


def _json(payload: dict[str, Any], status_code: int = 200):
    return JSONResponse(content=payload, status_code=status_code)


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _safe_filename(filename: str) -> str:
    cleaned = re.sub(r"[^a-zA-Z0-9._-]+", "_", str(filename or "").strip())
    cleaned = cleaned.strip("._")
    return cleaned or "arquivo"


def _detect_mime_type(filename: str, declared: str = "") -> str:
    normalized = str(declared or "").strip().lower()
    if normalized:
        return normalized
    guessed, _ = mimetypes.guess_type(_safe_filename(filename))
    return guessed or "application/octet-stream"


def _file_extension(filename: str) -> str:
    suffix = Path(_safe_filename(filename)).suffix.lower()
    return suffix[1:] if suffix.startswith(".") else suffix


def _is_image(filename: str, mime_type: str) -> bool:
    if str(mime_type or "").lower().startswith("image/"):
        return True
    return _file_extension(filename) in _IMAGE_EXTENSIONS


def _meta_path(file_id: str) -> Path:
    return UPLOADS_DIR / f"{file_id}.json"


def _blob_path(file_id: str, filename: str) -> Path:
    suffix = Path(_safe_filename(filename)).suffix
    return UPLOADS_DIR / f"{file_id}{suffix}"


def _read_meta(file_id: str) -> dict[str, Any] | None:
    path = _meta_path(file_id)
    if not path.exists():
        return None
    try:
        import json

        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return None


def _write_meta(meta: dict[str, Any]) -> None:
    import json

    file_id = str(meta.get("file_id", "")).strip()
    if not file_id:
        raise ValueError("file_id is required")
    _meta_path(file_id).write_text(
        json.dumps(meta, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )


def _build_next_actions(analysis_type: str) -> list[str]:
    if analysis_type == "image":
        return [
            "Melhorar interface",
            "Gerar codigo",
            "Salvar analise na memoria",
        ]
    return [
        "Resumir pontos principais",
        "Gerar codigo",
        "Salvar contexto",
    ]


def _format_keywords(report: dict[str, Any]) -> str:
    keywords = report.get("keywords")
    if not isinstance(keywords, list):
        return ""
    items: list[str] = []
    for item in keywords[:4]:
        if not isinstance(item, dict):
            continue
        token = str(item.get("token", "")).strip()
        if token:
            items.append(token)
    return ", ".join(items)


def _build_human_answer(
    *,
    analysis_type: str,
    filename: str,
    report: dict[str, Any],
) -> str:
    summary = str(report.get("executive_summary", "")).strip()
    risks = report.get("risks") if isinstance(report.get("risks"), list) else []
    recommendations = (
        report.get("recommendations")
        if isinstance(report.get("recommendations"), list)
        else []
    )
    keywords = _format_keywords(report)

    if analysis_type == "image":
        lines = [
            f"Analisei a imagem `{filename}`.",
            summary or "Consegui interpretar a cena com base no contexto enviado.",
        ]
        if keywords:
            lines.append(f"Elementos importantes: {keywords}.")
        if risks:
            lines.append(f"Pontos de atenção: {str(risks[0]).strip()}")
        if recommendations:
            lines.append(f"Próximo passo sugerido: {str(recommendations[0]).strip()}")
        return " ".join(line for line in lines if line).strip()

    lines = [
        f"Li o documento `{filename}` e extraí o conteúdo principal.",
        summary or "O conteúdo foi processado com sucesso.",
    ]
    if keywords:
        lines.append(f"Tópicos centrais: {keywords}.")
    if risks:
        lines.append(f"Ponto de atenção: {str(risks[0]).strip()}")
    if recommendations:
        lines.append(f"Próximo passo sugerido: {str(recommendations[0]).strip()}")
    return " ".join(line for line in lines if line).strip()


def _analysis_prompt_from_report(
    *,
    filename: str,
    meta: dict[str, Any],
    report: dict[str, Any],
) -> str:
    analysis_type = str(report.get("analysis_type", "")).strip() or (
        "image" if _is_image(filename, str(meta.get("mime_type", ""))) else "document"
    )
    summary = str(report.get("executive_summary", "")).strip()
    risks = report.get("risks") if isinstance(report.get("risks"), list) else []
    keywords = _format_keywords(report)
    parts = [
        f"Arquivo anexado: {filename}",
        f"Tipo: {analysis_type}",
    ]
    if summary:
        parts.append(f"Resumo da analise: {summary}")
    if keywords:
        parts.append(f"Palavras-chave: {keywords}")
    if risks:
        parts.append(f"Riscos/pontos de atencao: {'; '.join(str(item).strip() for item in risks[:3])}")
    return "\n".join(parts).strip()


def create_uploaded_file(
    *,
    filename: str,
    content_base64: str,
    mime_type: str = "",
    source: str = "upload",
) -> dict[str, Any]:
    raw = str(content_base64 or "").strip()
    if not raw:
        return {"ok": False, "error": "content_required"}

    try:
        data = base64.b64decode(raw, validate=False)
    except Exception:
        return {"ok": False, "error": "content_invalid_base64"}

    if not data:
        return {"ok": False, "error": "content_empty"}

    safe_name = _safe_filename(filename)
    resolved_mime = _detect_mime_type(safe_name, mime_type)
    file_id = uuid4().hex
    blob = _blob_path(file_id, safe_name)
    blob.write_bytes(data)

    meta = {
        "file_id": file_id,
        "filename": safe_name,
        "mime_type": resolved_mime,
        "size_bytes": len(data),
        "source": source,
        "created_at": _now(),
        "stored_path": str(blob),
        "analysis": None,
    }
    _write_meta(meta)
    return {
        "ok": True,
        "file_id": file_id,
        "file_name": safe_name,
        "mime_type": resolved_mime,
        "size_bytes": len(data),
        "source": source,
    }


def analyze_uploaded_file(
    *,
    file_id: str,
    question: str = "",
    context: str = "",
    recognized_text: str = "",
    labels: list[dict[str, Any]] | None = None,
    metadata: dict[str, Any] | None = None,
    from_camera: bool = False,
) -> dict[str, Any]:
    meta = _read_meta(file_id)
    if not meta:
        return {"ok": False, "error": "file_not_found"}

    filename = str(meta.get("filename", "")).strip() or "arquivo"
    mime_type = str(meta.get("mime_type", "")).strip()
    stored_path = Path(str(meta.get("stored_path", "")).strip())
    if not stored_path.exists():
        return {"ok": False, "error": "file_missing_on_disk"}

    data = stored_path.read_bytes()
    is_image = _is_image(filename, mime_type)

    if is_image:
        analysis_payload = analisar_imagem_contextualizada(
            filename=filename,
            metadata=metadata if isinstance(metadata, dict) else {},
            recognized_text=recognized_text,
            labels=labels if isinstance(labels, list) else [],
            from_camera=from_camera or str(meta.get("source", "")).strip() == "camera",
            byte_size=len(data),
        )
        report = (
            analysis_payload.get("report")
            if isinstance(analysis_payload.get("report"), dict)
            else {}
        )
        report["recognized_text"] = recognized_text.strip()
        analysis_type = "image"
    else:
        analysis_payload = analisar_documento_base64(
            filename,
            base64.b64encode(data).decode("utf-8"),
            auto_learn=False,
        )
        report = (
            analysis_payload.get("report")
            if isinstance(analysis_payload.get("report"), dict)
            else {}
        )
        report["analysis_type"] = "document"
        analysis_type = "document"

    if not analysis_payload.get("ok"):
        return analysis_payload

    answer = _build_human_answer(
        analysis_type=analysis_type,
        filename=filename,
        report=report,
    )
    prompt_context = _analysis_prompt_from_report(
        filename=filename,
        meta=meta,
        report=report,
    )
    next_actions = _build_next_actions(analysis_type)

    meta["analysis"] = {
        "status": "ok",
        "analysis_type": analysis_type,
        "generated_at": _now(),
        "question": str(question or "").strip(),
        "context": str(context or "").strip(),
        "answer": answer,
        "next_actions": next_actions,
        "payload": analysis_payload,
        "prompt_context": prompt_context,
    }
    _write_meta(meta)

    return {
        "ok": True,
        "status": "ok",
        "type": "analysis",
        "file_id": file_id,
        "file_name": filename,
        "analysis_type": analysis_type,
        "answer": answer,
        "next_actions": next_actions,
        "analysis": analysis_payload,
        "prompt_context": prompt_context,
    }


def build_file_chat_context(file_id: str) -> dict[str, Any] | None:
    meta = _read_meta(file_id)
    if not meta:
        return None
    analysis = meta.get("analysis")
    if isinstance(analysis, dict):
        prompt_context = str(analysis.get("prompt_context", "")).strip()
        if prompt_context:
            return {
                "file_id": file_id,
                "file_name": str(meta.get("filename", "")).strip(),
                "prompt_context": prompt_context,
                "analysis_type": str(analysis.get("analysis_type", "")).strip(),
                "answer": str(analysis.get("answer", "")).strip(),
            }

    return {
        "file_id": file_id,
        "file_name": str(meta.get("filename", "")).strip(),
        "prompt_context": (
            f"Arquivo anexado: {str(meta.get('filename', '')).strip()}\n"
            f"Tipo MIME: {str(meta.get('mime_type', '')).strip()}\n"
            "O usuario enviou esse arquivo junto com a mensagem."
        ),
        "analysis_type": "",
        "answer": "",
    }


if APIRouter is not None:
    router = APIRouter(
        prefix="/files",
        tags=["files"],
        dependencies=[Depends(rate_limit(120)), Depends(require_token())],
    )

    @router.post("/upload")
    def files_upload(body: dict):
        payload = create_uploaded_file(
            filename=str(body.get("filename", "")).strip(),
            content_base64=str(body.get("content_base64", "")).strip(),
            mime_type=str(body.get("mime_type", "")).strip(),
            source=str(body.get("source", "upload")).strip() or "upload",
        )
        status_code = 200 if payload.get("ok") else 400
        return _json(payload, status_code=status_code)

    @router.post("/analyze")
    def files_analyze(body: dict):
        payload = analyze_uploaded_file(
            file_id=str(body.get("file_id", "")).strip(),
            question=str(body.get("question", "")).strip(),
            context=str(body.get("context", "")).strip(),
            recognized_text=str(body.get("recognized_text", "")).strip(),
            labels=body.get("labels") if isinstance(body.get("labels"), list) else [],
            metadata=body.get("metadata") if isinstance(body.get("metadata"), dict) else {},
            from_camera=bool(body.get("from_camera", False)),
        )
        status_code = 200 if payload.get("ok") else 400
        return _json(payload, status_code=status_code)

else:
    router = None
