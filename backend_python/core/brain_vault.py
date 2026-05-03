from __future__ import annotations

from datetime import datetime
from pathlib import Path
import re
import unicodedata
from typing import Any

from core.caminhos import pasta_dados_app


VAULT_DIR = pasta_dados_app() / "brain_vault"
WIKILINK_RE = re.compile(r"!?\[\[([^\]]+)\]\]")
TAG_RE = re.compile(r"(?<!\w)#([A-Za-z0-9_/-]+)")


def _now() -> str:
    return datetime.now().isoformat(timespec="seconds")


def _clean(text: str) -> str:
    return re.sub(r"\s+", " ", str(text or "").strip())


def _normalize_ascii(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", str(text or ""))
    return re.sub(r"\s+", " ", normalized.encode("ascii", "ignore").decode("ascii").lower()).strip()


def _safe_segment(text: str) -> str:
    value = str(text or "").strip()
    value = re.sub(r'[\\/:*?"<>|]+', "-", value)
    value = re.sub(r"\s+", " ", value).strip(" .")
    return value or "Sem título"


def _slugify(text: str) -> str:
    normalized = _normalize_ascii(text)
    normalized = re.sub(r"[^a-z0-9]+", "-", normalized).strip("-")
    return normalized or "sem-titulo"


def _normalize_note_ref(text: str) -> str:
    raw = str(text or "").strip()
    if not raw:
        return ""
    target = raw.split("|", 1)[0].strip()
    target = target.split("#", 1)[0].strip()
    if target.lower().endswith(".md"):
        target = target[:-3].strip()
    return _normalize_ascii(target)


def _extract_wikilinks(content: str) -> list[str]:
    found: list[str] = []
    seen: set[str] = set()
    for match in WIKILINK_RE.findall(str(content or "")):
        normalized = _normalize_note_ref(match)
        if not normalized or normalized in seen:
            continue
        seen.add(normalized)
        found.append(match.split("|", 1)[0].split("#", 1)[0].strip())
    return found


def _extract_tags(content: str) -> list[str]:
    found: list[str] = []
    seen: set[str] = set()
    for tag in TAG_RE.findall(str(content or "")):
        value = str(tag or "").strip()
        if not value or value in seen:
            continue
        seen.add(value)
        found.append(value)
    return found


def _excerpt(content: str, limit: int = 240) -> str:
    body = _clean(content)
    if len(body) <= limit:
        return body
    cut = body[: max(40, limit)].rsplit(" ", 1)[0].strip()
    return (cut or body[:limit]).rstrip(" ,.;:-") + "..."


def _markdown_bullet_links(items: list[str]) -> str:
    lines = [f"- [[{item}]]" for item in items if _clean(item)]
    return "\n".join(lines).strip()


def _markdown_bullet_values(items: list[str]) -> str:
    lines = [f"- {item}" for item in items if _clean(item)]
    return "\n".join(lines).strip()


class BrainVault:
    def __init__(self, vault_dir: str | Path | None = None) -> None:
        self.vault_dir = Path(vault_dir or VAULT_DIR)
        self.vault_dir.mkdir(parents=True, exist_ok=True)

    def _iter_note_files(self) -> list[Path]:
        return sorted(self.vault_dir.rglob("*.md"))

    def _title_from_path(self, path: Path) -> str:
        return path.stem.strip() or "Sem título"

    def _relative_path(self, path: Path) -> str:
        return path.relative_to(self.vault_dir).as_posix()

    def _path_for_title(self, title: str, folder: str = "") -> Path:
        safe_title = _safe_segment(title)
        parts = [self.vault_dir]
        for raw_segment in str(folder or "").split("/"):
            segment = _safe_segment(raw_segment)
            if segment and segment != "Sem título":
                parts.append(Path(segment))
        base = Path(*parts)
        base.mkdir(parents=True, exist_ok=True)
        return base / f"{safe_title}.md"

    def _existing_note_path(self, note_ref: str) -> Path | None:
        note = self.get_note(note_ref)
        if not isinstance(note, dict):
            return None
        path = str(note.get("path", "")).strip()
        if not path:
            return None
        return self.vault_dir / path

    def _strip_wikilinks(self, content: str) -> str:
        return WIKILINK_RE.sub(" ", str(content or ""))

    def _find_unlinked_mentions(
        self, source_note: dict[str, Any], notes: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        content = str(source_note.get("content", "") or "")
        if not content:
            return []
        plain = _normalize_ascii(self._strip_wikilinks(content))
        source_slug = str(source_note.get("slug", "") or "")
        linked = set(source_note.get("links_normalized", []) or [])
        suggestions: list[dict[str, Any]] = []
        seen_targets: set[str] = set()

        for candidate in notes:
            candidate_slug = str(candidate.get("slug", "") or "")
            candidate_title = str(candidate.get("title", "") or "").strip()
            if not candidate_slug or candidate_slug == source_slug or not candidate_title:
                continue
            candidate_ref = _normalize_note_ref(candidate_title)
            if not candidate_ref or candidate_ref in linked or candidate_slug in seen_targets:
                continue
            title_ascii = _normalize_ascii(candidate_title)
            if len(title_ascii) < 3:
                continue
            pattern = rf"(?<!\[)\b{re.escape(title_ascii)}\b"
            match = re.search(pattern, plain)
            if not match:
                continue
            start = max(0, match.start() - 72)
            end = min(len(plain), match.end() + 72)
            excerpt = plain[start:end].strip()
            suggestions.append(
                {
                    "source": str(source_note.get("title", "") or ""),
                    "source_slug": source_slug,
                    "target": candidate_title,
                    "target_slug": candidate_slug,
                    "excerpt": _excerpt(excerpt, limit=180),
                }
            )
            seen_targets.add(candidate_slug)
        return suggestions

    def _append_section(self, path: Path, heading: str, body: str) -> None:
        section_body = str(body or "").strip()
        if not section_body:
            return
        current = path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""
        marker = f"## {heading}"
        timestamp = _now()
        block = f"{marker}\n{section_body}\n\n_Atualizado em {timestamp}_"

        if marker in current:
            updated = re.sub(
                rf"(?s){re.escape(marker)}\n.*?(?=\n## |\Z)",
                block,
                current,
                count=1,
            ).strip()
            path.write_text(updated + "\n", encoding="utf-8")
            return

        base = current.rstrip()
        joined = f"{base}\n\n{block}\n" if base else f"{block}\n"
        path.write_text(joined, encoding="utf-8")

    def _parse_note(self, path: Path, include_content: bool = True) -> dict[str, Any]:
        content = path.read_text(encoding="utf-8", errors="ignore")
        title = self._title_from_path(path)
        links = _extract_wikilinks(content)
        tags = _extract_tags(content)
        stat = path.stat()
        note = {
            "title": title,
            "slug": _slugify(title),
            "path": self._relative_path(path),
            "exists": True,
            "links": links,
            "links_normalized": [
                _normalize_note_ref(item) for item in links if _normalize_note_ref(item)
            ],
            "tags": tags,
            "word_count": len(content.split()),
            "updated_at": datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds"),
            "created_at": datetime.fromtimestamp(stat.st_ctime).isoformat(timespec="seconds"),
            "excerpt": _excerpt(content),
        }
        if include_content:
            note["content"] = content
        return note

    def list_notes(
        self, query: str = "", limit: int = 50, *, include_content: bool = False
    ) -> list[dict]:
        notes = list(self.build_index().get("notes", []) or [])
        if query:
            return self.search_notes(query, limit=limit, include_content=include_content)
        items = notes[: max(1, limit)]
        if include_content:
            return items
        return [{k: v for k, v in item.items() if k != "content"} for item in items]

    def search_notes(
        self,
        query: str,
        limit: int = 10,
        *,
        include_content: bool = False,
    ) -> list[dict[str, Any]]:
        term = _clean(query)
        if not term:
            return self.list_notes(limit=limit, include_content=include_content)

        normalized_term = _normalize_ascii(term)
        terms = {token for token in re.findall(r"[a-z0-9]+", normalized_term) if len(token) >= 2}
        scored: list[tuple[float, dict[str, Any]]] = []

        for note in list(self.build_index().get("notes", []) or []):
            haystacks = [
                _normalize_ascii(note["title"]),
                _normalize_ascii(note.get("excerpt", "")),
                " ".join(_normalize_ascii(tag) for tag in note.get("tags", [])),
            ]
            combined = " ".join(part for part in haystacks if part)
            if not combined:
                continue

            score = 0.0
            if normalized_term == haystacks[0]:
                score += 8.0
            if normalized_term in haystacks[0]:
                score += 5.0
            if normalized_term in combined:
                score += 3.0
            if terms:
                note_terms = {
                    token for token in re.findall(r"[a-z0-9]+", combined) if len(token) >= 2
                }
                overlap = len(terms & note_terms)
                if overlap:
                    score += overlap * 1.5
            if score > 0:
                scored.append((score, note))

        scored.sort(key=lambda item: (item[0], item[1].get("updated_at", "")), reverse=True)
        items = [note for _, note in scored[: max(1, limit)]]
        if include_content:
            return items
        return [{k: v for k, v in item.items() if k != "content"} for item in items]

    def get_note(self, note_ref: str) -> dict[str, Any] | None:
        target = _normalize_note_ref(note_ref)
        if not target:
            return None
        for path in self._iter_note_files():
            note = self._parse_note(path, include_content=True)
            if _normalize_note_ref(note["title"]) == target or note["slug"] == _slugify(target):
                return note
        return None

    def save_note(self, title: str, content: str, folder: str = "") -> dict[str, Any]:
        note_title = _clean(title) or "Sem título"
        path = self._existing_note_path(note_title) or self._path_for_title(
            note_title, folder=folder
        )
        body = str(content or "").strip()
        path.write_text(body + ("\n" if body and not body.endswith("\n") else ""), encoding="utf-8")
        note = self._parse_note(path, include_content=True)
        note["saved_at"] = _now()
        return note

    def save_research_note(
        self,
        query: str,
        summary: str,
        *,
        sources: list[str] | None = None,
        related_links: list[str] | None = None,
    ) -> dict[str, Any]:
        title = _clean(query) or "Pesquisa"
        path = self._existing_note_path(title) or self._path_for_title(title, folder="pesquisas")
        if not path.exists():
            header = f"# {title}\n\n#pesquisa #nova\n"
            path.write_text(header, encoding="utf-8")
        self._append_section(path, "Resumo", summary)
        if related_links:
            self._append_section(path, "Conexoes", _markdown_bullet_links(list(related_links)))
        if sources:
            self._append_section(path, "Fontes", _markdown_bullet_values(list(sources)))
        return self._parse_note(path, include_content=True)

    def save_memory_note(
        self, category: str, content: str, *, user_id: str = "default"
    ) -> dict[str, Any]:
        category_label = _clean(category).replace("_", " ") or "contexto"
        title = f"Memoria {category_label.title()}"
        path = self._existing_note_path(title) or self._path_for_title(
            title, folder=f"memorias/{_safe_segment(user_id)}"
        )
        if not path.exists():
            header = f"# {title}\n\n#memoria #nova\n"
            path.write_text(header, encoding="utf-8")
        current = path.read_text(encoding="utf-8", errors="ignore") if path.exists() else ""
        entry = f"- {_now()}: {_clean(content)}"
        if entry not in current:
            marker = "## Entradas"
            if marker in current:
                updated = re.sub(
                    rf"(?s){re.escape(marker)}\n(.*?)(?=\n## |\Z)",
                    lambda match: f"{marker}\n{match.group(1).rstrip()}\n{entry}\n",
                    current,
                    count=1,
                )
                path.write_text(updated.rstrip() + "\n", encoding="utf-8")
            else:
                joined = current.rstrip()
                block = f"{joined}\n\n{marker}\n{entry}\n" if joined else f"{marker}\n{entry}\n"
                path.write_text(block, encoding="utf-8")
        return self._parse_note(path, include_content=True)

    def append_chat_turn(self, user_id: str, prompt: str, reply: str) -> dict[str, Any]:
        slug = _safe_segment(user_id or "default")
        daily = datetime.now().strftime("%Y-%m-%d")
        path = self._path_for_title(daily, folder=f"conversas/{slug}")
        if not path.exists():
            header = f"# Conversas {daily}\n\n#chat #nova\n"
            path.write_text(header, encoding="utf-8")
        current = path.read_text(encoding="utf-8", errors="ignore")
        block = (
            f"\n## Turno {_now()}\n"
            f"**Usuario:** {_clean(prompt)}\n\n"
            f"**NOVA:** {_clean(reply)}\n"
        )
        path.write_text(current.rstrip() + block + "\n", encoding="utf-8")
        return self._parse_note(path, include_content=True)

    def build_index(self) -> dict[str, Any]:
        notes = [self._parse_note(path, include_content=True) for path in self._iter_note_files()]
        by_ref = {_normalize_note_ref(note["title"]): note for note in notes}
        backlinks: dict[str, list[str]] = {}
        edges: list[dict[str, Any]] = []
        seen_edges: set[tuple[str, str]] = set()
        ghost_nodes: dict[str, dict[str, Any]] = {}
        link_suggestions: list[dict[str, Any]] = []

        for note in notes:
            source_title = str(note["title"])
            source_slug = str(note["slug"])
            for target_title in note.get("links", []):
                target_ref = _normalize_note_ref(target_title)
                if not target_ref:
                    continue
                target_note = by_ref.get(target_ref)
                target_slug = (
                    str(target_note["slug"])
                    if isinstance(target_note, dict)
                    else _slugify(target_title)
                )
                target_label = (
                    str(target_note["title"])
                    if isinstance(target_note, dict)
                    else _clean(target_title)
                )
                edge_key = (source_slug, target_slug)
                if edge_key not in seen_edges:
                    seen_edges.add(edge_key)
                    edges.append(
                        {
                            "source": source_slug,
                            "source_title": source_title,
                            "target": target_slug,
                            "target_title": target_label,
                            "target_exists": bool(target_note),
                        }
                    )
                backlinks.setdefault(target_slug, [])
                if source_title not in backlinks[target_slug]:
                    backlinks[target_slug].append(source_title)
                if target_note is None and target_slug not in ghost_nodes:
                    ghost_nodes[target_slug] = {
                        "title": target_label or "Sem título",
                        "slug": target_slug,
                        "path": "",
                        "exists": False,
                        "links": [],
                        "tags": [],
                        "word_count": 0,
                        "updated_at": "",
                        "created_at": "",
                        "excerpt": "",
                    }

        enriched_notes: list[dict[str, Any]] = []
        for note in notes:
            current_backlinks = backlinks.get(str(note["slug"]), [])
            suggestions = self._find_unlinked_mentions(note, notes)
            link_suggestions.extend(suggestions)
            enriched_notes.append(
                {
                    **note,
                    "backlinks": current_backlinks,
                    "backlinks_count": len(current_backlinks),
                    "links_count": len(note.get("links", [])),
                    "unlinked_mentions": suggestions,
                    "unlinked_mentions_count": len(suggestions),
                }
            )

        all_nodes = [
            {
                key: value
                for key, value in note.items()
                if key not in {"content", "links_normalized", "unlinked_mentions"}
            }
            for note in enriched_notes
        ] + list(ghost_nodes.values())
        return {
            "vault_path": str(self.vault_dir),
            "notes": enriched_notes,
            "nodes": all_nodes,
            "edges": edges,
            "backlinks": backlinks,
            "link_suggestions": link_suggestions,
            "total_notes": len(enriched_notes),
            "total_nodes": len(all_nodes),
            "total_edges": len(edges),
        }

    def get_backlinks(self, note_ref: str) -> dict[str, Any]:
        note = self.get_note(note_ref)
        if note is None:
            return {"ok": False, "error": "note_not_found", "note": None, "backlinks": []}
        index = self.build_index()
        backlinks = index.get("backlinks", {}).get(str(note["slug"]), [])
        note_with_context = next(
            (item for item in index.get("notes", []) if item.get("slug") == note.get("slug")),
            note,
        )
        return {
            "ok": True,
            "note": note["title"],
            "slug": note["slug"],
            "backlinks": backlinks,
            "total": len(backlinks),
            "unlinked_mentions": list(note_with_context.get("unlinked_mentions", []) or []),
        }

    def suggest_links(self, note_ref: str = "", limit: int = 20) -> dict[str, Any]:
        index = self.build_index()
        suggestions = list(index.get("link_suggestions", []) or [])
        if note_ref:
            target = _normalize_note_ref(note_ref)
            suggestions = [
                item
                for item in suggestions
                if _normalize_note_ref(item.get("source", "")) == target
                or _normalize_note_ref(item.get("target", "")) == target
            ]
        return {
            "ok": True,
            "items": suggestions[: max(1, limit)],
            "total": len(suggestions),
        }

    def vault_stats(self) -> dict[str, Any]:
        index = self.build_index()
        notes = list(index.get("notes", []) or [])
        suggestions = list(index.get("link_suggestions", []) or [])
        return {
            "ok": True,
            "vault_path": str(self.vault_dir),
            "total_notes": len(notes),
            "total_edges": int(index.get("total_edges", 0) or 0),
            "total_suggestions": len(suggestions),
            "recent_notes": notes[:6],
        }
