from __future__ import annotations

try:
    from fastapi import APIRouter, Query, Depends
except Exception:
    APIRouter = None
    Query = None
    Depends = None

from .dependencies import rate_limit, require_token
from core.brain_vault import BrainVault
from core.orchestrator import get_default_orchestrator
from models.schemas import MemoryCreateRequest, MemorySearchResponse


def open_memory_snapshot(user_id: str, limit: int = 8) -> dict:
    normalized_user = str(user_id or "").strip() or "default"
    normalized_limit = max(1, int(limit or 8))
    store = get_default_orchestrator().memory
    recent = store.search_recent(user_id=normalized_user, limit=normalized_limit)
    vault = BrainVault()
    notes = vault.list_notes(limit=min(normalized_limit, 8))
    graph = vault.build_index()
    return {
        "ok": True,
        "user_id": normalized_user,
        "recent_memories": recent,
        "notes": notes,
        "graph": {
            "total_notes": int(graph.get("total_notes", 0) or 0),
            "total_nodes": int(graph.get("total_nodes", 0) or 0),
            "total_edges": int(graph.get("total_edges", 0) or 0),
        },
    }


if APIRouter is not None:
    router = APIRouter(
        prefix="/memory",
        tags=["memory"],
        dependencies=[Depends(rate_limit(120)), Depends(require_token())],
    )

    @router.get("/recent", response_model=MemorySearchResponse)
    def recent_memories_query(user_id: str = Query(...), limit: int = 10) -> MemorySearchResponse:
        store = get_default_orchestrator().memory
        items = store.search_recent(user_id=user_id, limit=limit)
        return MemorySearchResponse(ok=True, items=items, total=len(items))

    @router.get("/recent/{user_id}", response_model=MemorySearchResponse)
    def recent_memories(user_id: str, limit: int = 10) -> MemorySearchResponse:
        store = get_default_orchestrator().memory
        items = store.search_recent(user_id=user_id, limit=limit)
        return MemorySearchResponse(ok=True, items=items, total=len(items))

    @router.get("/search", response_model=MemorySearchResponse)
    def search_memories(
        user_id: str = Query(...), query: str = Query(...), limit: int = 10
    ) -> MemorySearchResponse:
        store = get_default_orchestrator().memory
        items = store.search(user_id=user_id, query=query, limit=limit)
        return MemorySearchResponse(ok=True, items=items, total=len(items))

    @router.post("", response_model=dict)
    def save_memory(req: MemoryCreateRequest) -> dict:
        store = get_default_orchestrator().memory
        item = store.save(
            user_id=req.user_id,
            category=req.category,
            content=req.content,
            importance=req.importance,
            scope=req.scope,
            source="api_memory",
        )
        BrainVault().save_memory_note(req.category, req.content, user_id=req.user_id)
        return {"ok": True, "item": item}

    @router.post("/open", response_model=dict)
    def open_memory(body: dict) -> dict:
        user_id = str(body.get("user_id", "default")).strip() or "default"
        try:
            limit = int(body.get("limit", 8) or 8)
        except Exception:
            limit = 8
        return open_memory_snapshot(user_id=user_id, limit=limit)

else:
    router = None
