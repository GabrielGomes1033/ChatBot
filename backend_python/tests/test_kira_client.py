from __future__ import annotations

from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.kira_client import _build_chat_payload


class KiraClientTests(unittest.TestCase):
    def test_build_chat_payload_merges_objective_and_detailed_context(self) -> None:
        payload = _build_chat_payload(
            "python",
            """
## Resposta objetiva
Python é uma linguagem de programação usada para dar instruções ao computador.
Ela se destaca por ser legível e acessível para iniciantes.

## Alto resumo detalhado
Ela é bastante usada em automação, análise de dados, desenvolvimento web e inteligência artificial.
Também tem uma comunidade grande e muitas bibliotecas prontas.

## Pontos principais
1. Automação - Ajuda a automatizar tarefas repetitivas com pouco código.
2. Dados - É popular em análise de dados e machine learning.
""".strip(),
        )

        summary = payload["summary"]
        self.assertIn("Python é uma linguagem de programação", summary)
        self.assertIn(
            "automação, análise de dados, desenvolvimento web e inteligência artificial", summary
        )
        self.assertIn("comunidade grande e muitas bibliotecas prontas", summary)


if __name__ == "__main__":
    unittest.main()
