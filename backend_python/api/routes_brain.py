from __future__ import annotations

try:
    from fastapi import APIRouter, Depends, Query
except Exception:
    APIRouter = None
    Depends = None
    Query = None

from core.brain_vault import BrainVault
from models.schemas import (
    BrainGraphResponse,
    BrainNoteResponse,
    BrainNoteWriteRequest,
    BrainSearchResponse,
)

from .dependencies import rate_limit, require_token


if APIRouter is not None:
    router = APIRouter(
        prefix="/brain",
        tags=["brain"],
        dependencies=[Depends(rate_limit(120)), Depends(require_token())],
    )

    @router.get("/notes", response_model=BrainSearchResponse)
    def list_brain_notes(
        query: str = Query(default=""),
        limit: int = Query(default=20, ge=1, le=200),
    ) -> BrainSearchResponse:
        vault = BrainVault()
        items = vault.search_notes(query, limit=limit) if query else vault.list_notes(limit=limit)
        return BrainSearchResponse(
            ok=True,
            vault_path=str(vault.vault_dir),
            items=items,
            total=len(items),
        )

    @router.get("/notes/{note_ref}", response_model=BrainNoteResponse)
    def get_brain_note(note_ref: str) -> BrainNoteResponse:
        vault = BrainVault()
        note = vault.get_note(note_ref)
        if note is None:
            return BrainNoteResponse(ok=False, note=None, error="note_not_found")
        return BrainNoteResponse(ok=True, note=note, error=None)

    @router.post("/notes", response_model=BrainNoteResponse)
    def save_brain_note(req: BrainNoteWriteRequest) -> BrainNoteResponse:
        vault = BrainVault()
        note = vault.save_note(req.title, req.content, folder=req.folder)
        return BrainNoteResponse(ok=True, note=note, error=None)

    @router.get("/backlinks/{note_ref}", response_model=dict)
    def get_brain_backlinks(note_ref: str) -> dict:
        vault = BrainVault()
        return vault.get_backlinks(note_ref)

    @router.get("/graph", response_model=BrainGraphResponse)
    def get_brain_graph() -> BrainGraphResponse:
        vault = BrainVault()
        graph = vault.build_index()
        return BrainGraphResponse(
            ok=True,
            vault_path=str(graph.get("vault_path", "")),
            nodes=graph.get("nodes", []),
            edges=graph.get("edges", []),
            total_notes=int(graph.get("total_notes", 0) or 0),
            total_nodes=int(graph.get("total_nodes", 0) or 0),
            total_edges=int(graph.get("total_edges", 0) or 0),
        )

    @router.get("/suggestions", response_model=dict)
    def get_brain_suggestions(
        note_ref: str = Query(default=""),
        limit: int = Query(default=20, ge=1, le=200),
    ) -> dict:
        vault = BrainVault()
        return vault.suggest_links(note_ref=note_ref, limit=limit)

else:
    router = None
