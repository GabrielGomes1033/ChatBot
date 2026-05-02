from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.brain_vault import BrainVault
from core.orchestrator import build_default_tools
from memory.sqlite_store import MemoryStore


class BrainVaultTests(unittest.TestCase):
    def test_build_index_tracks_wikilinks_backlinks_and_ghost_nodes(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = BrainVault(Path(tmpdir) / "vault")
            vault.save_note(
                "Python",
                "Python é uma linguagem. Veja [[FastAPI]] e [[Projeto Fantasma]]. #programacao",
            )
            vault.save_note(
                "FastAPI",
                "FastAPI é um framework web moderno para APIs em Python.",
            )

            graph = vault.build_index()
            nodes = {item["slug"]: item for item in graph["nodes"]}

            self.assertIn("python", nodes)
            self.assertIn("fastapi", nodes)
            self.assertIn("projeto-fantasma", nodes)
            self.assertFalse(nodes["projeto-fantasma"]["exists"])

            python_note = next(item for item in graph["notes"] if item["slug"] == "python")
            fastapi_note = next(item for item in graph["notes"] if item["slug"] == "fastapi")

            self.assertIn("programacao", python_note["tags"])
            self.assertEqual(python_note["links_count"], 2)
            self.assertIn("Python", fastapi_note["backlinks"])
            self.assertEqual(fastapi_note["backlinks_count"], 1)

    def test_search_and_backlinks_return_obsidian_style_context(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = BrainVault(Path(tmpdir) / "vault")
            vault.save_note(
                "Machine Learning",
                "Machine learning aprende padrões com dados e se conecta com [[Estatística]].",
            )
            vault.save_note(
                "Estatística",
                "Estatística ajuda a validar hipóteses e interpretar dados.",
            )

            results = vault.search_notes("machine learning", limit=5)
            self.assertEqual(results[0]["title"], "Machine Learning")
            self.assertIn("aprende padrões com dados", results[0]["excerpt"])

            backlinks = vault.get_backlinks("Estatística")
            self.assertTrue(backlinks["ok"])
            self.assertIn("Machine Learning", backlinks["backlinks"])

    def test_search_memory_tool_also_reads_brain_vault_notes(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "nova_memory_test.db"
            memory = MemoryStore(db_path)
            vault = BrainVault(Path(tmpdir) / "vault")
            vault.save_note(
                "Obsidian Brain",
                "A NOVA pode organizar conhecimento em notas Markdown com [[Backlinks]] e grafo.",
            )

            with patch("core.orchestrator.BrainVault", return_value=vault):
                tools = build_default_tools(memory)
                result = tools.execute(
                    "search_memory",
                    {"query": "markdown grafo", "user_id": "tester"},
                )

            self.assertTrue(result["ok"])
            self.assertTrue(any(item.get("source") == "brain_vault" for item in result["items"]))
            self.assertTrue(
                any("Obsidian Brain" in str(item.get("content", "")) for item in result["items"])
            )
            memory.close()

    def test_memory_notes_append_entries_and_link_suggestions(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            vault = BrainVault(Path(tmpdir) / "vault")
            vault.save_note("CRM", "Sistema comercial central.")
            vault.save_note(
                "Atlas",
                "Projeto Atlas depende de crm para operar e melhorar o comercial.",
            )
            vault.save_memory_note("preferencia", "Gosta de respostas claras.", user_id="gabriel")
            vault.save_memory_note("preferencia", "Prefere respostas objetivas.", user_id="gabriel")

            memory_note = vault.get_note("Memoria Preferencia")
            self.assertIsNotNone(memory_note)
            content = str(memory_note.get("content", ""))
            self.assertEqual(content.count("## Entradas"), 1)
            self.assertIn("Gosta de respostas claras.", content)
            self.assertIn("Prefere respostas objetivas.", content)

            suggestions = vault.suggest_links("Atlas", limit=10)
            self.assertTrue(suggestions["ok"])
            self.assertTrue(
                any(item.get("target") == "CRM" for item in suggestions["items"])
            )

    def test_search_web_tool_persists_research_into_vault(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "nova_memory_test.db"
            memory = MemoryStore(db_path)
            vault = BrainVault(Path(tmpdir) / "vault")

            fake_result = {
                "ok": True,
                "query": "Atlas CRM",
                "summary": "Atlas CRM integra vendas, backlog e operacao comercial.",
                "results": [
                    {"title": "CRM", "snippet": "Sistema central", "url": "https://exemplo.test/crm"},
                ],
                "sources": ["https://exemplo.test/crm"],
            }

            with patch("core.orchestrator.integration_search_web", return_value=fake_result):
                tools = build_default_tools(memory, brain_vault=vault)
                result = tools.execute(
                    "search_web",
                    {"query": "Atlas CRM", "user_id": "tester"},
                )

            self.assertTrue(result["ok"])
            saved = vault.get_note("Atlas CRM")
            self.assertIsNotNone(saved)
            content = str(saved.get("content", ""))
            self.assertIn("## Resumo", content)
            self.assertIn("Atlas CRM integra vendas", content)
            self.assertIn("[[CRM]]", content)
            memory.close()


if __name__ == "__main__":
    unittest.main()
