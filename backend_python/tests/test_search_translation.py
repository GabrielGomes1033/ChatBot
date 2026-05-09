from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.orchestrator import NovaOrchestrator, RuleBasedLLM, build_default_tools
from core.translation_service import (
    parse_search_translation_request,
    parse_text_translation_request,
    translate_text,
)
from memory.sqlite_store import MemoryStore


class SearchTranslationTests(unittest.TestCase):
    def test_parse_search_translation_request_detects_target_language(self) -> None:
        pedido = parse_search_translation_request("traduza essa pesquisa para ingles")
        self.assertIsNotNone(pedido)
        self.assertEqual(pedido["target_language"], "en")

        atalho = parse_search_translation_request("em portugues")
        self.assertIsNotNone(atalho)
        self.assertEqual(atalho["target_language"], "pt")

        voz = parse_search_translation_request("me fale essa pesquisa em espanhol")
        self.assertIsNotNone(voz)
        self.assertEqual(voz["target_language"], "es")

    def test_parse_text_translation_request_extracts_explicit_text(self) -> None:
        pedido = parse_text_translation_request('traduza "Bom dia, mundo" para ingles')
        self.assertIsNotNone(pedido)
        self.assertEqual(pedido["source_text"], "Bom dia, mundo")
        self.assertEqual(pedido["target_language"], "en")

        pedido_com_dois_pontos = parse_text_translation_request(
            "traduza para portugues: Good morning"
        )
        self.assertIsNotNone(pedido_com_dois_pontos)
        self.assertEqual(pedido_com_dois_pontos["source_text"], "Good morning")
        self.assertEqual(pedido_com_dois_pontos["target_language"], "pt")

    def test_translate_last_search_after_web_lookup(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            memory = MemoryStore(Path(tmpdir) / "nova_memory_test.db")
            orchestrator = NovaOrchestrator(
                memory=memory,
                tools=build_default_tools(memory),
                llm=RuleBasedLLM(),
            )

            with patch(
                "core.orchestrator.integration_search_web",
                return_value={
                    "ok": True,
                    "query": "carros eletricos",
                    "summary": "Electric cars reduce emissions and depend on battery infrastructure.",
                    "sources": ["https://example.com/cars"],
                },
            ):
                pesquisa = orchestrator.handle(
                    "tester",
                    "pesquise sobre carros eletricos",
                )

            self.assertIn("Electric cars reduce emissions", pesquisa["reply"])
            self.assertNotIn("Responda sim ou nao", pesquisa["reply"])

            with patch(
                "core.orchestrator.translate_text",
                return_value={
                    "ok": True,
                    "translated_text": "Electric cars reduce emissions and depend on battery infrastructure.",
                    "provider": "mock",
                    "target_language": "en",
                },
            ):
                traducao = orchestrator.handle(
                    "tester",
                    "traduza essa pesquisa para ingles",
                )

            self.assertIn("Traducao da ultima pesquisa para ingles", traducao["reply"])
            self.assertIn("Electric cars reduce emissions", traducao["reply"])
            memory.close()

    def test_web_search_reply_is_structured_in_chat(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            memory = MemoryStore(Path(tmpdir) / "nova_memory_test.db")
            orchestrator = NovaOrchestrator(
                memory=memory,
                tools=build_default_tools(memory),
                llm=RuleBasedLLM(),
            )

            with patch(
                "core.orchestrator.integration_search_web",
                return_value={
                    "ok": True,
                    "query": "machine learning",
                    "summary": "Machine learning permite que sistemas aprendam a partir de dados.",
                    "results": [
                        {
                            "title": "Machine learning",
                            "snippet": "É uma área da IA focada em aprender padrões e fazer previsões.",
                            "url": "https://pt.wikipedia.org/wiki/Aprendizado_de_maquina",
                        }
                    ],
                    "sources": ["https://pt.wikipedia.org/wiki/Aprendizado_de_maquina"],
                },
            ):
                pesquisa = orchestrator.handle(
                    "tester",
                    "pesquise sobre machine learning",
                )

            self.assertIn(
                "Machine learning permite que sistemas aprendam a partir de dados.",
                pesquisa["reply"],
            )
            self.assertIn(
                "É uma área da IA focada em aprender padrões e fazer previsões.",
                pesquisa["reply"],
            )
            self.assertNotIn("Pontos principais", pesquisa["reply"])
            self.assertNotIn("Fontes consultadas", pesquisa["reply"])
            memory.close()

    def test_search_reply_stays_in_summary_mode(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            memory = MemoryStore(Path(tmpdir) / "nova_memory_test.db")
            orchestrator = NovaOrchestrator(
                memory=memory,
                tools=build_default_tools(memory),
                llm=RuleBasedLLM(),
            )

            with patch(
                "core.orchestrator.integration_search_web",
                return_value={
                    "ok": True,
                    "query": "electric cars",
                    "summary": "Electric cars reduce emissions.",
                    "sources": ["https://example.com/cars"],
                },
            ):
                pesquisa = orchestrator.handle(
                    "tester",
                    "pesquise sobre electric cars",
                )

            self.assertEqual(pesquisa["reply"], "Electric cars reduce emissions.")
            self.assertNotIn("traduzir essa pesquisa", pesquisa["reply"].lower())
            memory.close()

    def test_search_reply_does_not_include_extra_sections(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            memory = MemoryStore(Path(tmpdir) / "nova_memory_test.db")
            orchestrator = NovaOrchestrator(
                memory=memory,
                tools=build_default_tools(memory),
                llm=RuleBasedLLM(),
            )

            with patch(
                "core.orchestrator.integration_search_web",
                return_value={
                    "ok": True,
                    "query": "electric cars",
                    "summary": (
                        "Pesquisei sobre electric cars e organizei a explicação de forma clara:\n\n"
                        "Resumo direto:\nElectric cars reduce emissions.\n\n"
                        "Pontos principais:\n1. Need batteries.\n\n"
                        "Fontes consultadas:\n- https://example.com/cars"
                    ),
                    "sources": ["https://example.com/cars"],
                },
            ):
                resposta = orchestrator.handle(
                    "tester",
                    "pesquise sobre electric cars",
                )

            self.assertEqual(resposta["reply"], "Electric cars reduce emissions.")
            memory.close()

    def test_followup_can_deepen_last_search_naturally(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            memory = MemoryStore(Path(tmpdir) / "nova_memory_test.db")
            orchestrator = NovaOrchestrator(
                memory=memory,
                tools=build_default_tools(memory),
                llm=RuleBasedLLM(),
            )

            with patch(
                "core.orchestrator.integration_search_web",
                side_effect=[
                    {
                        "ok": True,
                        "query": "energia nuclear",
                        "summary": "Energia nuclear gera eletricidade a partir da fissão e exige controle rigoroso de segurança.",
                        "sources": ["https://example.com/nuclear"],
                    },
                    {
                        "ok": True,
                        "query": "energia nuclear detalhes exemplos contexto",
                        "summary": "Os principais pontos de aprofundamento envolvem custo inicial alto, baixa emissão operacional e gestão de rejeitos.",
                        "results": [
                            {
                                "title": "Usinas nucleares",
                                "snippet": "Projetos nucleares costumam exigir investimento alto e planejamento de longo prazo.",
                                "url": "https://example.com/nuclear-details",
                            }
                        ],
                        "sources": ["https://example.com/nuclear-details"],
                    },
                ],
            ) as mocked_search:
                orchestrator.handle(
                    "tester",
                    "pesquise sobre energia nuclear",
                )
                aprofundamento = orchestrator.handle(
                    "tester",
                    "fale mais sobre esse assunto",
                )

            self.assertIn("custo inicial alto", aprofundamento["reply"])
            self.assertIn("investimento alto", aprofundamento["reply"])
            self.assertEqual(mocked_search.call_count, 2)
            memory.close()

    def test_translate_last_search_without_previous_search_returns_guidance(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            memory = MemoryStore(Path(tmpdir) / "nova_memory_test.db")
            orchestrator = NovaOrchestrator(
                memory=memory,
                tools=build_default_tools(memory),
                llm=RuleBasedLLM(),
            )

            resposta = orchestrator.handle(
                "tester",
                "traduza essa pesquisa para ingles",
            )

            self.assertIn("ainda nao tenho uma pesquisa recente", resposta["reply"])
            memory.close()

    def test_translate_last_search_persists_across_new_orchestrator_instance(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            db_path = Path(tmpdir) / "nova_memory_test.db"

            memory1 = MemoryStore(db_path)
            orchestrator1 = NovaOrchestrator(
                memory=memory1,
                tools=build_default_tools(memory1),
                llm=RuleBasedLLM(),
            )

            with patch(
                "core.orchestrator.integration_search_web",
                return_value={
                    "ok": True,
                    "query": "electric cars",
                    "summary": "Electric cars use battery power for propulsion.",
                    "sources": ["https://example.com/cars"],
                },
            ):
                orchestrator1.handle(
                    "tester",
                    "pesquise sobre electric cars",
                )
            memory1.close()

            memory2 = MemoryStore(db_path)
            orchestrator2 = NovaOrchestrator(
                memory=memory2,
                tools=build_default_tools(memory2),
                llm=RuleBasedLLM(),
            )

            with patch(
                "core.orchestrator.translate_text",
                return_value={
                    "ok": True,
                    "translated_text": "Carros eletricos usam bateria para propulsao.",
                    "provider": "mock",
                    "target_language": "pt",
                },
            ):
                resposta = orchestrator2.handle(
                    "tester",
                    "me fale essa pesquisa em portugues",
                )

            self.assertIn("Traducao da ultima pesquisa para portugues", resposta["reply"])
            self.assertIn("Carros eletricos usam bateria", resposta["reply"])
            memory2.close()

    def test_translate_explicit_text_in_chat(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            memory = MemoryStore(Path(tmpdir) / "nova_memory_test.db")
            orchestrator = NovaOrchestrator(
                memory=memory,
                tools=build_default_tools(memory),
                llm=RuleBasedLLM(),
            )

            with patch(
                "core.orchestrator.translate_text",
                return_value={
                    "ok": True,
                    "translated_text": "Good morning",
                    "provider": "mock",
                    "target_language": "en",
                },
            ):
                resposta = orchestrator.handle(
                    "tester",
                    'traduza "Bom dia" para ingles',
                )

            self.assertIn("Traducao do texto para ingles", resposta["reply"])
            self.assertIn("Good morning", resposta["reply"])
            memory.close()

    def test_translate_text_without_explicit_source_returns_guidance(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            memory = MemoryStore(Path(tmpdir) / "nova_memory_test.db")
            orchestrator = NovaOrchestrator(
                memory=memory,
                tools=build_default_tools(memory),
                llm=RuleBasedLLM(),
            )

            resposta = orchestrator.handle(
                "tester",
                "traduza isso para ingles",
            )

            self.assertIn("Me mande o texto junto do pedido", resposta["reply"])
            memory.close()

    def test_translate_text_uses_next_provider_when_first_is_unavailable(self) -> None:
        with patch(
            "core.translation_service._translate_via_libretranslate",
            return_value={"ok": False, "error": "translate_api_not_configured"},
        ):
            with patch(
                "core.translation_service._translate_via_google_public",
                return_value={
                    "ok": True,
                    "translated_text": "Hello world",
                    "provider": "mock_google",
                    "detected_source_language": "pt",
                },
            ):
                result = translate_text(
                    "Ola mundo",
                    target_language="en",
                )

        self.assertTrue(result["ok"])
        self.assertEqual(result["translated_text"], "Hello world")
        self.assertEqual(result["target_language"], "en")


if __name__ == "__main__":
    unittest.main()
