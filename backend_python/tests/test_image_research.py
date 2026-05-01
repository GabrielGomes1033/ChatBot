from __future__ import annotations

from pathlib import Path
import sys
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.image_research import analisar_imagem_contextualizada


class ImageResearchTests(unittest.TestCase):
    def test_retorn_local_fallback_quando_nao_ha_sinal(self) -> None:
        out = analisar_imagem_contextualizada(
            filename="foto.jpg",
            metadata={"width": 1024, "height": 768},
            recognized_text="",
            labels=[],
            from_camera=True,
            byte_size=2048,
        )

        self.assertTrue(out["ok"])
        self.assertIn("Não encontrei pista suficiente", out["report"]["executive_summary"])
        self.assertTrue(out["learning"]["local_fallback"])

    def test_pesquisa_contextualiza_imagem_quando_ha_objetos_detectados(self) -> None:
        with patch(
            "core.image_research.search_web",
            return_value={
                "ok": True,
                "query": "o que e Museum",
                "summary": "É um museu histórico localizado em São Paulo.",
                "results": [],
            },
        ):
            out = analisar_imagem_contextualizada(
                filename="museu.jpg",
                metadata={"width": 1080, "height": 720},
                recognized_text="",
                labels=[{"label": "Museum", "confidence": 0.93}],
                from_camera=False,
                byte_size=4096,
            )

        self.assertTrue(out["ok"])
        self.assertIn("museu histórico", out["report"]["executive_summary"].lower())
        self.assertEqual(out["report"]["analysis_type"], "image")
        self.assertFalse(out["learning"]["local_fallback"])


if __name__ == "__main__":
    unittest.main()
