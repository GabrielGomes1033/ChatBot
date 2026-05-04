from __future__ import annotations

try:
    from fastapi import APIRouter, Depends
    from fastapi.responses import JSONResponse
except Exception:
    APIRouter = None
    Depends = None
    JSONResponse = None

from .dependencies import rate_limit, require_token
from .routes_memory import open_memory_snapshot
from core.brain_vault import BrainVault
from core.orchestrator import get_default_orchestrator
from core.response_style import style_response
from models.schemas import ToolApprovalRequest


if APIRouter is not None:
    router = APIRouter(
        prefix="/actions",
        tags=["actions"],
        dependencies=[Depends(require_token())],
    )

    @router.get("/tools", dependencies=[Depends(rate_limit(120))])
    def list_tools() -> dict:
        orchestrator = get_default_orchestrator()
        return {"ok": True, "tools": orchestrator.tools.describe()}

    @router.post("/approve", response_model=dict, dependencies=[Depends(rate_limit(60))])
    def approve_action(req: ToolApprovalRequest) -> dict:
        orchestrator = get_default_orchestrator()
        result = orchestrator.execute_tool(
            req.user_id,
            req.tool_name,
            req.params,
            prompt_text=req.prompt_text,
            mode=req.mode,
        )
        return {"ok": True, **result}

    def _action_payload(
        *,
        user_id: str,
        answer: str,
        next_actions: list[str],
        context: str = "",
        action_type: str = "analysis",
    ) -> dict:
        return {
            "ok": True,
            "status": "ok",
            "type": action_type,
            "answer": style_response(answer, "normal"),
            "context": context,
            "next_actions": next_actions,
        }

    def _recent_context(user_id: str, limit: int = 4) -> str:
        items = get_default_orchestrator().memory.search_recent(user_id=user_id, limit=limit)
        for item in items:
            content = str(item.get("content", "")).strip()
            if content:
                return content
        notes = BrainVault().list_notes(limit=3)
        for note in notes:
            excerpt = str(note.get("excerpt", "")).strip()
            if excerpt:
                return excerpt
        return ""

    @router.post("/continue-project", response_model=dict, dependencies=[Depends(rate_limit(90))])
    def continue_project(body: dict) -> dict:
        user_id = str(body.get("user_id", "default")).strip() or "default"
        explicit_context = str(body.get("context", "")).strip()
        context = explicit_context or _recent_context(user_id)
        answer = (
            "Retomei o contexto ativo do projeto. "
            f"O foco mais recente e: {context}. "
            "Meu proximo passo sugerido e separar a interface em topo fixo, chat puro e acoes discretas."
            if context
            else "Retomei o projeto atual. O melhor proximo passo e revisar o ultimo bloco trabalhado e transformar isso em uma tarefa executavel."
        )
        return _action_payload(
            user_id=user_id,
            answer=answer,
            context=context,
            next_actions=[
                "Continuar daqui",
                "Gerar codigo",
                "Organizar proximo passo",
            ],
        )

    @router.post("/generate-code", response_model=dict, dependencies=[Depends(rate_limit(90))])
    def generate_code(body: dict) -> dict:
        language = str(body.get("language", "")).strip()
        context = str(body.get("context", "")).strip() or _recent_context(
            str(body.get("user_id", "default")).strip() or "default"
        )
        answer = (
            "Ativei o modulo Dev. "
            f"Vou priorizar a geracao de codigo{f' em {language}' if language else ''} "
            "com base no contexto atual, explicando como executar e o que melhorar em seguida."
        )
        if context:
            answer = f"{answer} Contexto considerado: {context}."
        return _action_payload(
            user_id=str(body.get("user_id", "default")).strip() or "default",
            answer=answer,
            context=context,
            action_type="dev",
            next_actions=[
                "Criar projeto",
                "Corrigir codigo",
                "Explicar codigo",
            ],
        )

    @router.post("/improve-interface", response_model=dict, dependencies=[Depends(rate_limit(90))])
    def improve_interface(body: dict) -> dict:
        context = str(body.get("context", "")).strip() or _recent_context(
            str(body.get("user_id", "default")).strip() or "default"
        )
        answer = (
            "Ativei a analise de interface. "
            "Vou buscar uma estrutura mais limpa, com visual startup premium, topo fixo e menos poluicao visual nas respostas."
        )
        if context:
            answer = f"{answer} Base usada: {context}."
        return _action_payload(
            user_id=str(body.get("user_id", "default")).strip() or "default",
            answer=answer,
            context=context,
            next_actions=[
                "Melhorar interface",
                "Gerar codigo",
                "Salvar contexto",
            ],
        )

    @router.post("/continue-from-here", response_model=dict, dependencies=[Depends(rate_limit(90))])
    def continue_from_here(body: dict) -> dict:
        last_answer = str(body.get("last_answer", "")).strip()
        context = last_answer or str(body.get("context", "")).strip() or _recent_context(
            str(body.get("user_id", "default")).strip() or "default"
        )
        answer = (
            "Vou continuar exatamente do ponto anterior, sem recomeçar do zero. "
            f"O gancho ativo e: {context}."
            if context
            else "Vou continuar do ponto em que a conversa parou, preservando o raciocinio anterior."
        )
        return _action_payload(
            user_id=str(body.get("user_id", "default")).strip() or "default",
            answer=answer,
            context=context,
            next_actions=[
                "Continuar projeto",
                "Organizar proximo passo",
                "Abrir memoria e notas",
            ],
        )

    @router.post("/open-memory", response_model=dict, dependencies=[Depends(rate_limit(90))])
    def open_memory(body: dict) -> dict:
        user_id = str(body.get("user_id", "default")).strip() or "default"
        snapshot = open_memory_snapshot(user_id=user_id, limit=8)
        notes_total = int(snapshot.get("graph", {}).get("total_notes", 0) or 0)
        recent_total = len(snapshot.get("recent_memories", []) or [])
        answer = (
            f"Abri a memoria operacional da NOVA. "
            f"Encontrei {recent_total} memoria(s) recente(s) e {notes_total} nota(s) no vault."
        )
        return {
            **snapshot,
            "status": "ok",
            "type": "memory",
            "answer": answer,
            "next_actions": [
                "Continuar projeto",
                "Salvar contexto",
                "Organizar proximo passo",
            ],
        }

else:
    router = None
